# tools/tag-release.ps1
# Creates and pushes a vX.Y.Z release tag for cd-tool-pwsh.
# Requires: PowerShell 7+, git (on PATH)
#
# Usage:
#   pwsh tools/tag-release.ps1 -Version 1.0.0
#
# This script validates preconditions before touching git:
#   - Version argument matches X.Y.Z semver format
#   - Module manifest exists
#   - ModuleVersion in the manifest matches the Version argument
#   - CHANGELOG.md contains a matching [X.Y.Z] section
#   - Release template exists
#   - Working tree is clean
#   - Current branch matches the default branch on origin
#   - Local HEAD matches origin/defaultBranch
#   - Tag does not already exist locally or on origin

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Write-Host is intentionally used for colored interactive console output.'
)]
param(
    [Parameter(Mandatory = $true, HelpMessage = 'Semantic version to tag, e.g. 1.0.0')]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,

    [Parameter(HelpMessage = 'Skip the branch check when tagging from a non-default branch')]
    [switch]$SkipBranchCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  ok  $Message" -ForegroundColor Green
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

function Invoke-Git {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$GitArgs
    )

    $result = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE):`n$result"
    }

    return $result
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$moduleManifest = Join-Path $repoRoot 'src/ContinuousDelphi.Tools/ContinuousDelphi.Tools.psd1'
$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
$releaseTemplatePath = Join-Path $repoRoot '.github/RELEASE_TEMPLATE.md'
$tag = "v$Version"

Write-Host ''
Write-Host 'cd-tool-pwsh  tag-release' -ForegroundColor White
Write-Host '=========================' -ForegroundColor White
Write-Host "  Version : $Version"
Write-Host "  Tag     : $tag"
Write-Host "  Repo    : $repoRoot"
Write-Host ''

Write-Step 'Checking module manifest...'

if (-not (Test-Path -LiteralPath $moduleManifest -PathType Leaf)) {
    Fail "Module manifest not found: $moduleManifest"
}

try {
    $manifest = Import-PowerShellDataFile -LiteralPath $moduleManifest
}
catch {
    Fail "Failed to read module manifest: $moduleManifest`n$_"
}

if (-not $manifest.ContainsKey('ModuleVersion')) {
    Fail "Module manifest does not define ModuleVersion: $moduleManifest"
}

$moduleVersion = [string]$manifest.ModuleVersion
if ($moduleVersion -ne $Version) {
    Fail "ModuleVersion mismatch. Manifest has '$moduleVersion' but requested tag version is '$Version'."
}

Write-Ok "module manifest found and ModuleVersion matches ($moduleVersion)"

Write-Step 'Checking changelog...'

if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) {
    Fail "CHANGELOG.md not found: $changelogPath"
}

$changelogContent = Get-Content -LiteralPath $changelogPath -Raw -Encoding utf8
if ($changelogContent -notmatch ("(?m)^## \[{0}\]\s+-\s+\d{{4}}-\d{{2}}-\d{{2}}$" -f [regex]::Escape($Version))) {
    Fail "CHANGELOG.md does not contain a section header for [$Version]."
}

Write-Ok "CHANGELOG.md contains [$Version]"

Write-Step 'Checking release template...'

if (-not (Test-Path -LiteralPath $releaseTemplatePath -PathType Leaf)) {
    Fail "Release template not found: $releaseTemplatePath"
}

Write-Ok 'release template found'

Write-Step 'Checking git...'

try {
    $gitVersion = & git --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw
    }
}
catch {
    Fail 'git is not available on PATH.'
}

Write-Ok "git found ($gitVersion)"

Push-Location $repoRoot
try {
    Write-Step 'Checking git repository...'

    $null = & git rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "Not inside a git repository: $repoRoot"
    }

    Write-Ok 'inside git repository'

    Write-Step 'Checking branch...'

    $branch = (Invoke-Git rev-parse --abbrev-ref HEAD).Trim()

    $originHead = & git rev-parse --abbrev-ref origin/HEAD 2>$null
    $defaultBranch = if ($LASTEXITCODE -eq 0 -and $originHead) {
        $originHead.Trim() -replace '^origin/', ''
    }
    else {
        Write-WarnText "origin/HEAD not set; assuming default branch is 'main'"
        'main'
    }

    if (-not $SkipBranchCheck -and $branch -ne $defaultBranch) {
        Fail "Must be on '$defaultBranch' branch to tag a release (currently on '$branch').`n       Switch to $defaultBranch, or use -SkipBranchCheck to override."
    }

    if ($SkipBranchCheck -and $branch -ne $defaultBranch) {
        Write-WarnText "Not on '$defaultBranch' (on '$branch'); -SkipBranchCheck override active"
    }
    else {
        Write-Ok "on branch '$defaultBranch'"
    }

    Write-Step 'Checking working tree...'

    $status = Invoke-Git status --porcelain
    if ($status) {
        Fail "Working tree is not clean. Commit or stash all changes before tagging.`n`n$status"
    }

    Write-Ok 'working tree is clean'

    Write-Step 'Checking for origin remote...'

    $remotes = @((Invoke-Git remote).Trim().Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($remotes -notcontains 'origin') {
        Fail "Remote 'origin' not found. Add it or run this script in a clone with an origin remote."
    }

    Write-Ok 'origin remote found'

    Write-Step 'Fetching tags from origin...'
    Invoke-Git fetch --tags origin | Out-Null
    Write-Ok 'tags fetched'

    Write-Step "Checking HEAD is up-to-date with origin/$defaultBranch..."

    $localRev = (Invoke-Git rev-parse HEAD).Trim()
    $remoteRev = (Invoke-Git rev-parse "origin/$defaultBranch").Trim()

    if ($localRev -ne $remoteRev) {
        $behind = (Invoke-Git rev-list --count "HEAD..origin/$defaultBranch").Trim()
        $ahead = (Invoke-Git rev-list --count "origin/$defaultBranch..HEAD").Trim()

        if ([int]$behind -gt 0 -and [int]$ahead -eq 0) {
            Fail "Local HEAD is $behind commit(s) behind origin/$defaultBranch. Run 'git pull' before tagging."
        }
        elseif ([int]$ahead -gt 0 -and [int]$behind -eq 0) {
            Fail "Local HEAD is $ahead commit(s) ahead of origin/$defaultBranch. Push your changes before tagging."
        }
        else {
            Fail "Local HEAD has diverged from origin/$defaultBranch ($ahead ahead, $behind behind). Reconcile before tagging."
        }
    }

    Write-Ok "HEAD is up-to-date with origin/$defaultBranch"

    Write-Step 'Checking for existing tag...'

    & git show-ref --tags --verify --quiet "refs/tags/$tag" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Fail "Tag '$tag' already exists.`n       To delete locally:  git tag -d $tag`n       To delete on origin: git push origin --delete $tag"
    }

    Write-Ok "tag '$tag' does not exist"

    $tagMessage = "Release $tag"

    Write-Host ''
    Write-Host 'All checks passed.' -ForegroundColor Green
    Write-Host ''

    if ($PSCmdlet.ShouldProcess("origin (tag: $tag, message: '$tagMessage')", 'Create annotated tag and push')) {
        try {
            Write-Step "Creating tag $tag..."
            Invoke-Git tag -a $tag -m $tagMessage
            Write-Ok 'tag created'

            Write-Step 'Pushing tag to origin...'
            Invoke-Git push origin $tag | Out-Null
            Write-Ok 'tag pushed'

            Write-Host ''
            Write-Host "Released: $tag" -ForegroundColor Green
            Write-Host 'The GitHub Actions release workflow should run for this tag.' -ForegroundColor Green
            Write-Host ''
        }
        catch {
            Write-Host ''
            Write-Host 'ERROR: Tag or push failed.' -ForegroundColor Red
            Write-Host $_ -ForegroundColor DarkRed
            Write-Host ''
            Write-Host 'Partial failure - verify and clean up if needed:' -ForegroundColor Yellow

            & git show-ref --tags --verify --quiet "refs/tags/$tag" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host '  Local tag exists. If push failed, delete it with:' -ForegroundColor Yellow
                Write-Host "    git tag -d $tag" -ForegroundColor Yellow
            }

            Write-Host '  Verify origin does not have a partial push:' -ForegroundColor Yellow
            Write-Host "    git ls-remote --tags origin refs/tags/$tag" -ForegroundColor Yellow
            Write-Host ''
            throw
        }
    }
    else {
        Write-WarnText 'WhatIf: would create annotated tag and push to origin'
        Write-Host "    Tag    : $tag" -ForegroundColor Yellow
        Write-Host "    Message: $tagMessage" -ForegroundColor Yellow
        Write-Host ''
    }
}
finally {
    Pop-Location
}
