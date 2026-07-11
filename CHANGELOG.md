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
