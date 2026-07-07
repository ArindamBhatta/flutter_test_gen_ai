import 'dart:io';
import 'package:flutter_test_gen_ai/src/analyzer/declaration.dart';
import 'package:flutter_test_gen_ai/src/analyzer/extractor.dart';
import 'package:flutter_test_gen_ai/src/coverage/coverage_collection.dart';
import 'package:flutter_test_gen_ai/src/LLM/context_generator.dart';

void main() async {
  final String projectPath = Directory.current.path;
  final List<Declaration> declarations = await extractDeclarations(projectPath);

  print('--- AI Context Output ---');
  print(formatDeclarations(declarations));
  print('-------------------------');

  // Run the dynamic coverage layer
  final rawCoverage = await runTestsAndCollectCoverage(
    projectPath,
    scopeOutput: <String>{}, // Empty for now
  );

  // Format the results
  await formatCoverage(rawCoverage, projectPath);
}
