## 0.2.4

- Improved subprocess diagnostics by reporting standard output (`stdout`) alongside standard error (`stderr`) when `flutter test --coverage` fails.
- Handled `ProcessException` gracefully at the CLI entry point to print user-friendly troubleshooting details instead of crashing with a raw unhandled exception.

## 0.2.3

- Registered public library exports in `lib/flutter_test_gen_ai.dart` to support programmatic scripting and library integration.
- Added a compile-safe programmatic usage demonstration to `example/example.dart`.
- Added an explanation section at the bottom of the generated markdown reports (`testgen_report.md`) detailing why some tests fail (e.g., hardcoded global standard I/O, platform channels).
- Cleaned up package footprint using `.pubignore` to exclude local model assets and development configs.
- Disables global CLI configuration in `pubspec.yaml` to ensure pub.dev displays standard dev_dependencies installation instructions.

## 0.2.2

- Fixed analyzer API compatibility issues for newer Dart/Flutter SDKs.
- Focused documentation and usage instructions purely on local CLI execution.

## 0.2.0

- Added robust support for automated **Flutter Widget Testing**.
- Static analyzer dynamically extracts `Semantics` labels and widget `Keys` from source code to guide Gemini's test generation.
- Prevents selector hallucinations in generated widget tests.
- Fixed UI hierarchy resolution for nested widget methods.

## 0.1.0

- Initial release: LLM-based coverage-driven test generation CLI tool.
- Supports both Flutter and pure Dart packages.
- Added AST-driven static dependency context construction.
- Automated self-correcting validation loop.
- Optional visual Mermaid dependency and coverage reporting.
