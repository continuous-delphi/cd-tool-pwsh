# Test-NonAsciiContent

## Synopsis

Tests files for characters outside the ASCII range (0x00-0x7F).

## Description

`Test-NonAsciiContent` scans files and reports any lines containing
characters outside the standard ASCII range. This helps detect encoding
issues and unintended characters that may appear from copy/paste
operations, rich text editors, or inconsistent file encodings.

The command returns objects describing each match so that results can be
inspected, filtered, or exported using normal PowerShell pipeline
behavior.

Typical scenarios include:

- repository validation
- CI pipeline checks
- pre-commit validation
- enforcing ASCII-only repository policies

The command is designed to behave like a native PowerShell command and
works well with pipeline input.

------------------------------------------------------------------------

## Syntax

``` powershell
Test-NonAsciiContent [-Path <string>] -FileSpec <string[]> [-Recurse] [-Quiet]
```

``` powershell
Test-NonAsciiContent -InputObject <object[]> [-Quiet]
```

``` powershell
Test-NonAsciiContent -Version
```

------------------------------------------------------------------------

## Parameters

### Path

Directory to search for files.

Defaults to the current working directory if not specified.

### FileSpec

One or more file patterns used to select files to scan.

Multiple patterns may be provided as a comma-separated list.

Example:

``` powershell
-FileSpec *.pas,*.ps1,*.md
```

### Recurse

Optional switch to search subdirectories recursively.

Defaults to non-recursive search.

### InputObject

Optional parameter to accept pipeline input of file paths or objects
with a `FullName` property, such as those returned by `Get-ChildItem`.

### Quiet

Optional switch that suppresses match output and returns a Boolean value.

Returns:

```text
  True   - Non-ASCII content detected
  False  - No non-ASCII content found
```

### Version

Displays the command's current version.

------------------------------------------------------------------------

## Output

By default, the command outputs one object per match with the following
properties:

| Property   | Description                     |
|------------|---------------------------------|
| Path       | File path                       |
| LineNumber | Line containing the match       |
| Line       | Full line content               |
| Match      | The first non-ASCII character detected|

Example output object:

``` text
Path       : C:\repo\file.md
LineNumber : 12
Line       : Example text with smart quote “
Match      : “
```

------------------------------------------------------------------------

## Examples

### Scan current repository

``` powershell
Test-NonAsciiContent -FileSpec *.pas,*.ps1,*.md -Recurse
```

### Scan specific directory

``` powershell
Test-NonAsciiContent -Path C:\code -FileSpec *.pas -Recurse
```

### Use pipeline input

``` powershell
Get-ChildItem -Path . -Filter *.md -Recurse |
    Test-NonAsciiContent
```

### CI validation example

``` powershell
if (Test-NonAsciiContent -Path . -FileSpec *.pas,*.ps1,*.md -Recurse -Quiet) {
    Write-Error "Non-ASCII content detected."
    exit 2
}
```
