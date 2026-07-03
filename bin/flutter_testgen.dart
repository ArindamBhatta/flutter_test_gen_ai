import 'dart:io';
import 'package:test_gen_ai/src/analyzer/extractor.dart';
import 'package:test_gen_ai/src/coverage/coverage_collection.dart';

void main() async {
  final String projectPath = Directory.current.path;
  // await extractDeclarations(projectPath);

  // Run the dynamic coverage layer
  final rawCoverage = await runTestsAndCollectCoverage(
    projectPath,
    scopeOutput: <String>{}, // Empty for now
  );

  // Format the results
  await formatCoverage(rawCoverage, projectPath);
}
