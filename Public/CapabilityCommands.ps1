function Get-TbCapability {
    <#
    .SYNOPSIS
        Retourne les capacites d'un outil (modes hashcat ou formats john).
        Utilise le cache Data/capabilities/ si valide (< 7 jours par defaut).
    .EXAMPLE
        Get-TbCapability -Tool hashcat
        Get-TbCapability -Tool hashcat | Select-Object -ExpandProperty HashModes | Where-Object Name -match 'pdf'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool
    )

    return Get-TbCapabilityInternal -Tool $Tool
}

function Update-TbCapability {
    <#
    .SYNOPSIS
        Force le rafraichissement du cache des capacites d'un outil.
    .EXAMPLE
        Update-TbCapability -Tool hashcat
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool
    )

    Write-Host "[*] Mise a jour des capacites $Tool..." -ForegroundColor Cyan
    $cap = Get-TbCapabilityInternal -Tool $Tool -ForceRefresh
    $count = if ($Tool -eq 'hashcat') { $cap.HashModes.Count } else { $cap.Formats.Count }
    Write-Host "[+] $count entrees chargees pour $Tool." -ForegroundColor Green
    return $cap
}

function Find-HashFormat {
    <#
    .SYNOPSIS
        Recherche un format de hash dans les bases Hashcat et John (compat v2).
    .EXAMPLE
        Find-HashFormat -Search 'pdf'
        'ntlm','sha256' | Find-HashFormat
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Search
    )

    process {
        $data = Get-Content (Join-Path $script:DataPath 'HashFormats.json') -Raw -Encoding UTF8 | ConvertFrom-Json

        $hcResults = $data.Hashcat.PSObject.Properties |
            Where-Object { $_.Value -match $Search } |
            ForEach-Object {
                [PSCustomObject]@{
                    PSTypeName = 'TongBack.HashFormat.Hashcat'
                    Mode       = [int]$_.Name
                    Name       = $_.Value
                }
            } |
            Sort-Object Mode

        $johnResults = $data.John | Where-Object { $_ -match $Search } | Sort-Object

        [PSCustomObject]@{
            PSTypeName = 'TongBack.FindHashFormatResult'
            Search     = $Search
            Hashcat    = $hcResults
            John       = $johnResults
        }
    }
}
