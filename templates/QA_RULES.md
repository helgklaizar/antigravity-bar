# QA & Testing Standards

## 1. Self-Verification
Before presenting code to the user or declaring a task complete, you MUST verify your work.
- Check syntax and run linters (e.g., `eslint`, `cargo clippy`, `flake8`) if available.
- Review your own diffs for logic errors or regressions.

## 2. Unit Testing
- If you create or modify utility functions, parsers, or core logic, you MUST write or update the corresponding Unit Tests.
- Keep tests isolated. Mock external services and databases.

## 3. UI & E2E Testing
- If you modify UI components or user flows, request the user to visually verify the changes in the browser/simulator.
- Do not assume UI code works perfectly without a render check.

## 4. Debugging
- Do not guess errors. Always ask to run code, read the logs, or write a test to isolate the issue.
- Apply the "Crash Detect" workflow for hard-to-find bugs: add excessive logging, reproduce, fix, then clean up logs.
