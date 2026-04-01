
<p align="center">
  <img width="200" height="200" alt="cd-tool-pwsh logo" src="https://github.com/user-attachments/assets/b5d9a3fd-1ace-4c5e-9ea1-c68aca5bdc7e" />
</p>

# Continuous-Delphi PowerShell Tools

[![CI](https://github.com/continuous-delphi/cd-tool-pwsh/actions/workflows/ci.yml/badge.svg)](https://github.com/continuous-delphi/cd-tool-pwsh/actions/workflows/ci.yml)
![Status](https://img.shields.io/badge/status-incubator-orange)
[![GitHub Release](https://img.shields.io/github/v/release/continuous-delphi/cd-tool-pwsh?display_name=release)](https://github.com/continuous-delphi/cd-tool-pwsh/releases)
![License](https://img.shields.io/github/license/continuous-delphi/cd-tool-pwsh)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)
![Continuous Delphi](https://img.shields.io/badge/org-continuous--delphi-red)

This repository contains PowerShell utilities used across the
**Continuous-Delphi** ecosystem.

The goal of these tools is to support consistent, automated workflows
for maintaining healthy code repositories.

## TL;DR

Quick start:

```powershell
git clone https://github.com/continuous-delphi/cd-tool-pwsh
Import-Module ./src/ContinuousDelphi.Tools
Test-NonAsciiContent -FileSpec *.md -Recurse
```

------------------------------------------------------------------------

# First Tool: Test-NonAsciiContent

The first utility provided by this repository is the PowerShell command:

`Test-NonAsciiContent`

This command scans files for characters outside the ASCII range
(0x00--0x7F) and reports their location.

Detecting non-ASCII characters is useful for:

-   preventing encoding problems
-   avoiding copy-paste typography issues
-   keeping source repositories portable across tools and platforms
-   enforcing consistent text standards in long-lived codebases

Typical use cases include:

-   validating repository content
-   pre-commit checks
-   CI pipeline validation
-   enforcing ASCII-only policies in source files

Example usage:

``` powershell
Test-NonAsciiContent -Path . -FileSpec *.pas,*.ps1,*.md -Recurse
```

The command returns objects describing each match, allowing results to
be filtered, exported, or inspected using standard PowerShell pipelines.

------------------------------------------------------------------------


# Tools Included

- `Test-NonAsciiContent` -- detects non-ASCII characters in repository files
- `Set-FileLineEnding` -- normalizes repository text files to CRLF or LF line endings
- `Add-ToSystemPath` -- adds a directory to the machine PATH when needed

------------------------------------------------------------------------

# Normalize line endings for Delphi repositories

The module now includes:

`Set-FileLineEnding`

This command is intended for repository hygiene tasks such as normalizing
Delphi and PowerShell source files to CRLF line endings before commit,
release, or packaging.

Default behavior:

- searches recursively from the current directory
- targets `*.pas`, `*.dpr`, `*.inc`, and `*.ps1`
- normalizes line endings to `CRLF`
- supports `-WhatIf` and pipeline input

Example usage:

``` powershell
Set-FileLineEnding
Set-FileLineEnding -Path . -FileSpec *.pas,*.dpr,*.inc,*.ps1
Get-ChildItem -Path . -Filter *.ps1 -Recurse | Set-FileLineEnding -PassThru
```

------------------------------------------------------------------------

# Repository Scope

This repository will contain PowerShell tools that support the
**Continuous-Delphi** ecosystem, including utilities for:

-   repository validation
-   content linting
-   CI workflow helpers
-   developer tooling for Delphi projects

Commands in this repository are intended to be:

-   PowerShell-native (Verb-Noun)
-   pipeline-friendly
-   automation-ready
-   compatible with PowerShell 7+

------------------------------------------------------------------------

# Installation (Development)

Until a packaged distribution is provided, the module can be loaded
directly from the repository:

``` powershell
Import-Module ./src/ContinuousDelphi.Tools
```

Once imported, the commands become available in the current session.

---

## Part of Continuous Delphi

This repository follows the `Continuous Delphi` organization taxonomy. See
[cd-meta-org](https://github.com/continuous-delphi/cd-meta-org) for navigation and governance.

- `docs/org-taxonomy.md` -- naming and tagging conventions
- `docs/versioning-policy.md` -- release and versioning rules
- `docs/repo-lifecycle.md` -- lifecycle states and graduation criteria

