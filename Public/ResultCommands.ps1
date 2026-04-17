function Get-TbResult {
    <#
    .SYNOPSIS
        Lit les resultats (mots de passe trouves) depuis Results/.
    .EXAMPLE
        Get-TbResult
        Get-TbResult -JobId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter()]
        [string]$JobId = ''
    )

    $results = Get-AllTbResults

    if ($JobId) {
        $results = $results | Where-Object { $_.JobId -eq $JobId }
    }

    return $results
}

function Export-TbResult {
    <#
    .SYNOPSIS
        Exporte les resultats en CSV ou JSON.
    .EXAMPLE
        Export-TbResult -Path .\results.csv -Format CSV
        Export-TbResult -Path .\results.json -Format JSON
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('CSV', 'JSON')]
        [string]$Format = 'CSV',

        [Parameter()]
        [string]$JobId = ''
    )

    $results = Get-TbResult -JobId $JobId

    if (-not $results -or $results.Count -eq 0) {
        Write-Warning "Aucun resultat a exporter."
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Path, "Exporter $($results.Count) resultat(s) en $Format")) { return }

    switch ($Format) {
        'CSV'  { $results | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 }
        'JSON' { $results | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8 }
    }

    Write-Host "[+] $($results.Count) resultat(s) exporte(s) vers : $Path" -ForegroundColor Green
}
