function Get-TbTool {
    <#
    .SYNOPSIS
        Liste les outils (hashcat, john) detectes dans le dossier Tools/.
    .EXAMPLE
        Get-TbTool
        Get-TbTool -Tool hashcat
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter()]
        [ValidateSet('hashcat', 'john', 'all')]
        [string]$Tool = 'all'
    )

    $tools = Get-TbInstalledTools

    if ($Tool -ne 'all') {
        $tools = $tools | Where-Object { $_.Name -eq $Tool }
    }

    return $tools
}

function Set-TbActiveTool {
    <#
    .SYNOPSIS
        Definit la version active d'un outil (ecrit dans Config/appsettings.local.json).
    .EXAMPLE
        Set-TbActiveTool -Tool hashcat -ExePath 'C:\Tools\hashcat-7.1.2\hashcat.exe'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ExePath
    )

    if (-not $PSCmdlet.ShouldProcess($ExePath, "Definir comme outil actif ($Tool)")) { return }

    $settings = Get-TbSettings

    if ($Tool -eq 'hashcat') {
        $settings.Tools.hashcat.ActivePath       = $ExePath
        $settings.Tools.hashcat.WorkingDirectory = Split-Path $ExePath -Parent
    } else {
        $settings.Tools.john.ActiveRunPath = Split-Path $ExePath -Parent
        $settings.Tools.john.PerlLibPath   = Join-Path (Split-Path $ExePath -Parent) 'lib'
    }

    Save-TbSettings -Settings $settings
    Write-TbLog -Level Info -Source 'ToolCommands' -Message "Outil actif defini : $Tool = $ExePath"
    Write-Host "[+] Outil actif : $Tool -> $ExePath" -ForegroundColor Green
}

function Install-TbTool {
    <#
    .SYNOPSIS
        Telecharge et installe un outil depuis Config/sources.json.
    .EXAMPLE
        Install-TbTool -Tool hashcat -Version 7.1.2
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool,

        [Parameter()]
        [string]$Version = ''
    )

    $sourcesFile = Join-Path $script:ConfigPath 'sources.json'
    if (-not (Test-Path $sourcesFile)) { throw "sources.json introuvable : $sourcesFile" }

    $sources = (Get-Content $sourcesFile -Raw -Encoding UTF8 | ConvertFrom-Json).Tools.$Tool

    if (-not $sources) { throw "Aucune source definie pour $Tool dans sources.json." }

    $source = if ($Version) {
        $sources | Where-Object { $_.Version -eq $Version } | Select-Object -First 1
    } else {
        $sources | Select-Object -Last 1
    }

    if (-not $source) { throw "Version '$Version' introuvable pour $Tool dans sources.json." }

    if (-not $PSCmdlet.ShouldProcess($source.Url, "Telecharger $Tool $($source.Version)")) { return }

    $toolsDir  = Join-Path $script:RootPath 'Tools'
    $tempFile  = Join-Path $script:TempPath "$Tool-$($source.Version).$($source.ArchiveType)"

    Write-Host "[*] Telechargement de $Tool $($source.Version)..." -ForegroundColor Cyan
    Invoke-TbDownload -Url $source.Url -Destination $tempFile

    if ($source.PSObject.Properties.Name -contains 'Sha256' -and
        -not [string]::IsNullOrWhiteSpace([string]$source.Sha256)) {
        $expectedHash = ([string]$source.Sha256).ToLowerInvariant()
        $actualHash   = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash.ToLowerInvariant()

        if ($actualHash -ne $expectedHash) {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            throw "Checksum SHA256 invalide pour $Tool $($source.Version). Attendu: $expectedHash ; obtenu: $actualHash"
        }

        Write-Host "[+] SHA256 verifie : $actualHash" -ForegroundColor Green
    }

    Write-Host "[*] Extraction vers $toolsDir..." -ForegroundColor Cyan
    Expand-TbArchive -ArchivePath $tempFile -Destination $toolsDir -ArchiveType $source.ArchiveType

    $exeRelPath = Join-Path $toolsDir $source.ExeRelPath
    $exePath = if (Test-Path $exeRelPath) {
        $exeRelPath
    } else {
        $exeName = if ($Tool -eq 'hashcat') { 'hashcat.exe' } else { 'john.exe' }
        Find-TbExeInTools -ToolsDir $toolsDir -ExeName $exeName
    }

    if ($exePath -and (Test-Path $exePath -PathType Leaf)) {
        Set-TbActiveTool -Tool $Tool -ExePath $exePath
        Write-Host "[+] $Tool $($source.Version) installe et actif." -ForegroundColor Green
    } else {
        Write-Warning "Executable introuvable apres extraction : $exeRelPath"
    }

    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
