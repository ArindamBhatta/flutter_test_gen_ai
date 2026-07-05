import 'dart:async';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test_gen_ai/src/analyzer/declaration.dart';
import 'package:test_gen_ai/src/coverage/utils.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('coverage');
//Records : (filepath, ListOfUncoveredLines)

typedef CoverageData = List<(String, List<int>)>;

//cross-platform path styling os .
const coverageImportFilePath = <String>[
  'test',
  'testgen',
  'coverage_import_test.dart',
];

final _allProcesses = <Process>[];
bool _isSignalsWatched = false;

Future<void> _dartRun(
  List<String> args, {
  required String packageAbsolutePath,
  required void Function(String) onStdout,
  required void Function(String) onStderr,
}) async {
  final Process process = await Process.start(
    Platform.executable,
    args,
    workingDirectory: packageAbsolutePath,
  );

  //
  _allProcesses.add(process);

  void listen(
    Stream<List<int>> stream,
    IOSink sink,
    void Function(String) onLine,
  ) {
    final broadStream = stream.asBroadcastStream();
    broadStream.listen(sink.add);
    broadStream.lines().listen(onLine);
  }

  listen(process.stdout, stdout, onStdout);
  listen(process.stderr, stderr, onStderr);

  final result = await process.exitCode;

  // Don't throw an error if the process exits with code 79 which is common for no tests found.
  if (result != 0 && result != 79) {
    throw ProcessException(Platform.executable, args, '', result);
  }
}

// 2. The Emergency Cleanup Routine
void _killSubprocessesAndExit(ProcessSignal signal) {
  for (final process in _allProcesses) {
    process.kill(
      signal,
    ); // Force kill every background Dart VM process we spawned!
  }
  exit(1);
}

void _watchExitSignal(ProcessSignal signal) {
  // Listen for the OS notification event
  signal.watch().listen(_killSubprocessesAndExit);
}

//-------------- STARTING DYNAMIC LAYER  ---------------
Future<Map<String, dynamic>> runTestsAndCollectCoverage(
  String packageDir, {
  String vmServicePort = '0', //set to 0 to let the system pick a random port
  bool branchCoverage = false,
  bool functionCoverage = false,
  bool isInternalCall = false,
  required Set<String> scopeOutput,
}) async {
  _logger.info('Starting code coverage collection for package at $packageDir');

  //1. Setting Up OS Kill Signals if not already set up
  if (!_isSignalsWatched) {
    _watchExitSignal(ProcessSignal.sighup); //(Signal Hang Up)
    // 1. Setup the watchers
    _watchExitSignal(ProcessSignal.sigint); //(Signal Interrupt)
    if (!Platform.isWindows) {
      _watchExitSignal(ProcessSignal.sigterm); //(Signal Terminate)
    }
    _isSignalsWatched = true;
  }

  if (!isInternalCall) {
    await _generateCoverageImportFile(packageDir);
  }

  final serviceUriCompleter = Completer<Uri>();

  //2. Call or Launching Dart with VM Service Flags
  final testProcess = _dartRun(
    [
      if (branchCoverage) '--branch-coverage',
      'run',
      '--pause-isolates-on-exit', //? --pause-isolates-on-exit: This prevents Dart from closing immediately when the tests finish. It freezes the program at the finish line so the coverage collector has time to extract the data.
      '--disable-service-auth-codes',
      '--enable-vm-service=$vmServicePort', //? --enable-vm-service: This fires up an internal HTTP server inside the Dart runtime.
      'test',
    ],
    packageAbsolutePath: packageDir,
    //listen every output to find the vm service port
    onStdout: (line) {
      if (!serviceUriCompleter.isCompleted) {
        final uri = extractVMServiceUri(line);
        if (uri != null) {
          serviceUriCompleter.complete(uri);
        }
      }
    },
    //if the vm service fails to start, kill the process
    onStderr: (line) {
      if (!serviceUriCompleter.isCompleted) {
        if (line.contains('Could not start the VM service')) {
          _killSubprocessesAndExit(ProcessSignal.sigkill);
        }
      }
    },
  );

  final serviceUri = await serviceUriCompleter.future;

  final Map<String, dynamic> coverageResults = await Chain.capture(
    () async {
      return await collect(
        serviceUri,
        true,
        true,
        false,
        scopeOutput,
        branchCoverage: branchCoverage,
        functionCoverage: functionCoverage,
      );
    },
    onError: (dynamic error, Chain chain) {
      stderr.writeln(error);
      stderr.writeln(chain.terse);
      // See http://www.retro11.de/ouxr/211bsd/usr/include/sysexits.h.html
      // EX_SOFTWARE
      exit(70);
    },
  );
  await testProcess;

  return coverageResults; //raw result
}

// Generate a Dart file that imports all Dart files in the `lib` directory.
// This ensure the coverage tool includes these files in the analysis. even if they are not directly referenced in tests
Future<void> _generateCoverageImportFile(String packagePath) async {
  _logger.config('Preparing coverage import file for coverage collection');

  // packagePath = Directory.currentPath + add test + coverage_import_test.dart path
  final File importsFile = File(
    path.joinAll([packagePath, ...coverageImportFilePath]),
  );

  //This is why PackageConfig is fetched.
  final PackageConfig? config = await findPackageConfig(Directory(packagePath));

  final String importStatements = Directory(path.join(packagePath, 'lib'))
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => 'import \'${config?.toPackageUri(file.uri)}\';')
      .join('\n');

  // print('Importing files are  📄📄📄📄📄📄 => $importStatements');

  importsFile.createSync(recursive: true);

  importsFile.writeAsStringSync('''
// This file is generated by testgen to include all files in the lib directory
// for coverage collection purposes, Don't modify or delete this file.
$importStatements

void main(){}
''');
}

//Step 2:  🧹 🧹 🧹 CLEANING UP AND FORMATTING RAW JSON COVERAGE DATA 🧹 🧹 🧹
Future<CoverageData> formatCoverage(
  Map<String, dynamic> coverageResults,
  String packageDir,
) async {
  _logger.fine('Formatting raw coverage results into CoverageData structure');
  final List<Map<String, dynamic>> coverage = coverageResults['coverage'];
  //A HitMap (short for "Hit Map") is a highly specialized data model created by the official Dart package:coverage library.
  //1. The Problem: Raw JSON is Messy
  // When your tool dials into the Dart VM backdoor and downloads the raw coverage metadata payload, the server sends back a massive, heavily nested JSON map that looks like this:

  // {
  // "source": "package:my_app/user.dart",
  // "hits": [12, 1, 14, 0, 15, 3]
  // } : Line 12 was hit 1 time, Line 14 was hit 0 times, and Line 15 was hit 3 times.

  // A HitMap contains a primary internal property called lineHits, which is a clean, structured Map<int, int>:
  // The Key (int): The literal line number in your source file.
  // The Value (int): The total number of times a test case executed that line.

  final Map<String, HitMap> hitmaps = await HitMap.parseJson(
    coverage,
    packagePath: packageDir,
  );

  final CoverageData result = hitmaps.entries
      .map(
        (fileHits) => (
          fileHits
              .key, // The String file path (e.g., 'package:my_app/user.dart')
          fileHits.value.lineHits.entries
              .where(
                (lineHit) => lineHit.value == 0,
              ) // Step 1: Keep ONLY the pairs where run count is 0
              .map(
                (lineHit) => lineHit.key,
              ) // Step 2: Extract just the line number (the key)
              .toList(), // Step 3: Turn them into a List
        ),
      )
      .where((fileHits) => fileHits.$2.isNotEmpty)
      .toList();

  print('  Result: $result');
  return result;
}

//Step 3:  🤔 🤔 🤔 VALIDATING CODE COVERAGE IMPROVEMENT 🤔 🤔 🤔

Future<bool> validateTestCoverageImprovement({
  required Declaration declaration,
  required int baselineUncoveredLines,
  required String packageDir,
  required Set<String> scopeOutput,
  String vmServicePort = '0',
  bool branchCoverage = false,
  bool functionCoverage = false,
}) async {
  _logger.info('Validating code coverage improvement for ${declaration.name}');

  final Map<String, dynamic> coverage = await runTestsAndCollectCoverage(
    packageDir,
    scopeOutput: scopeOutput,
    vmServicePort: vmServicePort,
    branchCoverage: branchCoverage,
    functionCoverage: functionCoverage,
    isInternalCall: true,
  );

  final coverageByFile = await formatCoverage(coverage, packageDir);

  int currentUncoveredLines = 0;

  final fileCoverage = coverageByFile
      .where((pair) => pair.$1 == declaration.path)
      .firstOrNull;

  for (final line in fileCoverage?.$2 ?? <int>[]) {
    if (line >= declaration.startLine && line <= declaration.endLine) {
      currentUncoveredLines++;
    }
  }

  final coverageImproved = currentUncoveredLines < baselineUncoveredLines;
  _logger.info(
    coverageImproved
        ? 'Code coverage has improved. '
              'Uncovered lines decreased from $baselineUncoveredLines '
              'to $currentUncoveredLines.'
        : 'Code coverage has not improved. '
              'Uncovered lines remain at $currentUncoveredLines '
              '(baseline: $baselineUncoveredLines).',
  );
  return coverageImproved;
}
