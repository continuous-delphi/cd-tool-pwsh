@{
    RootModule = 'ContinuousDelphi.Tools.psm1'
    ModuleVersion = '0.5.0'
    GUID = '9e6d3f3e-6c6c-4b1c-9c7a-3c4d4c9a7b11'

    Author = 'Darian Miller'
    CompanyName = 'Continuous-Delphi'
    Copyright = '(c) 2026 Continuous-Delphi'
    Description = 'PowerShell developer tools used across the Continuous-Delphi ecosystem.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Test-NonAsciiContent',
        'Add-ToSystemPath'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @(
                'continuous-delphi',
                'delphi',
                'powershell',
                'pwsh',
                'powershell-module',
                'developer-tools',
                'linting',
                'ascii',
                'encoding'
            )

            ProjectUri = 'https://github.com/continuous-delphi/cd-tool-pwsh'
            LicenseUri = 'https://github.com/continuous-delphi/cd-tool-pwsh/blob/main/LICENSE'
            ReleaseNotes = 'Initial public release of the ContinuousDelphi.Tools module with Test-NonAsciiContent.'
        }
    }
}
