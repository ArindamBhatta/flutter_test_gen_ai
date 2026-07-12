import 'package:flutter_test_gen_ai/flutter_test_gen_ai.dart';

///Use as a Library for Prompt Engineering
Future<void> main() async {
  // Change the packagePath and scopeOutput to your package directory and name
  const packagePath = '.';
  const scopeOutput = 'my_package';
  const modelName = 'gemini-3-flash-preview';

  // 1. Run tests and collect coverage metrics
  final coverage = await runTestsAndCollectCoverage(
    packagePath,
    scopeOutput: {scopeOutput},
  );

  // 2. Format coverage information by file
  final coverageByFile = await formatCoverage(coverage, packagePath);

  // 3. Extract class and method declarations from the package code
  final declarations = await extractDeclarations(packagePath);

  final Map<String, List<Declaration>> declarationsByFile = {};
  for (final declaration in declarations) {
    declarationsByFile.putIfAbsent(declaration.path, () => []).add(declaration);
  }

  // 4. Identify which declarations are currently uncovered by existing tests
  final untestedDeclarations = extractUntestedDeclarations(
    declarationsByFile,
    coverageByFile,
  );

  // 5. Initialize the Gemini LLM Model
  final model = GeminiModel(modelName: modelName);

  // 6. Initialize the test generator to start creating test files
  final testGenerator = TestGenerator(model: model, packagePath: packagePath);

  print('Found ${untestedDeclarations.length} untested declarations.');
  print(
    'Ready to run programmatic test generation for ${testGenerator.packagePath} using model: $modelName',
  );
}

///Use as a Cli
///1. Add to dev_dependencies:
///flutter_test_gen_ai: ^0.2.2
///2. run
/// To run the test generator as a command-line tool, execute the following command from your package root directory:
/// ```bash
/// # Option 1: Pass the Gemini API Key as an argument
/// dart run flutter_test_gen_ai --api-key YOUR_GEMINI_API_KEY
///
/// # Option 2: Set the environment variable (Recommended)
/// export GEMINI_API_KEY="your-gemini-api-key"
/// dart run flutter_test_gen_ai
/// ```
