function Get-TbCapabilityInternal {
    <#
    .SYNOPSIS
        Retourne les capacites d'un outil (hashcat ou john).
        Priorite : cache JSON (< 7 jours) > decouverte dynamique > fallback statique.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool,

        [Parameter()]
        [switch]$ForceRefresh
    )

    $cacheFile = Join-Path $script:DataPath "capabilities\$Tool.json"
    $settings  = Get-TbSettings
    $ttl       = $settings.Capabilities.CacheTtlDays

    if (-not $ForceRefresh -and (Test-Path $cacheFile)) {
        $age = ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalDays
        if ($age -lt $ttl) {
            return (Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
    }

    try {
        $exe = Resolve-TbToolPath -Tool $Tool

        $workDir = Split-Path $exe -Parent

        if ($Tool -eq 'hashcat') {
            $lines = [System.Collections.Generic.List[string]]::new()
            $onOut = { param($l) $lines.Add($l) }
            Invoke-TbProcess -Executable $exe -Arguments @('-hh') `
                             -WorkingDirectory $workDir -OnOutput $onOut | Out-Null
            $modes = ConvertFrom-HashcatHelp -Output $lines.ToArray()
            $cap   = New-TbCapabilityObject -Tool $Tool -HashModes $modes
        } else {
            $lines = [System.Collections.Generic.List[string]]::new()
            $onOut = { param($l) $lines.Add($l) }
            Invoke-TbProcess -Executable $exe -Arguments @('--list=formats') `
                             -WorkingDirectory $workDir -OnOutput $onOut -OnError $onOut | Out-Null
            $formats = ConvertFrom-JohnList -Output $lines.ToArray()
            $cap     = New-TbCapabilityObject -Tool $Tool -Formats $formats
        }

        $capDir = Join-Path $script:DataPath 'capabilities'
        if (-not (Test-Path $capDir)) { New-Item -Path $capDir -ItemType Directory -Force | Out-Null }
        $cap | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Encoding UTF8

        $entryCount = if ($Tool -eq 'hashcat') { @($modes).Count } else { @($formats).Count }
        Write-TbLog -Level Info -Source 'CapabilityService' -Message "Capacites $Tool mises a jour ($entryCount entrees)"
        return $cap

    } catch {
        Write-TbLog -Level Warning -Source 'CapabilityService' -Message "Fallback statique pour $Tool : $_"

        $data = Get-Content (Join-Path $script:DataPath 'HashFormats.json') -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($Tool -eq 'hashcat') {
            $modes = $data.Hashcat.PSObject.Properties | ForEach-Object {
                New-TbHashModeEntry -Mode ([int]$_.Name) -Name $_.Value
            }
            return New-TbCapabilityObject -Tool $Tool -HashModes $modes
        } else {
            return New-TbCapabilityObject -Tool $Tool -Formats $data.John
        }
    }
}
