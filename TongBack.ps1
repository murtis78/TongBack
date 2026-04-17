<#
.SYNOPSIS
    TongBack v2.0 — Wrapper CLI pour Hashcat et John the Ripper.

.DESCRIPTION
    Simplifie l'utilisation de Hashcat en proposant :
      - La recherche de formats de hash (-Search)
      - L'extraction automatique de hash depuis un fichier (-File)
      - Le lancement d'attaques par dictionnaire, combinaison, masque ou hybride (-Mode)
      - L'ouverture de l'interface graphique WPF (-GUI)

    Ce script est le point d'entrée en ligne de commande. Toute la logique
    métier est dans le module TongBack.psm1.

.PARAMETER Help
    Affiche cette aide.

.PARAMETER GUI
    Lance l'interface graphique WPF (TongBack-GUI.ps1).

.PARAMETER Search
    Recherche un format de hash dans les bases Hashcat et John.
    Accepte une expression régulière. Ex : -Search 'pdf'

.PARAMETER Mode
    Mode d'attaque Hashcat :
        0 = Dictionnaire         (requiert -Wordlist)
        1 = Combinaison          (requiert -Wordlist x2)
        3 = Brute-force masque   (requiert -Mask)
        6 = Hybride Wordlist+Masque
        7 = Hybride Masque+Wordlist

.PARAMETER HashMode
    Identifiant du format Hashcat (ex: 1000 = NTLM, 10400 = PDF 1.1-1.3).
    Utilisez -Search pour le trouver.

.PARAMETER Hash
    Hash à craquer, fourni directement en chaîne.

.PARAMETER File
    Fichier protégé dont le hash sera extrait automatiquement.
    Formats supportés : .pdf, .zip, .rar, .docx, .kdbx, .pfx, etc.

.PARAMETER Wordlist
    Chemin(s) vers les fichiers de mots de passe. Un ou deux chemins selon le mode.

.PARAMETER Mask
    Masque de brute-force. Caractères spéciaux :
        ?l = minuscules   ?u = majuscules   ?d = chiffres
        ?s = spéciaux     ?a = tout         ?b = 0x00-0xff

.PARAMETER ExtraArgs
    Arguments supplémentaires passés directement à hashcat.exe.

.PARAMETER NoShow
    Ne pas afficher le mot de passe retrouvé avec --show après l'attaque.

.EXAMPLE
    .\TongBack.ps1 -Search 'pdf'

.EXAMPLE
    .\TongBack.ps1 -Mode 0 -HashMode 10400 -File .\document.pdf -Wordlist .\wordlists\rockyou.txt

.EXAMPLE
    .\TongBack.ps1 -Mode 3 -HashMode 1000 -Hash 'aad3b...' -Mask '?u?l?l?l?d?d?d?d'

.EXAMPLE
    .\TongBack.ps1 -Mode 1 -HashMode 0 -Hash 'b4b9...' -Wordlist .\wl1.txt .\wl2.txt

.EXAMPLE
    .\TongBack.ps1 -GUI

.NOTES
    Auteur  : Othmane AZIRAR
    Version : 2.0.0
    Module  : TongBack.psm1
#>
#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'Attack')]
param(
    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    [Parameter(ParameterSetName = 'GUI')]
    [switch]$GUI,

    [Parameter(ParameterSetName = 'Search', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Search,

    [Parameter(ParameterSetName = 'Attack')]
    [ValidateSet(0, 1, 3, 6, 7)]
    [int]$Mode,

    [Parameter(ParameterSetName = 'Attack')]
    [ValidateRange(0, 99999)]
    [int]$HashMode,

    [Parameter(ParameterSetName = 'Attack')]
    [string]$Hash,

    [Parameter(ParameterSetName = 'Attack')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$File,

    [Parameter(ParameterSetName = 'Attack')]
    [string[]]$Wordlist,

    [Parameter(ParameterSetName = 'Attack')]
    [string]$Mask,

    [Parameter(ParameterSetName = 'Attack')]
    [string[]]$ExtraArgs,

    [Parameter(ParameterSetName = 'Attack')]
    [switch]$NoShow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Chargement du module ──────────────────────────────────────────────────────
$modulePath = Join-Path $PSScriptRoot 'TongBack.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "Module introuvable : $modulePath"
    exit 1
}
Import-Module $modulePath -Force

# ── Aide ──────────────────────────────────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help) {
    Show-TongBackLogo
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# ── GUI ───────────────────────────────────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'GUI' -or $GUI) {
    $guiScript = Join-Path $PSScriptRoot 'TongBack-GUI.ps1'
    if (-not (Test-Path $guiScript)) {
        Write-Error "TongBack-GUI.ps1 introuvable."
        exit 1
    }
    & $guiScript
    exit 0
}

# ── Recherche ─────────────────────────────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'Search') {
    Show-TongBackLogo
    $result = Find-HashFormat -Search $Search

    if (-not $result.Hashcat -and -not $result.John) {
        Write-Host "  Aucun résultat pour '$Search'." -ForegroundColor Red
        exit 0
    }

    if ($result.Hashcat) {
        Write-Host "  Résultats Hashcat (-m) pour '$Search' :" -ForegroundColor Green
        $result.Hashcat | Format-Table -AutoSize -Property @{L='Mode';E={$_.Mode};W=6}, Name
    }

    if ($result.John) {
        Write-Host "  Résultats John the Ripper pour '$Search' :" -ForegroundColor Green
        $result.John | ForEach-Object { Write-Host "    $_" }
        Write-Host ''
    }
    exit 0
}

# ── Attaque ───────────────────────────────────────────────────────────────────
Show-TongBackLogo

# Vérification qu'au moins une source de hash est fournie
if ([string]::IsNullOrWhiteSpace($Hash) -and [string]::IsNullOrWhiteSpace($File)) {
    Write-Error "Spécifiez un hash (-Hash) ou un fichier (-File)."
    Write-Host "  Aide : .\TongBack.ps1 -Help" -ForegroundColor Yellow
    exit 1
}

$attackParams = @{
    Mode     = $Mode
    HashMode = $HashMode
    NoShow   = $NoShow
}

if (-not [string]::IsNullOrWhiteSpace($Hash))     { $attackParams['Hash']      = $Hash }
if (-not [string]::IsNullOrWhiteSpace($File))     { $attackParams['FilePath']  = $File }
if ($Wordlist -and $Wordlist.Count -gt 0)         { $attackParams['Wordlist']  = $Wordlist }
if (-not [string]::IsNullOrWhiteSpace($Mask))     { $attackParams['Mask']      = $Mask }
if ($ExtraArgs -and $ExtraArgs.Count -gt 0)       { $attackParams['ExtraArgs'] = $ExtraArgs }

try {
    Start-HashcatAttack @attackParams
}
catch {
    Write-Host ''
    Write-Host "[!] Erreur : $_" -ForegroundColor Red
    exit 1
}
