function ConvertFrom-HashcatHelp {
    <#
    .SYNOPSIS
        Parse la sortie de "hashcat.exe --help" pour extraire les modes de hash.
    .OUTPUTS
        Tableau de TongBack.HashModeEntry
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Output
    )

    $modes   = [System.Collections.Generic.List[PSCustomObject]]::new()
    $category = ''
    $inHashSection = $false

    foreach ($line in $Output) {
        # Section header: "- [ Hash modes ] -" (hashcat 7.x) or legacy formats
        if ($line -match '^\s*-?\s*\[\s*Hash\s+modes\s*\]' -or $line -match '^\s*#\s*Hash modes\s*[-=]+') {
            $inHashSection = $true
            continue
        }
        # Break on next section header (both old "[" and new "- [" formats)
        if ($inHashSection -and ($line -match '^\s*-\s*\[\s*(?!Hash\s+modes)' -or ($line -match '^\s*\[' -and $line -notmatch '^\s*\[\s*Hash'))) {
            break
        }
        if (-not $inHashSection) { continue }

        if ($line -match '^\s*-\s*\[\s*(.+?)\s*\]\s*-?\s*$') {
            $category = $Matches[1].Trim()
            continue
        }

        if ($line -match '^\s*(\d+)\s*\|\s*(.+?)\s*$') {
            $modes.Add((New-TbHashModeEntry -Mode ([int]$Matches[1]) -Name $Matches[2].Trim() -Category $category))
        }
    }

    return $modes.ToArray()
}

function Parse-HashcatOutput {
    <#
    .SYNOPSIS
        Parse une ligne de sortie hashcat pour detecter un mot de passe trouve.
    .OUTPUTS
        [PSCustomObject] avec Hash et Password, ou $null
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Line,

        [Parameter()]
        [string]$ExpectedHash = ''
    )

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    if ($Line -match '^\s*(Session|Status|Time|Guess|Speed|Recovered|Progress|Candidates|Hardware|Started|Stopped)\.*:' -or
        $Line -match '^\s*Hash\.(Mode|Target)\.*:') {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedHash)) {
        $prefix = "${ExpectedHash}:"
        if ($Line.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            $password = $Line.Substring($prefix.Length)
            if ($password -and $password -ne '') {
                return [PSCustomObject]@{ Hash = $ExpectedHash; Password = $password }
            }
        }
    }

    $separatorIndex = $Line.LastIndexOf(':')
    if ($separatorIndex -gt 0 -and $separatorIndex -lt ($Line.Length - 1)) {
        $hash     = $Line.Substring(0, $separatorIndex)
        $password = $Line.Substring($separatorIndex + 1)
        if ($password -and $password -ne '') {
            return [PSCustomObject]@{ Hash = $hash; Password = $password }
        }
    }
    return $null
}
