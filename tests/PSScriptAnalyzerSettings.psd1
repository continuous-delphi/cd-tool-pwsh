# tests/PSScriptAnalyzerSettings.psd1
# PSScriptAnalyzer settings for the ContinuousDelphi.Tools module.
#
# Usage:
#   Invoke-ScriptAnalyzer -Path .\src\ContinuousDelphi.Tools -Recurse `
#     -Settings .\tests\PSScriptAnalyzerSettings.psd1
#
# Suppressions are limited to rules that conflict with deliberate
# conventions in this repository. Public module commands should still
# follow normal PowerShell naming conventions.

@{
  ExcludeRules = @(

    # [OutputType()] attributes on internal functions add no value here.
    # These functions are not part of a public API surface.
    'PSUseOutputTypeCorrectly'
  )
}
