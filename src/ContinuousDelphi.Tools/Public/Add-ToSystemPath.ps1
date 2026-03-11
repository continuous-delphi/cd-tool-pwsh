#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
Adds a directory to the system PATH if it is not already present.

.DESCRIPTION
Adds a single directory to the machine-level PATH environment variable.
The script normalizes the supplied path, avoids duplicates, checks for
administrator privileges, warns about PATH size growth, and updates the
current PowerShell session PATH after the change.

.PARAMETER PathToAdd
The directory path to add to the system PATH.

.EXAMPLE
pwsh -File .\Add-ToSystemPath.ps1 "C:\Tools\MyApp"
#>

function Add-ToSystemPath {

  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $true, Position = 0)]
      [string]$PathToAdd
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  function Test-IsAdministrator {
      $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
      $principal = [Security.Principal.WindowsPrincipal]::new($identity)
      return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }

  function Normalize-DirectoryPath {
      param(
          [Parameter(Mandatory = $true)]
          [string]$Path
      )

      if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
          throw "Directory does not exist: $Path"
      }

      $resolved = Resolve-Path -LiteralPath $Path
      $fullPath = [System.IO.Path]::GetFullPath($resolved.Path)

      return $fullPath.TrimEnd('\')
  }

  function Get-NormalizedPathKey {
      param(
          [Parameter(Mandatory = $true)]
          [string]$Path
      )

      return $Path.Trim().TrimEnd('\').ToUpperInvariant()
  }

  function Split-PathEntries {
      param(
          [AllowNull()]
          [string]$PathValue
      )

      if ([string]::IsNullOrWhiteSpace($PathValue)) {
          return @()
      }

      return @(
          $PathValue -split ';' |
          Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
      )
  }

  function Update-CurrentSessionPath {
      $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
      $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

      $combined = @()

      if (-not [string]::IsNullOrWhiteSpace($machinePath)) {
          $combined += Split-PathEntries -PathValue $machinePath
      }

      if (-not [string]::IsNullOrWhiteSpace($userPath)) {
          $combined += Split-PathEntries -PathValue $userPath
      }

      $env:Path = ($combined -join ';')
  }

  if (-not (Test-IsAdministrator)) {
      throw 'Administrator privileges are required to modify the system PATH. Re-run PowerShell as Administrator.'
  }

  $normalizedPathToAdd = Normalize-DirectoryPath -Path $PathToAdd

  $currentMachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $currentEntries = Split-PathEntries -PathValue $currentMachinePath

  $existingKeys = @{}
  foreach ($entry in $currentEntries) {
      $existingKeys[(Get-NormalizedPathKey -Path $entry)] = $true
  }

  $newKey = Get-NormalizedPathKey -Path $normalizedPathToAdd

  if ($existingKeys.ContainsKey($newKey)) {
      Write-Host ''
      Write-Host 'Path already exists in the system PATH:' -ForegroundColor Yellow
      Write-Host "  $normalizedPathToAdd"
      Write-Host ''
      Update-CurrentSessionPath
      return
  }

  $newEntries = @($currentEntries + $normalizedPathToAdd)
  $newMachinePath = $newEntries -join ';'

  if ($newMachinePath.Length -gt 30000) {
      Write-Warning "The updated system PATH will be $($newMachinePath.Length) characters long. Windows environment size limits may become a problem."
  }

  [Environment]::SetEnvironmentVariable('Path', $newMachinePath, 'Machine')
  Update-CurrentSessionPath

  Write-Host ''
  Write-Host 'Added to system PATH:' -ForegroundColor Green
  Write-Host "  $normalizedPathToAdd"
  Write-Host ''
  Write-Host 'The machine PATH has been updated.' -ForegroundColor Green
  Write-Host 'The current PowerShell session PATH has also been refreshed.' -ForegroundColor Green
  Write-Host ''
  Write-Host 'New processes will see the updated PATH immediately.' -ForegroundColor White
  Write-Host 'Some already-running applications may need to be restarted.' -ForegroundColor White
  Write-Host ''
}
