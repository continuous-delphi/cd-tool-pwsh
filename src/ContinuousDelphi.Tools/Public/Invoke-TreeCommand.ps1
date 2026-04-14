#requires -Version 7.0
#requires -PSEdition Core
function Invoke-TreeCommand {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Run')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string]$InputDirectory,

        [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string]$FileSpec,

        [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string]$ExeToRun,

        [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string]$CLIOptions,

        [Parameter(ParameterSetName = 'Run')]
        [switch]$PassThru,

        [Parameter(ParameterSetName = 'Run')]
        [switch]$StopOnError,

        [Parameter(ParameterSetName = 'Run')]
        [switch]$UseCmdShell,

        [Parameter(Mandatory = $true, ParameterSetName = 'Version')]
        [switch]$Version
    )

    $script:ToolVersion = '1.0.0'

      if ($Version) {
            $scriptVersion
            return
        }

    function Expand-TreeCommandTokenList {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Template,

            [Parameter(Mandatory = $true)]
            [string]$InputFileName,

            [Parameter(Mandatory = $true)]
            [string]$OutputFileName
        )

        $Result = $Template.Replace('{InputFileName}', $InputFileName)
        $Result = $Result.Replace('{OutputFileName}', $OutputFileName)
        return $Result
    }

    function Get-TreeCommandResult {
        param(
            [Parameter(Mandatory = $true)]
            [string]$InputFileName,

            [Parameter(Mandatory = $true)]
            [string]$OutputFileName,

            [Parameter(Mandatory = $true)]
            [string]$CommandLine,

            [AllowNull()]
            [int]$ExitCode,

            [AllowNull()]
            [bool]$Success,

            [Parameter(Mandatory = $true)]
            [bool]$Executed,

            [Parameter(Mandatory = $true)]
            [bool]$UsedCmdShell
        )

        [pscustomobject]@{
            InputFileName  = $InputFileName
            OutputFileName = $OutputFileName
            CommandLine    = $CommandLine
            ExitCode       = $ExitCode
            Success        = $Success
            Executed       = $Executed
            UsedCmdShell   = $UsedCmdShell
        }
    }

    try {
        $ResolvedInputDirectory = (Resolve-Path -Path $InputDirectory -ErrorAction Stop).Path
    }
    catch {
        throw "InputDirectory not found: $InputDirectory"
    }

    $ResolvedInputDirectory = [System.IO.Path]::GetFullPath($ResolvedInputDirectory)
    $ResolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

    $DirectorySeparator = [System.IO.Path]::DirectorySeparatorChar
    if (-not $ResolvedInputDirectory.EndsWith($DirectorySeparator)) {
        $ResolvedInputDirectory += $DirectorySeparator
    }

    [int]$TotalFiles = 0
    [int]$Attempted  = 0
    [int]$Succeeded  = 0
    [int]$Failed     = 0
    [int]$Skipped    = 0

    $Files = Get-ChildItem -Path $ResolvedInputDirectory -Recurse -File -Filter $FileSpec

    foreach ($File in $Files) {
        $TotalFiles++

        $InputFileName = [System.IO.Path]::GetFullPath($File.FullName)

        if (-not $InputFileName.StartsWith($ResolvedInputDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Skipping file outside InputDirectory boundary: $InputFileName"
            $Skipped++
            continue
        }

        $RelativePath = $InputFileName.Substring($ResolvedInputDirectory.Length)
        $OutputFileName = Join-Path -Path $ResolvedOutputDirectory -ChildPath $RelativePath
        $OutputParentDirectory = Split-Path -Path $OutputFileName -Parent

        $ExpandedOptions = Expand-TreeCommandTokenList `
            -Template $CLIOptions `
            -InputFileName $InputFileName `
            -OutputFileName $OutputFileName

        $ExitCode = $null
        $Success = $null
        $Executed = $false

        $CommandLine = "`"$ExeToRun`" $ExpandedOptions"

        if ($UseCmdShell) {
            $ActionDescription = "Execute via cmd.exe: $CommandLine"
        }
        else {
            $ActionDescription = "Execute: $CommandLine"
        }

        if ($PSCmdlet.ShouldProcess($InputFileName, $ActionDescription)) {
            if (-not [string]::IsNullOrWhiteSpace($OutputParentDirectory)) {
                if (-not (Test-Path -LiteralPath $OutputParentDirectory)) {
                    New-Item -ItemType Directory -Path $OutputParentDirectory -Force | Out-Null
                }
            }

            $Attempted++
            $Executed = $true

            if ($UseCmdShell) {
                & cmd.exe /d /c $CommandLine
                $ExitCode = $LASTEXITCODE
            }
            else {
                $ArgumentTokens = [System.Management.Automation.PSParser]::Tokenize($ExpandedOptions, [ref]$null)
                $ArgumentList = @(
                    foreach ($Token in $ArgumentTokens) {
                        if ($Token.Type -eq 'CommandArgument') {
                            $Token.Content
                        }
                    }
                )

                & $ExeToRun @ArgumentList
                $ExitCode = $LASTEXITCODE
            }

            $Success = ($ExitCode -eq 0)

            if ($Success) {
                $Succeeded++
                Write-Verbose "SUCCESS ($ExitCode): $InputFileName"
            }
            else {
                $Failed++
                Write-Warning "FAIL ($ExitCode): $InputFileName"
            }
        }
        else {
            $Skipped++
            Write-Verbose "WHATIF: $ActionDescription"
        }

        if ($PassThru) {
            Get-TreeCommandResult `
                -InputFileName $InputFileName `
                -OutputFileName $OutputFileName `
                -CommandLine $CommandLine `
                -ExitCode $ExitCode `
                -Success $Success `
                -Executed $Executed `
                -UsedCmdShell $UseCmdShell.IsPresent
        }

        if ($Executed -and (-not $Success) -and $StopOnError) {
            Write-Warning 'Stopping due to -StopOnError.'
            break
        }
    }

    Write-Output ''
    Write-Output 'Summary:'
    Write-Output "  Total Files : $TotalFiles"
    Write-Output "  Attempted   : $Attempted"
    Write-Output "  Succeeded   : $Succeeded"
    Write-Output "  Failed      : $Failed"
    Write-Output "  Skipped     : $Skipped"
}