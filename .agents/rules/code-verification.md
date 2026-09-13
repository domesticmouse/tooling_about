# Code Generation Verification Rule

Always execute the following verification steps at the end of each code generation flow or after modifying code in this project:

1. **`flutter test`**: Execute the test suite to guarantee that all unit, widget, and integration tests pass without errors or regressions.
2. **`dart format .`**: Format all project Dart files according to standard Dart conventions.
3. **`dart analyze`**: Run static analysis (via `dart analyze` or the Dart MCP `analyze_files` tool) to verify there are 0 errors, warnings, or lint violations.

If any test fails, code is unformatted, or analyzer diagnostics are surfaced, resolve them before concluding the task.
