#requires -Version 7.0
#requires -PSEdition Core

Set-StrictMode -Version Latest

Describe 'Set-FileLineEnding' {
    BeforeAll {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $ManifestPath = Join-Path $RepoRoot 'src/ContinuousDelphi.Tools/ContinuousDelphi.Tools.psd1'

        if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
            throw "Module manifest not found: $ManifestPath"
        }

        Import-Module $ManifestPath -Force
    }

    It 'normalizes LF files to CRLF by default' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'unit1.pas'
            [System.IO.File]::WriteAllText($filePath, "line1`nline2`n", [System.Text.UTF8Encoding]::new($false))

            Set-FileLineEnding -Path $TestRoot

            $content = [System.IO.File]::ReadAllText($filePath)
            $content | Should -Be "line1`r`nline2`r`n"
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'honors FileSpec filtering' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $pasPath = Join-Path $TestRoot 'unit1.pas'
            $txtPath = Join-Path $TestRoot 'notes.txt'

            [System.IO.File]::WriteAllText($pasPath, "pas1`npas2`n", [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($txtPath, "txt1`ntxt2`n", [System.Text.UTF8Encoding]::new($false))

            Set-FileLineEnding -Path $TestRoot -FileSpec *.pas

            [System.IO.File]::ReadAllText($pasPath) | Should -Be "pas1`r`npas2`r`n"
            [System.IO.File]::ReadAllText($txtPath) | Should -Be "txt1`ntxt2`n"
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'does NOT search recursively by default' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $SubDir = Join-Path $TestRoot 'src'
        New-Item -ItemType Directory -Path $SubDir -Force | Out-Null

        try {
            $filePath = Join-Path $SubDir 'script.ps1'
            [System.IO.File]::WriteAllText($filePath, "one`ntwo`n", [System.Text.UTF8Encoding]::new($false))

            Set-FileLineEnding -Path $TestRoot

            # Should remain unchanged because recursion is NOT default anymore
            [System.IO.File]::ReadAllText($filePath) | Should -Be "one`ntwo`n"
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'searches recursively when -Recurse is specified' {
      $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
      $SubDir = Join-Path $TestRoot 'src'
      New-Item -ItemType Directory -Path $SubDir -Force | Out-Null

      try {
          $filePath = Join-Path $SubDir 'script.ps1'
          [System.IO.File]::WriteAllText($filePath, "one`ntwo`n", [System.Text.UTF8Encoding]::new($false))

          Set-FileLineEnding -Path $TestRoot -Recurse

          [System.IO.File]::ReadAllText($filePath) | Should -Be "one`r`ntwo`r`n"
      }
      finally {
          if (Test-Path -LiteralPath $TestRoot) {
              Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
          }
      }
    }

    It 'accepts pipeline input' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'build.ps1'
            [System.IO.File]::WriteAllText($filePath, "first`nsecond`n", [System.Text.UTF8Encoding]::new($false))

            Get-ChildItem -LiteralPath $TestRoot -Filter *.ps1 | Set-FileLineEnding

            [System.IO.File]::ReadAllText($filePath) | Should -Be "first`r`nsecond`r`n"
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns result objects with PassThru' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'project.dpr'
            [System.IO.File]::WriteAllText($filePath, "program Project1;`n", [System.Text.UTF8Encoding]::new($false))

            $result = Set-FileLineEnding -Path $TestRoot -PassThru

            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result.Path | Should -Be (Resolve-Path -LiteralPath $filePath).Path
            $result.Changed | Should -BeTrue
            $result.OriginalLineEnding | Should -Be 'LF'
            $result.TargetLineEnding | Should -Be 'CRLF'
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'supports WhatIf without modifying files' {
        $TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        try {
            $filePath = Join-Path $TestRoot 'include.inc'
            [System.IO.File]::WriteAllText($filePath, "a`nb`n", [System.Text.UTF8Encoding]::new($false))

            Set-FileLineEnding -Path $TestRoot -WhatIf

            [System.IO.File]::ReadAllText($filePath) | Should -Be "a`nb`n"
        }
        finally {
            if (Test-Path -LiteralPath $TestRoot) {
                Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns version text when Version is specified' {
        $version = Set-FileLineEnding -Version

        $version | Should -Match '^\d+\.\d+\.\d+$'
    }
}
