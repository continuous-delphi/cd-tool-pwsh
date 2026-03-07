#requires -Version 7.0
#requires -PSEdition Core

Set-StrictMode -Version Latest

Describe 'Test-NonAsciiContent' {
    BeforeAll {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $ManifestPath = Join-Path $RepoRoot 'src/ContinuousDelphi.Tools/ContinuousDelphi.Tools.psd1'

        if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
            throw "Module manifest not found: $ManifestPath"
        }

        Import-Module $ManifestPath -Force
    }

    It 'returns no results for ASCII-only content' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'ascii.md'
            @(
                '# Heading'
                'Plain ASCII text only.'
                'Another ASCII line.'
            ) | Set-Content -LiteralPath $filePath -Encoding utf8

            $result = Test-NonAsciiContent -Path $TestRoot -FileSpec *.md

            $result | Should -BeNullOrEmpty
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns a match object for non-ASCII content' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'nonascii.md'
            @(
                'Plain ASCII line'
                'Contains smart quote: “'
                'Trailing ASCII'
            ) | Set-Content -LiteralPath $filePath -Encoding utf8

            $result = Test-NonAsciiContent -Path $TestRoot -FileSpec *.md

            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result.Path | Should -Be (Resolve-Path -LiteralPath $filePath).Path
            $result.LineNumber | Should -Be 2
            $result.Match | Should -Be '“'
            $result.Line | Should -Be 'Contains smart quote: “'
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'supports multiple file specs' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $mdPath = Join-Path $TestRoot 'doc.md'
            $ps1Path = Join-Path $TestRoot 'script.ps1'
            $txtPath = Join-Path $TestRoot 'notes.txt'

            'ASCII only' | Set-Content -LiteralPath $mdPath -Encoding utf8
            'Non-ASCII: é' | Set-Content -LiteralPath $ps1Path -Encoding utf8
            'Non-ASCII: ü' | Set-Content -LiteralPath $txtPath -Encoding utf8

            $result = Test-NonAsciiContent -Path $TestRoot -FileSpec *.md,*.ps1

            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result.Path | Should -Be (Resolve-Path -LiteralPath $ps1Path).Path
            $result.Match | Should -Be 'é'
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'searches recursively when Recurse is specified' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $subDir = Join-Path $TestRoot 'sub'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null

            $filePath = Join-Path $subDir 'nested.md'
            'Nested non-ASCII: ñ' | Set-Content -LiteralPath $filePath -Encoding utf8

            $resultWithoutRecurse = Test-NonAsciiContent -Path $TestRoot -FileSpec *.md
            $resultWithRecurse = Test-NonAsciiContent -Path $TestRoot -FileSpec *.md -Recurse

            $resultWithoutRecurse | Should -BeNullOrEmpty
            $resultWithRecurse | Should -Not -BeNullOrEmpty
            @($resultWithRecurse).Count | Should -Be 1
            $resultWithRecurse.Path | Should -Be (Resolve-Path -LiteralPath $filePath).Path
            $resultWithRecurse.Match | Should -Be 'ñ'
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns boolean output with Quiet' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $asciiPath = Join-Path $TestRoot 'ascii.md'
            $badPath = Join-Path $TestRoot 'bad.md'

            'ASCII only' | Set-Content -LiteralPath $asciiPath -Encoding utf8
            'Bad char: ™' | Set-Content -LiteralPath $badPath -Encoding utf8

            $hasAsciiOnlyIssue = Test-NonAsciiContent -Path $TestRoot -FileSpec ascii.md -Quiet
            $hasBadIssue = Test-NonAsciiContent -Path $TestRoot -FileSpec bad.md -Quiet

            $hasAsciiOnlyIssue | Should -BeFalse
            $hasBadIssue | Should -BeTrue
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'accepts pipeline input from Get-ChildItem' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'pipe.md'
            'Piped non-ASCII: Ω' | Set-Content -LiteralPath $filePath -Encoding utf8

            $result = Get-ChildItem -LiteralPath $TestRoot -Filter *.md | Test-NonAsciiContent

            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result.Path | Should -Be (Resolve-Path -LiteralPath $filePath).Path
            $result.Match | Should -Be 'Ω'
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns version text when Version is specified' {
        $version = Test-NonAsciiContent -Version

        $version | Should -Match '^\d+\.\d+\.\d+$'
    }
}
