function Invoke-Extractor {
    <#
    .SYNOPSIS
        Execute l'outil *2john approprie selon l'extension du fichier.
        Supporte exe, python et perl — jamais de Invoke-Expression.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath
    )

    $runPath = Resolve-TbJohnRunPath
    $perlLib  = Resolve-TbJohnPerlLib
    $ext      = (Get-Item $FilePath).Extension.ToLower()

    $foundTool = $null
    $toolType  = $null

    foreach ($tool in $script:ExtractorToolMap.Keys) {
        if ($script:ExtractorToolMap[$tool] -contains $ext) {
            $foundTool = $tool; $toolType = 'exe'; break
        }
    }
    if (-not $foundTool) {
        foreach ($tool in $script:ExtractorPythonMap.Keys) {
            if ($script:ExtractorPythonMap[$tool] -contains $ext) {
                $foundTool = $tool; $toolType = 'python'; break
            }
        }
    }
    if (-not $foundTool) {
        foreach ($tool in $script:ExtractorPerlMap.Keys) {
            if ($script:ExtractorPerlMap[$tool] -contains $ext) {
                $foundTool = $tool; $toolType = 'perl'; break
            }
        }
    }

    if (-not $foundTool) {
        throw "Extension non supportee : '$ext'. Formats supportes : .pdf .zip .rar .docx .kdbx .pfx .7z et autres."
    }

    $toolPath = Join-Path $runPath $foundTool
    if (-not (Test-Path $toolPath)) {
        throw "Outil introuvable : $toolPath — verifiez que John the Ripper est installe dans Tools/."
    }

    Write-TbLog -Level Debug -Source 'ExtractorAdapter' -Message "Extraction via $foundTool ($toolType) : $FilePath"

    $rawLines = [System.Collections.Generic.List[string]]::new()
    $onOut    = { param($l) $rawLines.Add($l) }
    $onErr    = { param($l) $rawLines.Add($l) }

    switch ($toolType) {
        'exe' {
            Invoke-TbProcess -Executable $toolPath `
                             -Arguments  @($FilePath) `
                             -OnOutput   $onOut `
                             -OnError    $onErr | Out-Null
        }
        'python' {
            $python = Get-Command 'python.exe' -ErrorAction SilentlyContinue
            if (-not $python) { throw "python.exe introuvable dans le PATH." }
            Invoke-TbProcess -Executable $python.Source `
                             -Arguments  @($toolPath, $FilePath) `
                             -OnOutput   $onOut `
                             -OnError    $onErr | Out-Null
        }
        'perl' {
            $perl = Get-Command 'perl.exe' -ErrorAction SilentlyContinue
            if (-not $perl) { throw "perl.exe introuvable dans le PATH." }
            Invoke-TbProcess -Executable $perl.Source `
                             -Arguments  @('-I', $perlLib, $toolPath, $FilePath) `
                             -OnOutput   $onOut `
                             -OnError    $onErr | Out-Null
        }
    }

    $hash = Parse-ExtractorOutput -RawOutput $rawLines.ToArray()

    if ([string]::IsNullOrWhiteSpace($hash)) {
        throw "Impossible d'extraire le hash depuis : $FilePath`nSortie : $($rawLines -join ' | ')"
    }

    return $hash
}
