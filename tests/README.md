# Tests

This folder contains the automated test suite for the ContinuousDelphi.Tools PowerShell module.

The tests validate command behavior, expected output, and error handling for all public functions in the module.

The project uses Pester v5.

---

# Running the Tests

From the repository root:

    pwsh ./tests/run-tests.ps1

Or run Pester directly:

    pwsh
    Invoke-Pester -Configuration ./tests/PesterConfig.psd1

Both approaches execute the same test configuration.

---

# Test Structure

tests/
|-- run-tests.ps1
|-- PesterConfig.psd1
|-- Tools/
|   |-- Test-NonAsciiContent.Tests.ps1

run-tests.ps1
Entry point for running the test suite locally or in CI.

PesterConfig.psd1
Defines how Pester discovers and executes tests.

Tools/
Contains tests for commands in the module. Each command should have a matching test file.

Example:

Public command:
src/ContinuousDelphi.Tools/Public/Test-NonAsciiContent.ps1

Test file:
tests/Tools/Test-NonAsciiContent.Tests.ps1

---

# Test Isolation

Tests create temporary directories when filesystem interaction is required. Each test creates its own isolated temporary workspace and removes it after execution.

This ensures:

- tests do not affect each other
- the repository remains clean
- CI results are deterministic

---

# Writing New Tests

When adding a new command to the module:

1. Create the command in:

    src/ContinuousDelphi.Tools/Public/

2. Create a matching test file:

    tests/Tools/<CommandName>.Tests.ps1

3. Follow the Pester pattern used by existing tests:

    Describe <CommandName>
        It <expected behavior>
            Arrange
            Act
            Assert

4. Run the full test suite:

    pwsh ./tests/run-tests.ps1

---

# Continuous Integration

Tests are executed automatically by GitHub Actions as part of the CI workflow.

The [CI](https://github.com/continuous-delphi/cd-tool-pwsh/actions/workflows/ci.yml)
pipeline installs dependencies and runs tests via:

```powershell
    pwsh -Command "Install-Module Pester -MinimumVersion 5.7.0 -Force -Scope CurrentUser"
    pwsh -Command "Install-Module PSScriptAnalyzer -Force -Scope CurrentUser"
    pwsh -NoProfile -File tests/run-tests.ps1
```

Any failing test will cause the workflow to fail.
