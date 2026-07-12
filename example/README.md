# Examples for Flutter AI Test Generator

This directory contains examples demonstrating how to use `flutter_test_gen_ai` to generate test cases and improve test coverage for both pure Dart packages and Flutter applications.

## 📁 Included Examples

1. **[tic_tac_toe](./tic_tac_toe/)**: A command-line Tic-Tac-Toe application built with pure Dart.

2. **[todo_app](./todo_app/)**: A mobile Todo application built with Flutter, utilizing `flutter_bloc` for state management.

---

## 🚀 How to Run the Examples

### 1. Set up your Gemini API Key
You must have a Google Gemini API Key. Set it as an environment variable in your terminal:
```bash
export GEMINI_API_KEY="your-api-key-here"
```

### 2. Run the generator on the Pure Dart Example
Navigate to the `example/tic_tac_toe` folder and run the generator:
```bash
cd example/tic_tac_toe
dart run flutter_test_gen_ai --api-key $GEMINI_API_KEY
```

### 3. Run the generator on the Flutter Example
Navigate to the `example/todo_app` folder and run the generator:
```bash
cd example/todo_app
dart run flutter_test_gen_ai --api-key $GEMINI_API_KEY
```

---

## 📊 Generating Reports

To generate a Markdown report with a Mermaid dependency and coverage flowchart (`testgen_report.md`):
```bash
dart run flutter_test_gen_ai --api-key $GEMINI_API_KEY --generate-report
```
