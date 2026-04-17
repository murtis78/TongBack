function Invoke-TbDownload {
    <#
    .SYNOPSIS
        Telecharge un fichier depuis une URL vers un chemin local.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter()]
        [scriptblock]$OnProgress = $null
    )

    $destDir = Split-Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    }

    Write-TbLog -Level Info -Source 'DownloadService' -Message "Telechargement : $Url" -Data @{ destination = $Destination }

    $client = [System.Net.WebClient]::new()

    if ($OnProgress) {
        $capturedOnProgress = $OnProgress
        $client.add_DownloadProgressChanged({
            param($sender, $e)
            & $capturedOnProgress $e.ProgressPercentage $e.BytesReceived $e.TotalBytesToReceive
        })
    }

    try {
        $client.DownloadFile($Url, $Destination)
        Write-TbLog -Level Info -Source 'DownloadService' -Message "Telechargement termine : $Destination"
    } catch {
        Write-TbLog -Level Error -Source 'DownloadService' -Message "Echec telechargement : $_"
        throw
    } finally {
        $client.Dispose()
    }
}
