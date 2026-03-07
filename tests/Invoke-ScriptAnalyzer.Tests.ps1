# tests/Invoke-ScriptAnalyzer.Tests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'PSScriptAnalyzer -- /src' {

  BeforeAll {
    # Verify PSScriptAnalyzer is available
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
      throw 'PSScriptAnalyzer module is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
    }

    Import-Module PSScriptAnalyzer -Force

    $repoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $srcPath      = Join-Path $repoRoot 'src'
    $settingsPath = Join-Path $repoRoot 'tests' 'PSScriptAnalyzerSettings.psd1'

    if (-not (Test-Path -LiteralPath $srcPath))    { throw "src\ not found: $srcPath" }
    if (-not (Test-Path -LiteralPath $settingsPath)) { throw "Settings file not found: $settingsPath" }

    $script:Findings = Invoke-ScriptAnalyzer `
      -Path $srcPath `
      -Recurse `
      -Settings $settingsPath
  }

  It 'reports no errors' {
    $errors = @($script:Findings | Where-Object Severity -EQ 'Error')
    $errors | Should -BeNullOrEmpty -Because (
      "PSScriptAnalyzer errors in src\:`n" +
      ($errors | ForEach-Object { "  [$($_.ScriptName):$($_.Line)] $($_.RuleName) -- $($_.Message)" } | Join-String -Separator "`n")
    )
  }

  It 'reports no warnings' {
    $warnings = @($script:Findings | Where-Object Severity -EQ 'Warning')
    $warnings | Should -BeNullOrEmpty -Because (
      "PSScriptAnalyzer warnings in src\:`n" +
      ($warnings | ForEach-Object { "  [$($_.ScriptName):$($_.Line)] $($_.RuleName) -- $($_.Message)" } | Join-String -Separator "`n")
    )
  }

}
