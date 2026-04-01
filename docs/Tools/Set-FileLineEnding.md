# Set-FileLineEnding

## Synopsis

Normalizes text file line endings.

## Description

`Set-FileLineEnding` searches one or more files and rewrites them using a
consistent line ending style.

It is intended for repository hygiene tasks such as normalizing Delphi and
PowerShell source files before commit, release, or packaging.

By default, the command searches recursively from the current directory and
processes these file patterns:

- `*.pas`
- `*.dpr`
- `*.inc`
- `*.ps1`

The default target line ending style is `CRLF`.

------------------------------------------------------------------------

## Syntax

``` powershell
Set-FileLineEnding [[-Path] <string>] [[-FileSpec] <string[]>] [-Recurse]
                   [-LineEnding <CRLF|LF>] [-PassThru] [-WhatIf] [-Confirm]

Set-FileLineEnding -InputObject <object[]> [-LineEnding <CRLF|LF>]
                   [-PassThru] [-WhatIf] [-Confirm]
```

------------------------------------------------------------------------

## Parameters

### Path

Directory to search.

Defaults to the current working directory.

### FileSpec

One or more file patterns used to select files to normalize.

Defaults to:

```text
*.pas
*.dpr
*.inc
*.ps1
```

### Recurse

Search subdirectories recursively.

Enabled by default for the path-based parameter set.

### InputObject

One or more file system objects or file paths to normalize.

Supports pipeline input from commands such as `Get-ChildItem`.

### LineEnding

Target line ending style.

Supported values:

- `CRLF` (default)
- `LF`

### PassThru

Returns one object per processed file describing whether the file changed.

### WhatIf

Shows which files would be normalized without modifying them.

------------------------------------------------------------------------

## Output

By default, this command does not emit result objects.

When `-PassThru` is specified, it returns one object per processed file:

```text
Path
Changed
OriginalLineEnding
TargetLineEnding
```

------------------------------------------------------------------------

## Examples

### Normalize a typical Delphi repository to CRLF

``` powershell
Set-FileLineEnding
```

### Normalize specific file types under the current directory

``` powershell
Set-FileLineEnding -Path . -FileSpec *.pas,*.dpr,*.inc,*.ps1
```

### Preview changes without modifying files

``` powershell
Set-FileLineEnding -Path . -WhatIf
```

### Normalize files returned from the pipeline

``` powershell
Get-ChildItem -Path . -Filter *.ps1 -Recurse | Set-FileLineEnding -PassThru
```

------------------------------------------------------------------------

## Notes

- The command is intended for text files only.
- BOM-based Unicode encodings are preserved.
- Files without a BOM are written as UTF-8 without BOM after normalization.
