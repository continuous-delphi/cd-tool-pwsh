#requires -Version 7.0
#requires -PSEdition Core

<#
.SYNOPSIS
Tests files for non-ASCII content.

.DESCRIPTION
Test-NonAsciiContent scans one or more files and returns an object for
each line containing characters outside the ASCII range (0x00-0x7F).

This command is intended for repository validation, content hygiene
checks, and automation scenarios where non-ASCII characters should be
identified or disallowed.

By default, the current working directory is searched when -Path is not
specified.

.PARAMETER Path
Directory to search.

Defaults to the current working directory. Files are selected using
FileSpec and optionally searched recursively when Recurse is specified.

.PARAMETER FileSpec
One or more file patterns used to select files to scan.

Multiple patterns may be provided as a comma-separated list.

Examples:

    *.pas
    *.ps1
    *.md
    *.json
    *.yml

Only files matching the specified patterns are scanned.

.PARAMETER Recurse
Search subdirectories recursively.

.PARAMETER InputObject
One or more file system objects or file paths to scan.

This parameter accepts pipeline input by value and by property name.
Objects with a FullName property, such as those returned by
Get-ChildItem, are supported.

.PARAMETER Quiet
Returns $true if any non-ASCII content is found; otherwise returns
$false.

When -Quiet is specified, no match objects are written to the pipeline.

.PARAMETER Version
Displays the command version.

.EXAMPLE
Test-NonAsciiContent -FileSpec *.ps1 -Recurse

Scans matching files under the current directory.

.EXAMPLE
Test-NonAsciiContent -Path C:\code -FileSpec *.pas,*.dpr -Recurse

Recursively scans Pascal source files under C:\code.

.EXAMPLE
Get-ChildItem -Path . -Filter *.md -Recurse | Test-NonAsciiContent

Scans Markdown files returned from the pipeline.

.EXAMPLE
Test-NonAsciiContent -Path . -FileSpec *.md -Recurse -Quiet

Returns $true if any non-ASCII content is found; otherwise returns
$false.

.OUTPUTS
By default, returns one PSCustomObject per matching line with these
properties:

    Path
    LineNumber
    Line
    Match

When -Quiet is specified, returns a single Boolean value.

.NOTES
Requires PowerShell 7 or later.
#>

function Test-NonAsciiContent {
  [CmdletBinding(DefaultParameterSetName = 'BySearch')]
  param(
      [Parameter(ParameterSetName = 'BySearch', Position = 0)]
      [ValidateNotNullOrEmpty()]
      [string]$Path = '.',

      [Parameter(Mandatory = $true, ParameterSetName = 'BySearch', Position = 1)]
      [ValidateNotNullOrEmpty()]
      [string[]]$FileSpec,

      [Parameter(ParameterSetName = 'BySearch')]
      [switch]$Recurse,

      [Parameter(
          Mandatory = $true,
          ParameterSetName = 'ByInput',
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true
      )]
      [Alias('FullName', 'PSPath')]
      [object[]]$InputObject,

      [Parameter()]
      [switch]$Quiet,

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

      $nonAsciiRegex = [regex]::new('[^\x00-\x7F]')
      $foundMatch = $false
      $filesToScan = [System.Collections.Generic.List[string]]::new()

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
                      $filesToScan.Add($resolved.Path)
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
  }

  process {
      switch ($PSCmdlet.ParameterSetName) {
          'ByInput' {
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
  }

  end {
      if ($PSCmdlet.ParameterSetName -eq 'BySearch') {
          $resolvedRoot = Resolve-Path -LiteralPath $Path -ErrorAction Stop
          $specs = Expand-FileSpec -Specs $FileSpec

          foreach ($spec in $specs) {
              Write-Verbose ("Searching '{0}' for '{1}'" -f $resolvedRoot.Path, $spec)

              foreach ($file in @(Get-ChildItem -LiteralPath $resolvedRoot.Path -File -Filter $spec -Recurse:$Recurse)) {
                  $filesToScan.Add($file.FullName)
              }
          }
      }

      $uniqueFiles = @($filesToScan | Sort-Object -Unique)

      if (-not $uniqueFiles) {
          if ($Quiet) {
              $false
          }
          return
      }

      foreach ($filePath in $uniqueFiles) {
          $lineNumber = 0
          $reader = $null

          try {
              $reader = [System.IO.StreamReader]::new(
                  $filePath,
                  [System.Text.Encoding]::UTF8,
                  $true
              )

              while (($line = $reader.ReadLine()) -ne $null) {
                  $lineNumber++

                  if ([string]::IsNullOrEmpty($line)) {
                      continue
                  }

                  $match = $nonAsciiRegex.Match($line)
                  if ($match.Success) {
                      $foundMatch = $true

                      if (-not $Quiet) {
                          [PSCustomObject]@{
                              PSTypeName = 'Test.NonAsciiContent.Match'
                              Path       = $filePath
                              LineNumber = $lineNumber
                              Line       = $line
                              Match      = $match.Value
                          }
                      }
                  }
              }
          }
          catch {
              $PSCmdlet.WriteError(
                  [System.Management.Automation.ErrorRecord]::new(
                      $_.Exception,
                      'ReadFileFailed',
                      [System.Management.Automation.ErrorCategory]::ReadError,
                      $filePath
                  )
              )
          }
          finally {
              if ($null -ne $reader) {
                  $reader.Dispose()
              }
          }
      }

      if ($Quiet) {
          $foundMatch
      }
  }
}
