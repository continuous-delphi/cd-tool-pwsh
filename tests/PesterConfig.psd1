@{
    Run = @{
        Path = @(
            './tests',
            './tests/Tools'
        )
        Exit = $false
        PassThru = $true
    }

    Filter = @{
        Tag = @()
        ExcludeTag = @()
    }

    CodeCoverage = @{
        Enabled = $false
        Path = @(
            './src/ContinuousDelphi.Tools/Public',
            './src/ContinuousDelphi.Tools/Private'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = './tests/results/coverage.xml'
    }

    TestResult = @{
        Enabled = $false
        OutputFormat = 'NUnitXml'
        OutputPath = './tests/results/pester-results.xml'
    }

    Output = @{
        Verbosity = 'Detailed'
        CIFormat = 'Auto'
    }

    Should = @{
        ErrorAction = 'Stop'
    }
}
