function Test-TbArguments {
    <#
    .SYNOPSIS
        Valide la coherence des arguments avant de lancer un job.
    #>
    [CmdletBinding()]
    param(
        [string]$Tool      = 'hashcat',
        [int]$Mode         = 0,
        [int]$HashMode     = 0,
        [string]$Hash      = '',
        [string]$FilePath  = '',
        [string[]]$Wordlist = @(),
        [string]$Mask      = '',
        [string[]]$ExtraArgs = @()
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace($Hash) -and [string]::IsNullOrWhiteSpace($FilePath)) {
        $errors.Add("Specifiez un hash (-Hash) ou un fichier (-FilePath).")
    }
    if (-not [string]::IsNullOrWhiteSpace($FilePath) -and -not (Test-Path $FilePath -PathType Leaf)) {
        $errors.Add("Fichier introuvable : $FilePath")
    }

    if ($Tool -eq 'hashcat') {
        if ($Mode -in @(0, 1, 6, 7) -and (-not $Wordlist -or $Wordlist.Count -eq 0)) {
            $errors.Add("Le mode $Mode requiert au moins une wordlist (-Wordlist).")
        }
        if ($Mode -eq 1 -and $Wordlist.Count -lt 2) {
            $errors.Add("Le mode 1 (combinaison) requiert deux wordlists.")
        }
        if ($Mode -in @(3, 6, 7) -and [string]::IsNullOrWhiteSpace($Mask)) {
            $errors.Add("Le mode $Mode requiert un masque (-Mask).")
        }
    }

    if ($Wordlist) {
        foreach ($wl in $Wordlist) {
            if (-not (Test-Path $wl -PathType Leaf)) {
                $errors.Add("Wordlist introuvable : $wl")
            }
        }
    }

    if ($errors.Count -gt 0) {
        throw "Arguments invalides :`n  - $($errors -join "`n  - ")"
    }
}
