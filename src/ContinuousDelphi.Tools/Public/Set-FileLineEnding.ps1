#requires -Version 7.0
#requires -PSEdition Core

<##
.SYNOPSIS
Normalizes text file line endings.

.DESCRIPTION
Set-FileLineEnding scans one or more text files and rewrites them using a
consistent line ending style.

This command is intended for repository hygiene and automation scenarios such
as normalizing Delphi source files in a repository before commit or release.

By default, the current working directory is searched recursively when -Path is
not specified. The default FileSpec targets common Continuous-Delphi source
files and normalizes them to CRLF line endings.

.PARAMETER Path
Directory to search.

Defaults to the current working directory.

.PARAMETER FileSpec
One or more file patterns used to select files to normalize.

Defaults to:

    *.pas
    *.dpr
    *.inc
    *.ps1

Multiple patterns may be provided as a comma-separated list.

.PARAMETER Recurse
Search subdirectories recursively.

This switch is enabled by default when using the -Path parameter set.

.PARAMETER InputObject
One or more file system objects or file paths to normalize.

This parameter accepts pipeline input by value and by property name. Objects
with a FullName property, such as those returned by Get-ChildItem, are
supported.

.PARAMETER LineEnding
Target line ending style.

Supported values are CRLF and LF. The default is CRLF.

.PARAMETER PassThru
Returns one object per processed file describing whether the file changed.

.PARAMETER Version
Displays the command version.

.EXAMPLE
Set-FileLineEnding

Recursively normalizes *.pas, *.dpr, *.inc, and *.ps1 files under the current
working directory to CRLF.

.EXAMPLE
Set-FileLineEnding -Path . -FileSpec *.pas,*.dpr,*.inc -Recurse

Recursively normalizes Delphi source files under the current directory.

.EXAMPLE
Get-ChildItem -Path . -Filter *.ps1 -Recurse | Set-FileLineEnding -PassThru

Normalizes PowerShell files returned from the pipeline and emits result objects.

.EXAMPLE
Set-FileLineEnding -Path . -LineEnding LF -WhatIf

Shows which files would be normalized to LF without modifying them.

.OUTPUTS
By default, this command does not write objects to the pipeline.

When -PassThru is specified, returns one PSCustomObject per processed file with
these properties:

    Path
    Changed
    OriginalLineEnding
    TargetLineEnding

.NOTES
Requires PowerShell 7 or later.
#>

function Set-FileLineEnding {
    [CmdletBinding(DefaultParameterSetName = 'SearchParamSet', SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param(
        [Parameter(ParameterSetName = 'SearchParamSet', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = '.',

        [Parameter(ParameterSetName = 'SearchParamSet', Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string[]]$FileSpec = @('*.pas', '*.dpr', '*.inc', '*.ps1'),

        [Parameter(ParameterSetName = 'SearchParamSet')]
        [switch]$Recurse = $false,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'ByInput',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('FullName', 'PSPath')]
        [object[]]$InputObject,

        [Parameter()]
        [ValidateSet('CRLF', 'LF')]
        [string]$LineEnding = 'CRLF',

        [Parameter()]
        [switch]$PassThru,

        [Parameter(ParameterSetName = 'Version')]
        [switch]$Version
    )

    begin {
        $scriptVersion = '1.0.0'

        if ($Version) {
            $scriptVersion
            return
        }

        Set-StrictMode -Version Latest

        $filesToProcess = [System.Collections.Generic.List[string]]::new()
        $utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($false)

        function Add-ResolvedFile {
            param(
                [Parameter(Mandatory = $true)]
                [string]$CandidatePath
            )

            if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
                return
            }

            try {
                if (Test-Path -LiteralPath $CandidatePath -PathType Leaf) {
                    foreach ($resolved in (Resolve-Path -LiteralPath $CandidatePath)) {
                        $filesToProcess.Add($resolved.Path)
                    }
                }
                else {
                    Write-Verbose "Skipping non-file path: $CandidatePath"
                }
            }
            catch {
                Write-Warning ("Skipping path '{0}': {1}" -f $CandidatePath, $_.Exception.Message)
            }
        }

        function Expand-FileSpec {
            param(
                [Parameter(Mandatory = $true)]
                [string[]]$Specs
            )

            @(
                $Specs |
                ForEach-Object { $_ -split '[,;]' } |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ } |
                Sort-Object -Unique
            )
        }

        function Get-LineEndingName {
            param(
                [Parameter(Mandatory = $true)]
                [AllowEmptyString()]
                [string]$Content
            )

            $hasCrLf = $Content.Contains("`r`n")
            $normalized = $Content.Replace("`r`n", '')
            $hasLoneCr = $normalized.Contains("`r")
            $hasLf = $normalized.Contains("`n")

            if ($hasCrLf -and -not $hasLf -and -not $hasLoneCr) {
                return 'CRLF'
            }

            if ($hasLf -and -not $hasCrLf -and -not $hasLoneCr) {
                return 'LF'
            }

            if (-not $hasCrLf -and -not $hasLf -and -not $hasLoneCr) {
                return 'None'
            }

            return 'Mixed'
        }

        function Get-EncodingInfo {
            param(
                [Parameter(Mandatory = $true)]
                [byte[]]$Bytes
            )

            if ($Bytes.Length -ge 3 -and
                $Bytes[0] -eq 0xEF -and
                $Bytes[1] -eq 0xBB -and
                $Bytes[2] -eq 0xBF) {
                return [PSCustomObject]@{
                    Encoding = [System.Text.UTF8Encoding]::new($true)
                    PreambleLength = 3
                    Name = 'UTF8-BOM'
                }
            }

            if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
                return [PSCustomObject]@{
                    Encoding = [System.Text.UnicodeEncoding]::new($false, $true)
                    PreambleLength = 2
                    Name = 'UTF16-LE'
                }
            }

            if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
                return [PSCustomObject]@{
                    Encoding = [System.Text.UnicodeEncoding]::new($true, $true)
                    PreambleLength = 2
                    Name = 'UTF16-BE'
                }
            }

            return [PSCustomObject]@{
                Encoding = [System.Text.Encoding]::Default
                PreambleLength = 0
                Name = 'ANSI'
            }
        }
        function ConvertTo-NormalizedLineEnding {
            param(
                [Parameter(Mandatory = $true)]
                [AllowEmptyString()]
                [string]$Content,

                [Parameter(Mandatory = $true)]
                [string]$TargetLineEnding
            )

            $newline = if ($TargetLineEnding -eq 'CRLF') { "`r`n" } else { "`n" }
            (($Content -replace "`r`n", "`n") -replace "`r", "`n") -replace "`n", $newline
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByInput') {
            foreach ($item in $InputObject) {
                if ($null -eq $item) {
                    continue
                }

                if ($item -is [string]) {
                    Add-ResolvedFile -CandidatePath $item
                    continue
                }

                $fullNameProperty = $item.PSObject.Properties['FullName']
                if ($null -ne $fullNameProperty -and -not [string]::IsNullOrWhiteSpace([string]$fullNameProperty.Value)) {
                    Add-ResolvedFile -CandidatePath ([string]$fullNameProperty.Value)
                    continue
                }

                $psPathProperty = $item.PSObject.Properties['PSPath']
                if ($null -ne $psPathProperty -and -not [string]::IsNullOrWhiteSpace([string]$psPathProperty.Value)) {
                    Add-ResolvedFile -CandidatePath ([string]$psPathProperty.Value)
                    continue
                }

                Write-Warning ("Unsupported pipeline input type: {0}" -f $item.GetType().FullName)
            }
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'SearchParamSet') {
            $resolvedRoot = Resolve-Path -LiteralPath $Path -ErrorAction Stop
            $specs = Expand-FileSpec -Specs $FileSpec

            foreach ($spec in $specs) {
                Write-Verbose ("Searching '{0}' for '{1}'" -f $resolvedRoot.Path, $spec)

                foreach ($file in @(Get-ChildItem -LiteralPath $resolvedRoot.Path -File -Filter $spec -Recurse:$Recurse)) {
                    $filesToProcess.Add($file.FullName)
                }
            }
        }

        $uniqueFiles = @($filesToProcess | Sort-Object -Unique)

        foreach ($filePath in $uniqueFiles) {
            $resolvedPath = (Resolve-Path -LiteralPath $filePath).Path
            $originalBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
            $encodingInfo = Get-EncodingInfo -Bytes $originalBytes
            $contentBytes = if ($encodingInfo.PreambleLength -gt 0) {
                $originalBytes[$encodingInfo.PreambleLength..($originalBytes.Length - 1)]
            }
            else {
                $originalBytes
            }

            if ($originalBytes.Length -eq 0) {
                $contentBytes = @()
            }

            $originalContent = $encodingInfo.Encoding.GetString($contentBytes)
            $normalizedContent = ConvertTo-NormalizedLineEnding -Content $originalContent -TargetLineEnding $LineEnding
            $originalLineEnding = Get-LineEndingName -Content $originalContent
            $changed = $normalizedContent -cne $originalContent

            if ($changed -and $PSCmdlet.ShouldProcess($resolvedPath, "Normalize line endings to $LineEnding")) {
                if ($encodingInfo.PreambleLength -gt 0) {
                    $contentOutputBytes = $encodingInfo.Encoding.GetBytes($normalizedContent)
                    $preambleBytes = $encodingInfo.Encoding.GetPreamble()
                    $bytesToWrite = [byte[]]::new($preambleBytes.Length + $contentOutputBytes.Length)
                    [System.Buffer]::BlockCopy($preambleBytes, 0, $bytesToWrite, 0, $preambleBytes.Length)
                    [System.Buffer]::BlockCopy($contentOutputBytes, 0, $bytesToWrite, $preambleBytes.Length, $contentOutputBytes.Length)
                    [System.IO.File]::WriteAllBytes($resolvedPath, $bytesToWrite)
                }
                else {
                    [System.IO.File]::WriteAllText($resolvedPath, $normalizedContent, $utf8NoBomEncoding)
                }
            }

            if ($PassThru) {
                [PSCustomObject]@{
                    Path = $resolvedPath
                    Changed = $changed
                    OriginalLineEnding = $originalLineEnding
                    TargetLineEnding = $LineEnding
                }
            }
        }
    }
}
