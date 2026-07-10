import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:flutter_test_gen_ai/src/analyzer/declaration.dart';
import 'package:flutter_test_gen_ai/src/coverage/utils.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('coverage');
//Records : (filepath, ListOfUncoveredLines)

//Create a record to store the coverage data
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
  String executable,
  List<String> args, {
  required String packageAbsolutePath,
  required void Function(String) onStdout,
  required void Function(String) onStderr,
}) async {
  final Process process = await Process.start(
    executable,
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
    final lineSink = const LineSplitter().startChunkedConversion(
      _LineSink(onLine),
    );
    final decodedSink = const SystemEncoding().decoder.startChunkedConversion(
      lineSink,
    );

    stream.listen(
      (data) {
        sink.add(data);
        decodedSink.add(data);
      },
      onDone: () {
        decodedSink.close();
      },
    );
  }

  listen(process.stdout, stdout, onStdout);
  listen(process.stderr, stderr, onStderr);

  final result = await process.exitCode;

  // Don't throw an error if the process exits with code 79 which is common for no tests found.
  if (result != 0 && result != 79) {
    throw ProcessException(executable, args, '', result);
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

Future<Map<String, dynamic>> _collectCoverageViaLcov(String packageDir) async {
  _logger.info('Running flutter test --coverage in $packageDir');
  final ProcessResult result = await Process.run(
    'flutter',
    ['test', '--coverage'],
    workingDirectory: packageDir,
  );

  // We should accept exit codes 0 and 79 (no tests found)
  if (result.exitCode != 0 && result.exitCode != 79) {
    throw ProcessException('flutter', ['test', '--coverage'], result.stderr.toString(), result.exitCode);
  }

  final lcovFile = File(path.join(packageDir, 'coverage', 'lcov.info'));
  if (!lcovFile.existsSync()) {
    _logger.warning('lcov.info not found at ${lcovFile.path}. Returning empty coverage.');
    return {'type': 'CodeCoverage', 'coverage': []};
  }

  final lines = await lcovFile.readAsLines();
  final List<Map<String, dynamic>> coverageList = [];
  
  final PackageConfig? config = await findPackageConfig(Directory(packageDir));

  String? currentSource;
  List<int> currentHits = [];

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      final relativePath = line.substring(3).trim();
      final fileUri = Uri.file(path.join(packageDir, relativePath));
      currentSource = config?.toPackageUri(fileUri)?.toString() ?? relativePath;
      currentHits = [];
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length == 2) {
        final lineNum = int.tryParse(parts[0]);
        final hits = int.tryParse(parts[1]);
        if (lineNum != null && hits != null) {
          currentHits.add(lineNum);
          currentHits.add(hits);
        }
      }
    } else if (line == 'end_of_record') {
      if (currentSource != null) {
        coverageList.add({
          'source': currentSource,
          'hits': currentHits,
        });
      }
      currentSource = null;
      currentHits = [];
    }
  }

  return {
    'type': 'CodeCoverage',
    'coverage': coverageList,
  };
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

  final File pubspecFile = File(path.join(packageDir, 'pubspec.yaml'));
  final bool isFlutter = pubspecFile.existsSync() && pubspecFile.readAsStringSync().contains('sdk: flutter');

  if (isFlutter) {
    return _collectCoverageViaLcov(packageDir);
  }

  final serviceUriCompleter = Completer<Uri>();

  final String executable = isFlutter ? 'flutter' : Platform.executable;
  final List<String> args = isFlutter
      ? [
          'test',
          '--pause-isolates-on-exit',
          '--disable-service-auth-codes',
          '--enable-vm-service=$vmServicePort',
        ]
      : [
          if (branchCoverage) '--branch-coverage',
          'run',
          '--pause-isolates-on-exit',
          '--disable-service-auth-codes',
          '--enable-vm-service=$vmServicePort',
          'test',
        ];

  //2. Call or Launching Dart with VM Service Flags
  final testProcess = _dartRun(
    executable,
    args,
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

  _logger.info(
    'Dynamic layer 🎯🎯🎯🎯🎯🎯🎯 : Importing files are => $importStatements',
  );

  importsFile.createSync(recursive: true);

  importsFile.writeAsStringSync('''
// This file is generated by testgen to include all files in the lib directory
// for coverage collection purposes, Don't modify or delete this file.
$importStatements

void main(){}
''');
}

//Step 2: Converts the raw coverage report into CoverageData by
// extracting only the uncovered line numbers for each source file.
Future<CoverageData> formatCoverage(
  Map<String, dynamic> coverageResults,
  String packageDir,
) async {
  _logger.fine('Formatting raw coverage results into CoverageData structure');
  final List<Map<String, dynamic>> coverage = coverageResults['coverage'];
  /*
      A HitMap (short for "Hit Map") is a highly specialized data model created by the official Dart package:coverage library.
      1. The Problem: Raw JSON is Messy
      When your tool dials into the Dart VM backdoor and downloads the raw coverage metadata payload, the server sends back a massive, heavily nested JSON map that looks like this:

      {
      "source": "package:my_app/user.dart",
      "hits": [12, 1, 14, 0, 15, 3]
      } : Line 12 was hit 1 time, Line 14 was hit 0 times, and Line 15 was hit 3 times.

      A HitMap contains a primary internal property called lineHits, which is a clean, structured Map<int, int>:
      The Key (int): The literal line number in your source file.
      The Value (int): The total number of times a test case executed that line.
   */

  final Map<String, HitMap> hitmaps = await HitMap.parseJson(
    coverage,
    packagePath: packageDir,
  );

  final CoverageData result = hitmaps.entries
      .map(
        (fileHits) => (
          // The String file path (e.g., 'package:my_app/user.dart')
          fileHits.key,

          fileHits.value.lineHits.entries
              // Step 1: Keep ONLY the pairs where run count is 0
              .where((lineHit) => lineHit.value == 0)
              // Step 2: Extract just the line number (the key)
              .map((MapEntry<int, int> lineHit) => lineHit.key)
              .toList(), // Step 3: Turn them into a List
        ),
      )
      .where((fileHits) => fileHits.$2.isNotEmpty)
      .toList();

  if (result.isNotEmpty) {
    _logger.info(
      'Dynamic Layer uncovered source file ${result[0].$1} and Line numbers : ${result[0].$2}',
    );
  } else {
    _logger.info('Dynamic Layer: No uncovered source files found.');
  }
  return result;
}

//Step 3: VALIDATING CODE COVERAGE IMPROVEMENT

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

class _LineSink implements Sink<String> {
  final void Function(String) onLine;
  _LineSink(this.onLine);

  @override
  void add(String line) => onLine(line);

  @override
  void close() {}
}
