<#
.SYNOPSIS
    TongBack v3.0 - CLI entrypoint pour le module TongBack.

.DESCRIPTION
    Point d'entree en ligne de commande. Charge le module TongBack.psm1
    et expose toutes les commandes Tb-prefixees.

    Modes d'utilisation :
      -Help          Affiche cette aide
      -GUI           Lance l'interface graphique WPF
      -Search        Recherche un format de hash
      -Environment   Affiche l'etat de l'environnement
      -Mode          Lance une attaque (0=dict, 1=combo, 3=masque, 6=hybrid, 7=hybrid)

.PARAMETER Help
    Affiche cette aide.

.PARAMETER GUI
    Lance l'interface graphique WPF.

.PARAMETER Search
    Recherche un format de hash. Ex : -Search 'pdf'

.PARAMETER Environment
    Affiche l'etat de l'environnement (outils, chemins).

.PARAMETER Mode
    Mode d'attaque Hashcat : 0, 1, 3, 6, 7.

.PARAMETER HashMode
    Identifiant du format Hashcat (ex: 1000 = NTLM, 10400 = PDF).

.PARAMETER Hash
    Hash a craquer.

.PARAMETER File
    Fichier protege dont le hash sera extrait automatiquement.

.PARAMETER Wordlist
    Un ou deux chemins vers des fichiers de mots de passe.

.PARAMETER Mask
    Masque de brute-force (?l ?u ?d ?s ?a ?b).

.PARAMETER ExtraArgs
    Arguments supplementaires passes directement a hashcat.exe.

.EXAMPLE
    .\TongBack.Cli.ps1 -Search 'pdf'

.EXAMPLE
    .\TongBack.Cli.ps1 -Mode 0 -HashMode 10400 -File .\doc.pdf -Wordlist .\wordlists\rockyou.txt

.EXAMPLE
    .\TongBack.Cli.ps1 -Mode 3 -HashMode 1000 -Hash 'aad3b...' -Mask '?u?l?l?l?d?d?d?d'

.EXAMPLE
    .\TongBack.Cli.ps1 -GUI

.EXAMPLE
    .\TongBack.Cli.ps1 -Environment

.NOTES
    Auteur  : Othmane AZIRAR
    Version : 3.0.0
    Module  : TongBack.psm1
#>
#Requires -Version 7.0

[CmdletBinding(DefaultParameterSetName = 'Attack')]
param(
    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    [Parameter(ParameterSetName = 'GUI')]
    [switch]$GUI,

    [Parameter(ParameterSetName = 'Search', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Search,

    [Parameter(ParameterSetName = 'Environment')]
    [switch]$Environment,

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
    [string[]]$ExtraArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\TongBack.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Error "Module introuvable : $modulePath"
    exit 1
}
Import-Module $modulePath -Force

switch ($PSCmdlet.ParameterSetName) {

    'Help' {
        Show-TongBackLogo
        Get-Help $MyInvocation.MyCommand.Path -Detailed
        exit 0
    }

    'GUI' {
        $guiScript = Join-Path $PSScriptRoot '..\TongBack-GUI.ps1'
        if (-not (Test-Path $guiScript)) {
            Write-Error "TongBack-GUI.ps1 introuvable."
            exit 1
        }
        & $guiScript
        exit 0
    }

    'Search' {
        Show-TongBackLogo
        $result = Find-HashFormat -Search $Search

        if (-not $result.Hashcat -and -not $result.John) {
            Write-Host "  Aucun resultat pour '$Search'." -ForegroundColor Red
            exit 0
        }
        if ($result.Hashcat) {
            Write-Host "  Resultats Hashcat (-m) pour '$Search' :" -ForegroundColor Green
            $result.Hashcat | Format-Table -AutoSize -Property @{L='Mode';E={$_.Mode};W=6}, Name
        }
        if ($result.John) {
            Write-Host "  Resultats John the Ripper pour '$Search' :" -ForegroundColor Green
            $result.John | ForEach-Object { Write-Host "    $_" }
            Write-Host ''
        }
        exit 0
    }

    'Environment' {
        Show-TongBackLogo
        Get-TbEnvironment
        exit 0
    }

    'Attack' {
        Show-TongBackLogo

        if ([string]::IsNullOrWhiteSpace($Hash) -and [string]::IsNullOrWhiteSpace($File)) {
            Write-Error "Specifiez un hash (-Hash) ou un fichier (-File)."
            Write-Host "  Aide : .\TongBack.Cli.ps1 -Help" -ForegroundColor Yellow
            exit 1
        }

        $jobParams = @{
            Tool     = 'hashcat'
            Mode     = $Mode
            HashMode = $HashMode
        }

        if (-not [string]::IsNullOrWhiteSpace($Hash))  { $jobParams['Hash']      = $Hash  }
        if (-not [string]::IsNullOrWhiteSpace($File))  { $jobParams['FilePath']  = $File  }
        if ($Wordlist  -and $Wordlist.Count -gt 0)     { $jobParams['Wordlist']  = $Wordlist }
        if (-not [string]::IsNullOrWhiteSpace($Mask))  { $jobParams['Mask']      = $Mask  }
        if ($ExtraArgs -and $ExtraArgs.Count -gt 0)    { $jobParams['ExtraArgs'] = $ExtraArgs }

        $outputHandler = { param($line) Write-Host $line }
        $jobParams['OnOutput'] = $outputHandler

        try {
            $job = Start-TbJob @jobParams
            if ($job.Status -eq 'Completed') {
                $results = Get-TbResult -JobId $job.Id
                if ($results) {
                    Write-Host ''
                    Write-Host '[+] Mot de passe trouve :' -ForegroundColor Green
                    foreach ($r in $results) {
                        Write-Host "    $($r.Hash) : $($r.Password)" -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host ''
            Write-Host "[!] Erreur : $_" -ForegroundColor Red
            exit 1
        }
    }
}
