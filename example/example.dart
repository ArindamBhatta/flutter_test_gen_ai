void main() {
  print('=== Flutter AI Test Generator Example ===');
  print('This package is a CLI tool and is run from the terminal.');
  print('');
  print('To run the test generator on your project, execute:');
  print('  dart run flutter_test_gen_ai --api-key YOUR_GEMINI_API_KEY');
  print('');
  print('Common CLI Options:');
  print(
    '  --target-files          Comma-separated list of target files to analyze',
  );
  print(
    '  --effective-tests-only  Discard tests that do not increase coverage',
  );
  print('  --generate-report       Generate a visual coverage Mermaid report');
  print('');
  print('Check out the complete sample applications in this directory:');
  print('  - example/tic_tac_toe: A pure Dart console application');
  print('  - example/todo_app: A Flutter state management (Bloc) application');
}
