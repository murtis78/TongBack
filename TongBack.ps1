<#
.SYNOPSIS
Hashcat script pour faciliter l'utilisation de l'outil Hashcat.

.DESCRIPTION
Ce script PowerShell simplifie l'utilisation de l'outil Hashcat en fournissant des fonctions pour rechercher des formats de hash, extraire des hashes à partir de fichiers et exécuter des attaques de craquage de mots de passe. Le script prend en charge différents modes d'attaque, l'utilisation de listes de mots et les attaques par force brute.

.PARAMETER help
Affiche l'aide pour le script.

.PARAMETER search
Effectue une recherche de format de hash à l'aide de la chaîne de recherche spécifiée.

.PARAMETER wordlist
Spécifie une ou deux listes de mots pour l'attaque.

.PARAMETER file
Spécifie le fichier contenant le hash ou à partir duquel extraire le hash.

.PARAMETER hash
Spécifie le hash directement.

.PARAMETER hashmode
Spécifie le format de hash à craquer.

.PARAMETER mask
Spécifie le jeu de caractères pour une attaque par force brute.
    ?l = abcdefghijklmnopqrstuvwxyz
    ?u = ABCDEFGHIJKLMNOPQRSTUVWXYZ
    ?d = 0123456789
    ?h = 0123456789abcdef
    ?H = 0123456789ABCDEF
    ?s = «space»!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
    ?a = ?l?u?d?s
    ?b = 0x00 - 0xff

.PARAMETER mode
Spécifie le mode d'attaque (0, 1, 3, 6, 7).
    0 = Attaque par dictionnaire, 
    1 = Attaque par combinaison (Wordlist + Wordlist), 
    3 = Attaque par dictionnaire avec masque (Wordlist + Masque), 
    6 = Attaque hybride (Wordlist + Masque), 
    7 = Attaque hybride (Masque + Wordlist).

.EXAMPLE
.\TongBack.ps1 -mode 1 -hash "votre_hash_ici" -wordlist "liste1.txt" "liste2.txt"

Cet exemple exécute une attaque de craquage de mot de passe en mode 1 en utilisant le hash spécifié et deux listes de mots.

.EXAMPLE
.\TongBack.ps1 -mode 1 -file "chemin\vers\hashes.txt" -wordlist "liste1.txt" "liste2.txt"

Cet exemple exécute une attaque de craquage de mot de passe en mode 1 en utilisant le hash extrait du fichier spécifié et deux listes de mots.

.NOTES
Auteur : Othmane AZIRAR
Version : 1.0

#>


param (
    [switch]$help,
    [string]$search,
    [string[]]$wordlist,
    [string]$file,
    [string]$hash,
    [string]$mask,
    [int]$mode,
    [int]$HashMode
)

function Get-Logo{
    Clear-Host
    Write-Output ""
    Write-Output ""
    Write-Output "               ▓                                   ▓               "
    Write-Output "               ▓▓▓                               ▓▓▓               "
    Write-Output "              ▓▓▓▓▓▓                           ▓▓▓▓▓▓              "
    Write-Output "              ▓▓▓▓▓▓▓▓                       ▓▓▓▓▓▓▓▓              "
    Write-Output "             ▓▓▓▓▓▓▓▓▓▓▓                   ▓▓▓▓▓▓▓▓▓▓▓             "
    Write-Output "             ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓             "
    Write-Output "            ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            "
    Write-Output "            ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            "
    Write-Output "           ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓           "
    Write-Output "        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒       "
    Write-Output "        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒       "
    Write-Output "          ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓         "
    Write-Output "         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓        "
    Write-Output "        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       "
    Write-Output "       ▓▓▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░░░░▓▓▓▓▓▓▓▓▓▓      "
    Write-Output "      ▓▓▓▓▓▓▓▓▓▓▓░░░░░░▓▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓▓░░░░░░▓▓▓▓▓▓▓▓▓▓▓     "
    Write-Output "      ▓▓▓▓▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓░░░░░░░▓▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓▓▓▓▓     "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    "
    Write-Output "      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     "
    Write-Output "      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     "
    Write-Output "       ▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓      "
    Write-Output "        ▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓       "
    Write-Output "         ▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓        "
    Write-Output "          ▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓         "
    Write-Output "           ▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓          "
    Write-Output "            ▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓            "
    Write-Output "              ▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓             "
    Write-Output "                 ▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓                "
    Write-Output "                   ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓                  "
    Write-Output "                     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                    "
    Write-Output "                     ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                    "
    Write-Output "                      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                     "
    Write-Output "                       ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                      "
    Write-Output "                         ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                       "
    Write-Output "                           ▒▒▒▒▒▒▒▒▒▒▒▒▒▒                          "
    Write-Output "                              ▒▒▒▒▒▒▒▒▒▒                           "
    Write-Output ""
    Write-Output ""
}



function Display-Help {
@"
Utilisation : TongBack.ps1 -mode <TypeAttaque> -hash <Hash>|-fichier <CheminFichier> [-search <ChaîneRecherche>] [-wordlist <ListeMots1> [<ListeMots2>]] [-extract] [-mask <JeuxCaractères>]

Options :
    -help           Afficher ce message d'aide.
    -search         Effectuer une recherche de format de hash à l'aide de la chaîne de recherche.
    -wordlist       Spécifier une ou deux listes de mots pour l'attaque.
    -file           Spécifier le fichier contenant le hash ou à partir duquel extraire le hash.
    -hash           Spécifier le hash directement.
    -hashmode       Spécifier le format de hash à craquer (l'option "-search" sert à le trouver)
    -mask           Spécifier le jeu de caractères pour une attaque par force brute (Exemple : ?l?u?d?h?H?s?a?b).
    -mode           Spécifier le mode d'attaque :
                    - 0= Attaque par dictionnaire, 
                    - 1= Attaque par combinaison (Wordlist + Wordlist), 
                    - 3= Attaque par dictionnaire avec masque (Wordlist + Masque), 
                    - 6= Attaque hybride (Wordlist + Masque), 
                    - 7= Attaque hybride (Masque + Wordlist).

Exemples :
    .\TongBack.ps1 -mode 1 -hash "votre_hash_ici" -wordlist "liste1.txt" "liste2.txt"
    .\TongBack.ps1 -mode 1 -fichier "chemin\vers\hashes.txt" -wordlist "liste1.txt" "liste2.txt"
"@
    exit
}



function Find-Format {
    param ([string]$search)
    & "$PSScriptRoot\Find-Format.ps1" -search $search
}



function Get-Hash {
    param (
        [string]$file,
        [string]$hash
    )

    if ($hash) {
        return $hash
    } elseif ($file) {
        $Hash = & "$PSScriptRoot\Get-Hash.ps1" -file $file
        return $Hash
    } else {
        Write-Error "No hash data found or provided."
        exit 1
    }
}



function Get-Attack {
    param (
        [int]$mode,
        [string]$Hash,
        [array]$wordlist,
        [string]$charset
    )
    Begin {
        Write-Verbose "Starting attack mode $mode"
    }
    Process {
        $hashcatExecutable = ".\hashcat.exe"
        $baseArgs = @("-m", $HashMode, "-a", $mode, $Hash)

        switch ($mode) {
            0 { $args = $baseArgs + $wordlist }
            1 { $args = $baseArgs + @($wordlist[0], $wordlist[1]) }
            3 { $args = $baseArgs + @("-1", $charset) }
            6 { $args = $baseArgs + @($wordlist, $charset) }
            7 { $args = $baseArgs + @($charset, $wordlist) }
            default {
                Write-Error "Unsupported attack mode $mode"
                return
            }
        }

        $output = & $hashcatExecutable $args
        Write-Verbose "Hashcat execution output: $output"

        if ($mode -ne 3) {
            $showArgs = $args + "--show"
            $showOutput = & $hashcatExecutable $showArgs
            Write-Verbose "Hashcat show output: $showOutput"
        }
    }
    End {
        Write-Verbose "Completed attack mode $mode"
    }
}

$VerbosePreference = 'Continue'



if ($help) {
    Get-Logo
    Display-Help
} elseif ($search) {
    Get-Logo
    Find-Format $search
} elseif (![string]::IsNullOrWhiteSpace($hash)) {  // Check if the $hash parameter is specified
    $HashData = $hash
} elseif (![string]::IsNullOrWhiteSpace($file)) {
    $HashData = Get-Hash $file
    if (-not $HashData) {
        Write-Error "No hash data found or provided."
        exit 1
    }
} else {
    Write-Error "Either file or hash parameter must not be empty."
    exit 1
}

if ($HashData) {
    try {
        Get-Logo
        Set-Location -Path "$PSScriptRoot\Tools\hashcat-6.2.6"
        Get-Attack -mode $mode -hash $HashData -wordlist $wordlist -charset $mask
    } finally {
        Set-Location -Path "$PSScriptRoot"
    }
}