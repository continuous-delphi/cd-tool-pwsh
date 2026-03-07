#requires -Version 7.0
#requires -PSEdition Core

Set-StrictMode -Version Latest

$publicPath = Join-Path $PSScriptRoot 'Public'
$privatePath = Join-Path $PSScriptRoot 'Private'

if (Test-Path -LiteralPath $privatePath -PathType Container) {
    $privateScripts = Get-ChildItem -LiteralPath $privatePath -Filter *.ps1 -File |
        Sort-Object -Property Name

    foreach ($script in $privateScripts) {
        . $script.FullName
    }
}

if (Test-Path -LiteralPath $publicPath -PathType Container) {
    $publicScripts = Get-ChildItem -LiteralPath $publicPath -Filter *.ps1 -File |
        Sort-Object -Property Name

    foreach ($script in $publicScripts) {
        . $script.FullName
    }

    Export-ModuleMember -Function $publicScripts.BaseName
}
else {
    Export-ModuleMember -Function @()
}
