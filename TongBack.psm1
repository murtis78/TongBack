#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Chemins globaux du module ──────────────────────────────────────────────────
$script:RootPath     = $PSScriptRoot
$script:ConfigPath   = Join-Path $PSScriptRoot 'Config'
$script:DataPath     = Join-Path $PSScriptRoot 'Data'
$script:LogsPath     = Join-Path $PSScriptRoot 'Logs'
$script:SessionsPath = Join-Path $PSScriptRoot 'Sessions'
$script:ResultsPath  = Join-Path $PSScriptRoot 'Results'
$script:TempPath     = Join-Path $PSScriptRoot 'Temp'

# ── Creation des repertoires runtime si absents ────────────────────────────────
@(
    $script:LogsPath,
    $script:SessionsPath,
    $script:ResultsPath,
    $script:TempPath,
    (Join-Path $script:DataPath 'capabilities')
) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# ── Dot-source dans l'ordre des dependances ────────────────────────────────────
$script:LoadOrder = @(
    'Private\Models\*.ps1',
    'Private\Infrastructure\*.ps1',
    'Private\Validation\*.ps1',
    'Private\Parsing\*.ps1',
    'Private\Adapters\*.ps1',
    'Private\Core\*.ps1',
    'Public\*.ps1'
)

foreach ($pattern in $script:LoadOrder) {
    $fullPattern = Join-Path $PSScriptRoot $pattern
    Get-ChildItem $fullPattern -ErrorAction SilentlyContinue | ForEach-Object {
        . $_.FullName
    }
}

# ── Exports publics uniquement ────────────────────────────────────────────────
Export-ModuleMember -Function @(
    # 14 commandes v3
    'Get-TbTool', 'Set-TbActiveTool', 'Install-TbTool',
    'Get-TbCapability', 'Update-TbCapability',
    'Start-TbJob', 'Stop-TbJob', 'Resume-TbJob', 'Get-TbJob',
    'Get-TbResult', 'Export-TbResult',
    'Get-TbLog',
    'Get-TbEnvironment',
    'Get-TbHash',
    # Compatibilite v2
    'Show-TongBackLogo', 'Find-HashFormat', 'Get-HashFromFile', 'Start-HashcatAttack'
)
