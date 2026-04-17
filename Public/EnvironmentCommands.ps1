function Get-TbEnvironment {
    <#
    .SYNOPSIS
        Verifie l'etat de l'environnement TongBack (outils, chemins, versions).
    .EXAMPLE
        Get-TbEnvironment
    #>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '  TongBack v3.0 — Environnement' -ForegroundColor Cyan
    Write-Host '  ─────────────────────────────' -ForegroundColor DarkCyan
    Write-Host ''

    $ok  = '[OK]'
    $nok = '[!!]'

    # Hashcat
    try {
        $hc = Resolve-TbToolPath -Tool 'hashcat'
        $ver = Get-TbToolVersion -Tool 'hashcat'
        Write-Host "  $ok  hashcat  : $hc" -ForegroundColor Green
        Write-Host "       version  : $ver" -ForegroundColor DarkGray
    } catch {
        Write-Host "  $nok  hashcat  : INTROUVABLE" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkRed
    }
    Write-Host ''

    # John
    try {
        $john = Resolve-TbToolPath -Tool 'john'
        $ver  = Get-TbToolVersion -Tool 'john'
        Write-Host "  $ok  john     : $john" -ForegroundColor Green
        Write-Host "       version  : $ver" -ForegroundColor DarkGray
    } catch {
        Write-Host "  $nok  john     : INTROUVABLE" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkRed
    }
    Write-Host ''

    # Python
    $python = Get-Command 'python.exe' -ErrorAction SilentlyContinue
    if ($python) {
        Write-Host "  $ok  python   : $($python.Source)" -ForegroundColor Green
    } else {
        Write-Host "  $nok  python   : non trouve dans PATH (optionnel)" -ForegroundColor Yellow
    }

    # Perl
    $perl = Get-Command 'perl.exe' -ErrorAction SilentlyContinue
    if ($perl) {
        Write-Host "  $ok  perl     : $($perl.Source)" -ForegroundColor Green
    } else {
        Write-Host "  $nok  perl     : non trouve dans PATH (optionnel)" -ForegroundColor Yellow
    }
    Write-Host ''

    # Repertoires
    $dirs = @{
        'Config'   = $script:ConfigPath
        'Logs'     = $script:LogsPath
        'Sessions' = $script:SessionsPath
        'Results'  = $script:ResultsPath
        'Temp'     = $script:TempPath
        'Data'     = $script:DataPath
    }

    foreach ($k in $dirs.Keys | Sort-Object) {
        $status = if (Test-Path $dirs[$k]) { "$ok " } else { "$nok" }
        $color  = if (Test-Path $dirs[$k]) { 'Green' } else { 'Red' }
        Write-Host "  $status  $k  : $($dirs[$k])" -ForegroundColor $color
    }
    Write-Host ''
}

function Show-TongBackLogo {
    <#
    .SYNOPSIS
        Affiche le logo ASCII TongBack (compat v2).
    #>
    [CmdletBinding()]
    param()

    try { Clear-Host } catch {}
    $c = 'DarkYellow'
    Write-Host ''
    Write-Host '               ||||                                   ||||               ' -ForegroundColor $c
    Write-Host '               |||||||                             |||||||               ' -ForegroundColor $c
    Write-Host '              ||||||||||                         ||||||||||              ' -ForegroundColor $c
    Write-Host '             |||||||||||||||||||||||||||||||||||||||||||||||||||          ' -ForegroundColor $c
    Write-Host '            ||||||||||||||||||||||||||||||||||||||||||||||||||||          ' -ForegroundColor $c
    Write-Host '           ||||||||||||||||||||||||||||||||||||||||||||||||||||||         ' -ForegroundColor $c
    Write-Host '        :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::       ' -ForegroundColor $c
    Write-Host '          ||||||||||||||||||||||||||||||||||||||||||||||||||||||          ' -ForegroundColor $c
    Write-Host '         ||||||||||||||||||||||||||||||||||||||||||||||||||||||||         ' -ForegroundColor $c
    Write-Host '        ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||        ' -ForegroundColor $c
    Write-Host '       ||||||||||| O  O |||||||||||||||||||||||||| O  O |||||||||||      ' -ForegroundColor $c
    Write-Host '      |||||||||||||||||||||||||||  O  O  ||||||||||||||||||||||||||||    ' -ForegroundColor $c
    Write-Host '     |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||    ' -ForegroundColor $c
    Write-Host '      |||||||||||||||::::::::::::::::::::::::::::::|||||||||||||||||     ' -ForegroundColor $c
    Write-Host '       |||||||||||||| ::::::::::::::::::::::::::: ||||||||||||||||||     ' -ForegroundColor $c
    Write-Host '        |||||||||||||||::::::::::::::::::::::::::||||||||||||||||||||    ' -ForegroundColor $c
    Write-Host '          |||||||||||||||:::::::::::::::::::::::|||||||||||||||||        ' -ForegroundColor $c
    Write-Host '            ||||||||||||| ::::::::::::::::::::  |||||||||||||||          ' -ForegroundColor $c
    Write-Host '              ||||||||||| ::::::::::::::::::::  |||||||||||              ' -ForegroundColor $c
    Write-Host '                 |||||||| ::::::::::::::::::::  ||||||||                 ' -ForegroundColor $c
    Write-Host '                   |||||| ::::::::::::::::::::  ||||||                   ' -ForegroundColor $c
    Write-Host '                     |||| ::::::::::::::::::::  ||||                     ' -ForegroundColor $c
    Write-Host '                      ::: ::::::::::::::::::::  :::                      ' -ForegroundColor $c
    Write-Host '                        : ::::::::::::::::::::  :                        ' -ForegroundColor $c
    Write-Host '                          ::::::::::::::::::::                           ' -ForegroundColor $c
    Write-Host ''
    Write-Host '  TongBack v3.0  —  Hashcat + John the Ripper Wrapper' -ForegroundColor Cyan
    Write-Host '  Auteur : Othmane AZIRAR' -ForegroundColor DarkCyan
    Write-Host ''
}
