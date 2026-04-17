function Resolve-TbArchiveExecutable {
    param(
        [Parameter(Mandatory)]
        [string[]]$CommandNames,

        [Parameter()]
        [string[]]$FallbackPaths = @()
    )

    foreach ($commandName in $CommandNames) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            if ($command.Source) { return $command.Source }
            if ($command.Path) { return $command.Path }
        }
    }

    foreach ($path in $FallbackPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }

    return $null
}

function Invoke-TbSevenZipExtraction {
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Executable
    )

    $exitCode = Invoke-TbProcess -Executable $Executable `
                                 -Arguments @('x', $ArchivePath, "-o$Destination", '-y') `
                                 -Wait
    if ($exitCode -ne 0) {
        throw "$([System.IO.Path]::GetFileName($Executable)) a echoue avec le code $exitCode."
    }
}

function Invoke-TbRarExtraction {
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Executable
    )

    $destinationPath = [System.IO.Path]::GetFullPath($Destination)
    if (-not $destinationPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $destinationPath = "$destinationPath$([System.IO.Path]::DirectorySeparatorChar)"
    }

    $exeName = [System.IO.Path]::GetFileName($Executable).ToLowerInvariant()
    $arguments = if ($exeName -eq 'winrar.exe') {
        @('x', '-ibck', '-y', $ArchivePath, $destinationPath)
    } else {
        @('x', '-y', $ArchivePath, $destinationPath)
    }

    $exitCode = Invoke-TbProcess -Executable $Executable -Arguments $arguments -Wait
    if ($exitCode -ne 0) {
        throw "$([System.IO.Path]::GetFileName($Executable)) a echoue avec le code $exitCode."
    }
}

function Expand-TbArchive {
    <#
    .SYNOPSIS
        Extrait une archive .zip, .7z ou .rar vers un repertoire de destination.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ArchivePath,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter()]
        [ValidateSet('zip', '7z', 'rar', 'auto')]
        [string]$ArchiveType = 'auto'
    )

    if (-not (Test-Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    }

    $type = $ArchiveType
    if ($type -eq 'auto') {
        $ext = [System.IO.Path]::GetExtension($ArchivePath).ToLower()
        $type = switch ($ext) {
            '.zip' { 'zip' }
            '.7z'  { '7z'  }
            '.rar' { 'rar' }
            default { throw "Type d'archive non supporte : $ext" }
        }
    }

    Write-TbLog -Level Info -Source 'ArchiveService' -Message "Extraction $type : $ArchivePath -> $Destination"

    switch ($type) {
        'zip' {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $Destination)
        }
        '7z' {
            $sevenZipPath = Resolve-TbArchiveExecutable `
                -CommandNames @('7z.exe', '7z') `
                -FallbackPaths @(
                    'C:\Program Files\7-Zip\7z.exe',
                    'C:\Program Files (x86)\7-Zip\7z.exe'
                )

            if ($sevenZipPath) {
                Invoke-TbSevenZipExtraction -ArchivePath $ArchivePath -Destination $Destination -Executable $sevenZipPath
                break
            }

            $winRarPath = Resolve-TbArchiveExecutable `
                -CommandNames @('WinRAR.exe') `
                -FallbackPaths @(
                    'C:\Program Files\WinRAR\WinRAR.exe',
                    'C:\Program Files (x86)\WinRAR\WinRAR.exe'
                )

            if (-not $winRarPath) {
                throw "Aucun extracteur .7z compatible trouve. Installez 7-Zip ou WinRAR, ou ajoutez l'executable au PATH."
            }

            Invoke-TbRarExtraction -ArchivePath $ArchivePath -Destination $Destination -Executable $winRarPath
        }
        'rar' {
            $sevenZipPath = Resolve-TbArchiveExecutable `
                -CommandNames @('7z.exe', '7z') `
                -FallbackPaths @(
                    'C:\Program Files\7-Zip\7z.exe',
                    'C:\Program Files (x86)\7-Zip\7z.exe'
                )

            if ($sevenZipPath) {
                Invoke-TbSevenZipExtraction -ArchivePath $ArchivePath -Destination $Destination -Executable $sevenZipPath
                break
            }

            $rarPath = Resolve-TbArchiveExecutable `
                -CommandNames @('WinRAR.exe', 'UnRAR.exe', 'rar.exe', 'unrar.exe') `
                -FallbackPaths @(
                    'C:\Program Files\WinRAR\WinRAR.exe',
                    'C:\Program Files\WinRAR\UnRAR.exe',
                    'C:\Program Files (x86)\WinRAR\WinRAR.exe',
                    'C:\Program Files (x86)\WinRAR\UnRAR.exe'
                )

            if (-not $rarPath) {
                throw "Aucun extracteur .rar compatible trouve. Installez 7-Zip ou WinRAR, ou ajoutez l'executable au PATH."
            }

            Invoke-TbRarExtraction -ArchivePath $ArchivePath -Destination $Destination -Executable $rarPath
        }
    }

    Write-TbLog -Level Info -Source 'ArchiveService' -Message "Extraction terminee : $Destination"
}
