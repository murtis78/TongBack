function ConvertFrom-JohnList {
    <#
    .SYNOPSIS
        Parse la sortie de "john --list=formats" pour extraire les formats supportes.
    .OUTPUTS
        Tableau de strings (noms de formats)
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Output
    )

    $formats = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $Output) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^(Using|Will|Loaded|Press|Node|Remaining|Session|Status)') { continue }

        $trimmed -split '\s+' | ForEach-Object {
            $f = $_.Trim().TrimEnd(',')
            if ($f -and $f -notmatch '^\d+$') {
                $formats.Add($f)
            }
        }
    }

    return ($formats | Select-Object -Unique | Sort-Object)
}

function Parse-JohnOutput {
    <#
    .SYNOPSIS
        Parse une ligne de sortie john pour detecter un mot de passe trouve.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    $trimmed = $Line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }

    if ($trimmed -match '^(Loaded|Remaining|Session|Status|Press|Using|Will)\b') { return $null }
    if ($trimmed -match '^\d+\s+password\s+hash(?:es)?\s+cracked') { return $null }
    if ($trimmed -match '^\d+g\s+\d+:') { return $null }

    if ($trimmed -match '^(.+?)\s+\((.+?)\)\s*$') {
        return [PSCustomObject]@{ Password = $Matches[1].Trim(); Hash = $Matches[2].Trim() }
    }

    $parts = $trimmed -split ':', 3
    if ($parts.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
        return [PSCustomObject]@{ Hash = $parts[0].Trim(); Password = $parts[1] }
    }

    return $null
}
