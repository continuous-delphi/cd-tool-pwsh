#requires -Version 7.0
#requires -PSEdition Core

<#
.SYNOPSIS
Creates a development symlink for the ContinuousDelphi.Tools module
so the module is auto-loaded on every PowerShell session.

.DESCRIPTION
Creates a symbolic link in the current user's PowerShell Modules folder
that points to the module source in this repository.

more info:
https://learn.microsoft.com/en-us/powershell/scripting/learn/shell/creating-profiles?view=powershell-7.5

The script first attempts to create the symlink normally. On modern
Windows systems with Developer Mode enabled, this usually succeeds
without elevation.

If symlink creation fails due to insufficient privileges, the script
automatically relaunches itself with administrator privileges and tries
again.

Developer Mode note:
    Enabling Windows Developer Mode allows symbolic links to be created
    without running PowerShell as Administrator. This can be enabled in:

        Settings -> System -> For developers -> Developer Mode
#>

[CmdletBinding()]
param(
    [switch]$ElevatedRetry
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  $Message" -ForegroundColor Cyan
}

function Write-WarnText {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  warn  $Message" -ForegroundColor Yellow
}

function Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host ''
    Write-Host "FAIL  $Message" -ForegroundColor Red
    Write-Host ''
    throw $Message
}

function Start-ElevatedSelf {
    $argumentList = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-ElevatedRetry'
    )

    Write-WarnText 'Administrator privilege required for this operation.'
    Write-Step 'Restarting script with elevation...'

    Start-Process -FilePath 'pwsh' -Verb RunAs -ArgumentList $argumentList | Out-Null
}

function New-ModuleSymlink {
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    if (Test-Path -LiteralPath $LinkPath) {
        $existingItem = Get-Item -LiteralPath $LinkPath -Force

        if ($existingItem.LinkType -eq 'SymbolicLink') {
            Write-Step 'Removing existing symbolic link...'
            Remove-Item -LiteralPath $LinkPath -Force
        }
        else {
            Fail "Path already exists and is not a symbolic link: $LinkPath`n       Refusing to delete it automatically."
        }
    }

    Write-Step 'Creating symbolic link in PowerShell home directory...'
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
}

Write-Host ''
Write-Host 'ContinuousDelphi.Tools  Install-DevModuleSymlink' -ForegroundColor White
Write-Host '================================================' -ForegroundColor White
Write-Host ''

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$moduleSource = Join-Path $repoRoot 'src/ContinuousDelphi.Tools'
$moduleInstallRoot = Join-Path $HOME 'Documents/PowerShell/Modules'
$linkPath = Join-Path $moduleInstallRoot 'ContinuousDelphi.Tools'

Write-Host "  Repo root : $repoRoot"
Write-Host "  Source    : $moduleSource"
Write-Host "  Link path : $linkPath"
Write-Host ''

if (-not (Test-Path -LiteralPath $moduleSource -PathType Container)) {
    Fail "Module source folder not found: $moduleSource"
}

New-Item -ItemType Directory -Path $moduleInstallRoot -Force | Out-Null

try {
    New-ModuleSymlink -LinkPath $linkPath -TargetPath $moduleSource

    Write-Host ''
    Write-Host 'Symlink created successfully.' -ForegroundColor Green
    Write-Host ''
    Write-Host 'You can now run commands like: ' -ForegroundColor White
    Write-Host '  Test-NonAsciiContent -Version' -ForegroundColor White
    Write-Host ''

    if ($ElevatedRetry) {
        Write-Host 'Press Enter to close this elevated window...' -ForegroundColor Yellow
        [void](Read-Host)
    }
}
catch {
    $message = $_.Exception.Message

    $needsElevation = (
        $message -match 'Administrator privilege required' -or
        $message -match 'client does not possess a required privilege' -or
        $message -match 'A required privilege is not held by the client'
    )

    if ($needsElevation -and -not $ElevatedRetry) {
        Start-ElevatedSelf
        exit 0
    }

    if ($needsElevation -and $ElevatedRetry) {
        Fail 'Symlink creation still failed after elevation attempt.'
    }

    throw
}
