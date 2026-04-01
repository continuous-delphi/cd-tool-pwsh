# Changelog
## `ContinuousDelphi.Tools` PowerShell module 

All notable changes to this project will be documented in this file.

The format is loosely based on Keep a Changelog (https://keepachangelog.com/en/1.1.0/)
and this project follows Semantic Versioning.

Example release
```powershell
pwsh .\tools\tag-release.cd-tool-pwsh.ps1 -Version 0.5.0 -WhatIf
pwsh .\tools\tag-release.cd-tool-pwsh.ps1 -Version 0.5.0
```

---

## [0.6.0] Unreleased

### Added

- `Set-FileLineEnding` command for normalizing repository text files to CRLF or LF line endings.
- Default repository-oriented FileSpec set for `*.pas`, `*.dpr`, `*.inc`, and `*.ps1`.
- Support for recursive searching, pipeline input, `-WhatIf`, and `-PassThru` result objects.

## [0.5.0] - 2026-03-07

### Added

- Initial release of the `ContinuousDelphi.Tools` PowerShell module.
- `Test-NonAsciiContent` command for detecting non-ASCII characters in files.
- Support for scanning directories with optional recursion.
- Support for multiple FileSpec patterns.
- Pipeline input support from Get-ChildItem.
- Quiet switch for boolean detection mode.
- Version switch for command version reporting.

### Module Infrastructure

- Module manifest (ContinuousDelphi.Tools.psd1).
- Auto-loading module structure using Public and Private folders.
- PowerShell 7+ requirement enforced.

### Testing

- Pester test suite for command behavior.
- Isolated filesystem tests using temporary directories.
- Test runner script (tests/run-tests.ps1).
- Pester configuration file.

### Documentation

- Command documentation under `docs/Tools`.
- README with usage examples.

### Automation

- GitHub Actions CI workflow for automated test execution on push and pull requests.
