import 'dart:collection';
import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter_test_gen_ai/src/LLM/context_generator.dart';
import 'package:flutter_test_gen_ai/src/LLM/model.dart';
import 'package:flutter_test_gen_ai/src/LLM/test_generator.dart';
import 'package:flutter_test_gen_ai/src/analyzer/declaration.dart';
import 'package:flutter_test_gen_ai/src/analyzer/extractor.dart';
import 'package:flutter_test_gen_ai/src/coverage/coverage_collection.dart';
import 'package:flutter_test_gen_ai/src/coverage/utils.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

// Create a logger instance for structured logging output
final _logger = Logger('testgen');

/// Helper function to configure the command-line argument parser (ArgParser).
/// Defines all the flags and options that can be passed to the CLI.
ArgParser _createArgParser() => ArgParser()
  ..addOption(
    'package',
    defaultsTo: '.',
    help: 'Root directory of the package to test.',
  )
  ..addMultiOption(
    'target-files',
    defaultsTo: [],
    help: 'Limit test generation to specific dart files inside the package.',
    valueHelp: 'lib/foo.dart,lib/src/temp.dart',
  )
  ..addOption(
    'port',
    defaultsTo: '0',
    help: 'VM service port. Defaults to using any free port.',
  )
  ..addFlag(
    'function-coverage',
    abbr: 'f',
    defaultsTo: false,
    help: 'Collect function coverage info.',
  )
  ..addFlag(
    'branch-coverage',
    abbr: 'b',
    defaultsTo: false,
    help: 'Collect branch coverage info.',
  )
  ..addMultiOption(
    'scope-output',
    defaultsTo: [],
    help:
        'Restrict coverage results so that only scripts that start with '
        'the provided package path are considered. Defaults to the name of '
        'the current package (including all subpackages, if this is a '
        'workspace).',
  )
  ..addOption(
    'model',
    defaultsTo: 'gemini-3-flash-preview',
    help: 'Gemini model to use for generating tests.',
  )
  ..addOption(
    'api-key',
    defaultsTo: Platform.environment['GEMINI_API_KEY'],
    help: 'Gemini API key for authentication (or set GEMINI_API_KEY env var).',
  )
  ..addOption(
    'max-depth',
    defaultsTo: '10',
    help: 'Maximum dependency depth for context generation.',
  )
  ..addOption(
    'max-attempts',
    defaultsTo: '5',
    help:
        'Maximum number of attempts to generate tests for each declaration on failure.',
  )
  ..addFlag(
    'effective-tests-only',
    abbr: 'e',
    defaultsTo: false,
    help:
        'Restrict test generation to only create tests that increase coverage.',
  )
  ..addFlag(
    'verbose',
    abbr: 'v',
    defaultsTo: false,
    help: 'Enable verbose logging. Logs LLM prompts to a file.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// A container class that holds all configuration values parsed from
/// the command-line arguments.
class Flags {
  final String package;
  final List<String> targetFiles;
  final String vmServicePort;
  final bool branchCoverage;
  final bool functionCoverage;
  final Set<String> scopeOutput;
  final String model;
  final String apiKey;
  final bool effectiveTestsOnly;
  final int maxDepth;
  final int maxAttempts;
  final bool verbose;

  const Flags({
    required this.package,
    required this.targetFiles,
    required this.vmServicePort,
    required this.branchCoverage,
    required this.functionCoverage,
    required this.scopeOutput,
    required this.model,
    required this.apiKey,
    required this.effectiveTestsOnly,
    required this.maxDepth,
    required this.maxAttempts,
    required this.verbose,
  });
}

/// Parses the CLI arguments and validates that the provided paths, settings,
/// and API keys are correct and accessible.
Future<Flags> perseArgs(List<String> arguments) async {
  //print('arguments are  🔥  🔥   🔥  🔥 $arguments'); // []

  //ArgParser is a class that is used to parse command-line arguments. addOption(), addFlag(), usage, parse() are some of the methods used to parse command-line arguments. Think of it like a form
  final ArgParser parser = _createArgParser();

  //ArgResults is an object that contains the parsed command-line arguments. ArgResults is the parsed output after the user provides arguments. The submitted form
  final ArgResults results = parser.parse(arguments);

  // print('form fields are  🔥  🔥   🔥  🔥 ${parser.usage}');

  // Helper function to print usage information
  void printUsage() {
    print('''
test_gen_ai - LLM-based test generation tool

Generates Dart test cases using Google Gemini to improve code coverage.

Analyzes code coverage, identifies untested declarations, and creates targeted
tests to improve coverage metrics through an iterative validation process.

Usage: testgen [OPTIONS]

${parser.usage}
 ''');
  }

  // Helper function to terminate execution with an error message
  Never fail(String msg) {
    _logger.severe('ERROR: $msg');
    printUsage();
    exit(1);
  }

  // If user requested --help, print usage instructions and exit successfully
  if (results['help'] as bool) {
    printUsage();
    exit(0);
  }

  // Normalize the package path to get an absolute path
  final String packageDir = path.normalize(
    path.absolute(results['package'] as String),
  );

  //find the absolute path from your p.c
  _logger.info('Working directory resolved to: $packageDir');

  // Verify that the package directory exists
  if (!FileSystemEntity.isDirectorySync(packageDir)) {
    fail('--package is not a valid directory.');
  }

  // Find and verify the pubspec.yaml file inside the package
  final String pubspecPath = getPubspecPath(packageDir);

  // Make sure the pubspec.yaml file exists.
  if (!File(pubspecPath).existsSync()) {
    fail(
      "Couldn't find $pubspecPath. Make sure this command is run in a "
      'package directory, or pass --package to explicitly set the directory.',
    );
  }

  final String libDir = path.join(packageDir, 'lib');

  // print(' Locates the Library Directory: $libDir');

  // If you run it without target-files: dart run bin/flutter_testgen.dart.   Then targetFiles will be empty ([]). It goes to the else block:
  final List<String>
  targetFiles = (results['target-files'] as List<String>).map((String file) {
    //child path
    final String fullPath = path.normalize(path.join(packageDir, file));

    // Ensure target files are valid Dart files and located inside the lib/ folder
    if (!file.endsWith('.dart') ||
        //libDir/a.dart => true
        !path.isWithin(libDir, fullPath) ||
        !FileSystemEntity.isFileSync(fullPath)) {
      fail('target-files must contain dart files exist inside lib directory');
    }
    return fullPath;
  }).toList();

  if (targetFiles.isNotEmpty) {
    _logger.info(
      '🔥  🔥 Restricting test generation to target files: $targetFiles',
    );
  } else {
    _logger.info(
      ' No target files specified, using all files in lib directory $targetFiles',
    );
  }

  // Determine the workspace/package scopes
  final List<String> scopes = results['scope-output'].isEmpty
      ? getAllWorkspaceNames(packageDir)
      : results['scope-output'] as List<String>;

  if (scopes.length != 1) {
    fail(
      'Workspace support is not implemented yet. '
      'Please specify a single package scope.',
    );
  }

  _logger.info(
    'Reading the Pubspec and Retrieving the Package Name:  ${scopes.first}',
  );

  // Validate the presence of the Gemini API key
  final apiKey = results['api-key'];
  if (apiKey == null || (apiKey as String).isEmpty) {
    fail(
      'No API key provided. Please set the GEMINI_API_KEY environment variable '
      'or use the --api-key option.',
    );
  }

  // Return a structured Flags object with all the verified parameters
  return Flags(
    package: packageDir,
    targetFiles: targetFiles,
    vmServicePort: results['port'],
    branchCoverage: results['branch-coverage'],
    functionCoverage: results['function-coverage'],
    scopeOutput: scopes.toSet(),
    model: results['model'] as String,
    apiKey: results['api-key'] as String,
    effectiveTestsOnly: results['effective-tests-only'] as bool,
    maxDepth: int.parse(results['max-depth'] as String),
    maxAttempts: int.parse(results['max-attempts'] as String),
    verbose: results['verbose'] as bool,
  );
}

/// Reads the `pubspec.yaml` of the target package and returns its dependencies
/// (both regular and dev dependencies) as a list of strings.
List<String> getPackageDependencies(String package) {
  final pubspecFile = File('$package/pubspec.yaml');
  final yamlContent = loadYaml(pubspecFile.readAsStringSync());
  final deps = <String>[];
  final dependencies = yamlContent['dependencies'];
  if (dependencies is YamlMap) {
    deps.addAll(dependencies.keys.cast<String>());
  }
  final devDependencies = yamlContent['dev_dependencies'];
  if (devDependencies is YamlMap) {
    deps.addAll(devDependencies.keys.cast<String>());
  }
  return deps;
}

/// The main entry point of the CLI tool.
Future<void> main(List<String> arguments) async {
  // Set up logging to output to stdout
  Logger.root.level = Level.INFO;

  Logger.root.onRecord.listen((record) {
    print(
      '[${record.time}] [${record.loggerName}] [${record.level.name}] '
      '[${record.message}]',
    );
  });

  // Step 1: Parse arguments and configure runtime environment
  final Flags flags = await perseArgs(arguments);

  _logger.info("Flags package path are ${flags.package}");
  _logger.info("Flags vm service port are ${flags.vmServicePort}");
  _logger.info("Flags target files are ${flags.targetFiles}");

  _logger.info("Flags branch coverage are ${flags.branchCoverage}");
  _logger.info("Flags function coverage are ${flags.functionCoverage}");
  _logger.info("Flags scope output are ${flags.scopeOutput}");

  _logger.info("Flags verbose are ${flags.verbose}");

  if (flags.verbose) {
    Logger.root.level = Level.FINE;
  }

  // Step 2: Read dependencies and check if the 'test' library is installed
  //🚀 Dependencies are  🚀  🚀 [path, lints, test, flutter_test_gen_ai]

  final List<String> deps = getPackageDependencies(flags.package);

  _logger.info('Dependencies are  🚀  🚀 $deps');

  // The 'test' library is required to run generated tests.
  // If not found in the project's pubspec.yaml, we add it automatically.
  if (!deps.contains('test')) {
    _logger.info(
      '"test" package not found in dependencies. Running "dart pub add test --dev"...',
    );
    final process = await Process.run('dart', [
      'pub',
      'add',
      'test',
      '--dev',
    ], workingDirectory: flags.package);
    if (process.exitCode != 0) {
      _logger.shout('Failed to run dart pub add test --dev: ${process.stderr}');
      exit(1);
    }
    _logger.info('Successfully added "test" dev dependency.');
  }

  // Step 3: Start with dynamic layer. Run initial tests and get json
  final Map<String, dynamic> coverage = await runTestsAndCollectCoverage(
    flags.package, //absolute path of the package
    vmServicePort: flags.vmServicePort, //port number 0
    branchCoverage: flags.branchCoverage, //[]
    functionCoverage: flags.functionCoverage, //false
    scopeOutput: flags.scopeOutput, //{tic_tac_toe}
  );

  // Format Json to CoverageData
  final CoverageData coverageByFile = await formatCoverage(
    coverage,
    flags.package,
  );

  // Step 4: Start with Static layer. Extract all code declarations
  final List<Declaration> declarations = await extractDeclarations(
    flags.package,
    targetFiles: flags.targetFiles,
  );

  _logger.info(
    "Extracted ${declarations.length} declarations from the package",
  );

  // Group the declarations by the file they belong to
  final Map<String, List<Declaration>> declarationsByFile = {};

  for (final declaration in declarations) {
    declarationsByFile.putIfAbsent(declaration.path, () => []).add(declaration);
  }

  // Step 5: Identify untested or partially tested declarations by cross-referencing
  // the declarations with the baseline coverage report.
  List<(Declaration, List<int>)> untestedDeclarations =
      extractUntestedDeclarations(declarationsByFile, coverageByFile);

  _logger.info(
    'Found ${untestedDeclarations.length} untested/partially tested declarations.',
  );

  // Step 6: Initialize Gemini model and test generation framework
  final model = GeminiModel(modelName: flags.model, apiKey: flags.apiKey);

  final TestGenerator testGenerator = TestGenerator(
    model: model,
    packagePath: flags.package,
    maxRetries: flags.maxAttempts,
    verbose: flags.verbose,
  );

  // Keep track of declarations that failed or were skipped to avoid infinite loops
  final skippedOrFailedDeclarations = HashSet<int>();

  // Shuffle untested declarations to randomize the order in which we build tests
  untestedDeclarations.shuffle();

  _logger.info('Step 7: Starting test generation loop...');
  while (untestedDeclarations.isNotEmpty) {
    // Find the next declaration that we haven't skipped/failed yet
    final idx = untestedDeclarations.indexWhere(
      (pair) => !skippedOrFailedDeclarations.contains(pair.$1.id),
    );

    // If all remaining declarations have been skipped/failed, break the loop
    if (idx == -1) {
      _logger.info(
        'No more declarations can be processed. Terminating test generation loop.',
      );
      break;
    }

    final remainingCount =
        untestedDeclarations.length - skippedOrFailedDeclarations.length;
    _logger.info('====================================================');
    _logger.info('Untested declarations remaining: $remainingCount');

    // Retrieve the declaration and the list of uncovered lines
    final (declaration, lines) = untestedDeclarations[idx];
    _logger.info(
      'Selected Target: "${declaration.name}" (ID: ${declaration.id}) in ${path.relative(declaration.path, from: flags.package)}',
    );
    _logger.info('Uncovered lines for this declaration: $lines');

    // Format the code block for the selected declaration
    final toBeTestedCode = formatUntestedCode(declaration, lines);

    // Step 7a: Collect references & dependencies of this declaration (BFS/DFS traversal of AST)
    // This gives the LLM context about other classes/methods used by this code, enabling it
    // to write valid tests without mock errors.
    _logger.info(
      'Analyzing dependency context for "${declaration.name}" up to depth of ${flags.maxDepth}...',
    );
    final contextMap = buildDependencyContext(
      declaration,
      maxDepth: flags.maxDepth,
    );

    // Format context mapping for injection into the LLM prompt
    final contextCode = formatContext(contextMap);
    _logger.info('Dependency context generated successfully.');

    // Step 7b: Query the LLM to generate tests
    _logger.info('Sending request to Gemini LLM to generate tests...');
    final result = await testGenerator.generate(
      toBeTestedCode: toBeTestedCode,
      contextCode: contextCode,
      fileName:
          '${declaration.name}_${declaration.id}_${lines.length}_test.dart',
    );

    _logger.info('LLM response received. Status: ${result.status}');
    bool isTestDeleted = result.status != TestStatus.created;

    // Step 7c: If --effective-tests-only is enabled, we run the suite and verify
    // if code coverage actually improved. If it didn't, we discard the generated test file.
    if (flags.effectiveTestsOnly && result.status == TestStatus.created) {
      _logger.info(
        'Validation: Checking if the generated test increases code coverage...',
      );
      final isImproved = await validateTestCoverageImprovement(
        declaration: declaration,
        baselineUncoveredLines: lines.length,
        packageDir: flags.package,
        scopeOutput: flags.scopeOutput,
        vmServicePort: flags.vmServicePort,
        branchCoverage: flags.branchCoverage,
        functionCoverage: flags.functionCoverage,
      );

      if (!isImproved) {
        _logger.info(
          'Validation Outcome: Test did not improve coverage. Deleting generated test file.',
        );
        await result.testFile.deleteTest();
        isTestDeleted = true;
      } else {
        _logger.info(
          'Validation Outcome: Success! Code coverage increased. Keeping test file: ${result.testFile.testFilePath}',
        );
      }
    }

    // Step 7d: Re-run tests to collect updated coverage map
    _logger.info('Re-running tests to collect new coverage metrics...');
    final newCoverage = await runTestsAndCollectCoverage(
      flags.package,
      vmServicePort: flags.vmServicePort,
      branchCoverage: flags.branchCoverage,
      functionCoverage: flags.functionCoverage,
      scopeOutput: flags.scopeOutput,
      isInternalCall: true,
    );

    final newCoverageByFile = await formatCoverage(newCoverage, flags.package);

    // If the test was successfully kept, update our listing of untested declarations
    if (result.status == TestStatus.created && !isTestDeleted) {
      _logger.info(
        'Updating list of untested declarations with new coverage data.',
      );
      untestedDeclarations = extractUntestedDeclarations(
        declarationsByFile,
        newCoverageByFile,
      );
    } else {
      // Otherwise mark this declaration as skipped/failed to avoid trying it again
      _logger.info(
        'Marking declaration "${declaration.name}" as skipped/failed to avoid re-tries.',
      );
      skippedOrFailedDeclarations.add(declaration.id);
    }
  }

  // Clean up test generator resources
  _logger.info('Step 8: Disposing test generator and cleaning up...');
  await testGenerator.dispose();
  _logger.info('Process finished successfully.');
  exit(0);
}
