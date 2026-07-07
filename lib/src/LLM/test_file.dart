import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as path;

/// Manages the lifecycle of generated test files handling all operations
/// related to test files including writing, validation, execution, formatting,
/// and cleanup.
///
/// The test files are created in the `test/testgen/` directory within the
/// package path provided.
class TestFile {
  // path to the generated test file
  final String testFilePath;
  // path to the package
  final String packagePath;
  // number of analyzer errors
  int analyzerErrors = 0;
  // number of test errors
  int testErrors = 0;

  // Why? It ensures all LLM-generated test files are quarantined in a specific subdirectory (test/testgen/). This keeps them isolated from the project's hand-written tests and makes bulk cleanup easy.
  TestFile(this.packagePath, String fileName)
    : testFilePath = path.join(
        packagePath,
        'test',
        'testgen',
        fileName.toLowerCase(),
      );

  ///-----------------------------Write Test----------------------------------
  // Write the generated test code to a file.
  Future<void> writeTest(String content) async {
    print('Writing test file to $testFilePath');
    final File testFile = File(testFilePath);
    final Directory directory = testFile.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    await testFile.writeAsString(
      '// LLM-Generated test file created by testgen\n\n'
      '$content\n',
    );
  }

  ///-----------------------------Delete Test----------------------------------
  // Delete the generated test file.
  Future<void> deleteTest() async {
    print('Deleting test file at $testFilePath');
    final File testFile = File(testFilePath);
    if (await testFile.exists()) {
      await testFile.delete();
    }
  }

  ///-----------------------------Run Analyzer-----------------------------------
  // Runs a lightweight syntax check on the generated test file.
  // **only performs syntactic validation** by parsing the file
  // using the Dart analyzer parser. It does **not** perform semantic analysis.
  Future<String?> runAnalyzer() async {
    print('Running syntax check on $testFilePath');
    final result = parseFile(
      path: testFilePath,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );

    final errors = result.errors
        .where((error) => error.severity == Severity.error)
        .map((error) => '${error.diagnosticCode}: ${error.message}')
        .toList();

    analyzerErrors += errors.isNotEmpty ? 1 : 0;

    return errors.isEmpty ? null : errors.join('\n');
  }

  ///------------------------ Run Test-------------------------------------------
  // Runs the generated test file using the Dart test runner.
  Future<String?> runTest() async {
    print('Running tests in $testFilePath');
    final result = await Process.run('dart', [
      'test',
      testFilePath,
    ], workingDirectory: packagePath);

    testErrors += result.exitCode != 0 ? 1 : 0;

    return result.exitCode != 0 ? result.stdout.toString() : null;
  }

  ///------------------------ Run Format----------------------------------------
  //clean up spacing and indentation
  Future<String?> runFormat() async {
    print('Formatting test file at $testFilePath');
    final result = await Process.run('dart', [
      'format',
      testFilePath,
    ], workingDirectory: packagePath);

    return result.exitCode != 0 ? result.stdout.toString() : null;
  }
}
