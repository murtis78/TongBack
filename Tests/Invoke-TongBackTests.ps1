#Requires -Version 5.1
<#
.SYNOPSIS
    Lance la suite de tests TongBack.
.DESCRIPTION
    Detecte la version de Pester disponible et invoque TongBack.Tests.ps1 avec
    une configuration compatible Pester 3 ou Pester 5.
.PARAMETER Tag
    Tags Pester a executer.
.PARAMETER ExcludeTag
    Tags Pester a exclure.
.PARAMETER CleanRuntime
    Supprime les artefacts generes dans les dossiers runtime apres les tests.
.EXAMPLE
    .\Tests\Invoke-TongBackTests.ps1
.EXAMPLE
    .\Tests\Invoke-TongBackTests.ps1 -CleanRuntime
#>
[CmdletBinding()]
param(
    [string[]]$Tag = @(),
    [string[]]$ExcludeTag = @(),
    [switch]$CleanRuntime
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$testPath = Join-Path $PSScriptRoot 'TongBack.Tests.ps1'

function Clear-TongBackRuntimeArtifacts {
    $dirs = @(
        'Logs',
        'Sessions',
        'Results',
        'Temp',
        'Data\capabilities'
    )

    foreach ($dir in $dirs) {
        $path = Join-Path $repoRoot $dir
        if (-not (Test-Path $path -PathType Container)) { continue }

        Get-ChildItem -Path $path -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne '.gitkeep' } |
            Remove-Item -Force -ErrorAction SilentlyContinue

        $gitkeep = Join-Path $path '.gitkeep'
        if (-not (Test-Path $gitkeep -PathType Leaf)) {
            New-Item -Path $gitkeep -ItemType File -Force | Out-Null
        }
    }
}

if (-not (Test-Path $testPath -PathType Leaf)) {
    throw "Suite de tests introuvable : $testPath"
}

$pester = Get-Module -ListAvailable Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pester) {
    throw "Pester est introuvable. Installez Pester ou executez les validations manuelles de README."
}

Import-Module $pester.Path -Force

try {
    if ($pester.Version.Major -ge 5) {
        $config = New-PesterConfiguration
        $config.Run.Path = $testPath
        $config.Run.Exit = $true
        if ($Tag.Count -gt 0) { $config.Filter.Tag = $Tag }
        if ($ExcludeTag.Count -gt 0) { $config.Filter.ExcludeTag = $ExcludeTag }
        Invoke-Pester -Configuration $config
    } else {
        $params = @{
            Script = $testPath
            EnableExit = $true
        }
        if ($Tag.Count -gt 0) { $params['Tag'] = $Tag }
        if ($ExcludeTag.Count -gt 0) { $params['ExcludeTag'] = $ExcludeTag }
        Invoke-Pester @params
    }
} finally {
    if ($CleanRuntime) {
        Clear-TongBackRuntimeArtifacts
    }
}
