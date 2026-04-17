function Find-TbExeInTools {
    # Cherche un exe dans Tools/ en traversant les junctions manuellement
    # (Get-ChildItem -Recurse ne traverse pas les junctions Windows)
    param([string]$ToolsDir, [string]$ExeName)
    foreach ($sub in (Get-ChildItem $ToolsDir -Directory -ErrorAction SilentlyContinue)) {
        $c = Join-Path $sub.FullName $ExeName
        if (Test-Path $c -PathType Leaf) { return $c }
        foreach ($s2 in (Get-ChildItem $sub.FullName -Directory -ErrorAction SilentlyContinue)) {
            $c2 = Join-Path $s2.FullName $ExeName
            if (Test-Path $c2 -PathType Leaf) { return $c2 }
        }
    }
    return $null
}

$script:ExtractorToolMap = [ordered]@{
    # .exe direct
    'bitlocker2john.exe' = @('.bek')
    'dmg2john.exe'       = @('.dmg')
    'gpg2john.exe'       = @('.gpg')
    'hccap2john.exe'     = @('.hccap')
    'keepass2john.exe'   = @('.kdbx')
    'wpapcap2john.exe'   = @('.pcap')
    'putty2john.exe'     = @('.ppk')
    'rar2john.exe'       = @('.rar')
    'zip2john.exe'       = @('.zip')
}

$script:ExtractorPythonMap = [ordered]@{
    '1password2john.py'  = @('.1pif')
    'axcrypt2john.py'    = @('.axx')
    'bitwarden2john.py'  = @('.bwdb')
    'electrum2john.py'   = @('.dat')
    'encfs2john.py'      = @('.encfs6')
    'ethereum2john.py'   = @('.json')
    'keychain2john.py'   = @('.keychain')
    'keepass2john.py'    = @('.kdbx')
    'luks2john.py'       = @('.luks')
    'openssl2john.py'    = @('.pem')
    'pfx2john.py'        = @('.pfx')
    'ssh2john.py'        = @('.pub')
    'pwsafe2john.py'     = @('.pws')
    'mozilla2john.py'    = @('.sqlite')
    'truecrypt2john.py'  = @('.tc')
    'office2john.py'     = @('.accdb','.doc','.docm','.docx','.dot','.dotm','.dotx',
                              '.mdb','.pot','.potm','.potx','.pps','.ppsm','.ppsx',
                              '.ppt','.pptm','.pptx','.vsd','.vsdm','.vsdx',
                              '.xls','.xlsm','.xlsx','.xlt','.xltm','.xltx')
}

$script:ExtractorPerlMap = [ordered]@{
    '7z2john.pl'  = @('.7z')
    'ldif2john.pl' = @('.ldif')
    'pdf2john.pl'  = @('.pdf')
    'vdi2john.pl'  = @('.vdi')
}

function Resolve-TbToolPath {
    <#
    .SYNOPSIS
        Retourne le chemin de l'executable actif pour un outil (hashcat ou john).
        Priorite : configuration chargee > scan Tools/.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool
    )

    $settings = Get-TbSettings

    if ($Tool -eq 'hashcat') {
        $active = $settings.Tools.hashcat.ActivePath
        if (-not [string]::IsNullOrWhiteSpace($active) -and (Test-Path $active -PathType Leaf)) {
            return $active
        }

        $found = Find-TbExeInTools -ToolsDir (Join-Path $script:RootPath 'Tools') -ExeName 'hashcat.exe'
        if ($found) { return $found }

        throw "hashcat.exe introuvable dans Tools/ — utilisez Install-TbTool -Tool hashcat."
    }

    if ($Tool -eq 'john') {
        $active = $settings.Tools.john.ActiveRunPath
        if (-not [string]::IsNullOrWhiteSpace($active) -and (Test-Path $active -PathType Container)) {
            $johnExe = Join-Path $active 'john.exe'
            if (Test-Path $johnExe) { return $johnExe }
        }

        $found = Find-TbExeInTools -ToolsDir (Join-Path $script:RootPath 'Tools') -ExeName 'john.exe'
        if ($found) { return $found }

        throw "john.exe introuvable dans Tools/ — utilisez Install-TbTool -Tool john."
    }
}

function Resolve-TbJohnRunPath {
    [OutputType([string])]
    param()
    $johnExe = Resolve-TbToolPath -Tool 'john'
    return Split-Path $johnExe -Parent
}

function Resolve-TbJohnPerlLib {
    [OutputType([string])]
    param()
    $runPath = Resolve-TbJohnRunPath
    return Join-Path $runPath 'lib'
}

function Get-TbToolVersion {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool
    )
    try {
        $exe = Resolve-TbToolPath -Tool $Tool
        if ($Tool -eq 'hashcat') {
            $output = & $exe --version 2>&1 | Select-Object -First 1
        } else {
            # john n'a pas --version : la premiere ligne du banner contient la version
            $output = & $exe 2>&1 | Select-Object -First 1
        }
        return [string]$output
    } catch {
        return 'inconnu'
    }
}

function Get-TbInstalledTools {
    [OutputType([array])]
    param()

    $toolsDir = Join-Path $script:RootPath 'Tools'
    $result   = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($toolName in @('hashcat', 'john')) {
        $exeName = if ($toolName -eq 'hashcat') { 'hashcat.exe' } else { 'john.exe' }

        # Get-ChildItem -Recurse ne traverse pas les junctions — on itere manuellement
        $subDirs   = Get-ChildItem $toolsDir -Directory -ErrorAction SilentlyContinue
        $instances = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        foreach ($sub in $subDirs) {
            # Chercher dans la racine du sous-dossier
            $candidate = Join-Path $sub.FullName $exeName
            if (Test-Path $candidate -PathType Leaf) {
                $instances.Add([System.IO.FileInfo]::new($candidate))
                continue
            }
            # Chercher un niveau plus bas (ex: john/run/john.exe)
            $sub2 = Get-ChildItem $sub.FullName -Directory -ErrorAction SilentlyContinue
            foreach ($s2 in $sub2) {
                $c2 = Join-Path $s2.FullName $exeName
                if (Test-Path $c2 -PathType Leaf) {
                    $instances.Add([System.IO.FileInfo]::new($c2))
                }
            }
        }

        foreach ($inst in $instances) {
            $isActive = $false
            try {
                $active = Resolve-TbToolPath -Tool $toolName
                $isActive = ($active -eq $inst.FullName)
            } catch {}

            $version = ''
            try {
                if ($toolName -eq 'hashcat') {
                    $v = & $inst.FullName --version 2>&1 | Select-Object -First 1
                } else {
                    $v = & $inst.FullName 2>&1 | Select-Object -First 1
                }
                $version = [string]$v
            } catch {}

            $result.Add((New-TbToolObject -Name $toolName `
                                          -Version $version `
                                          -ExePath $inst.FullName `
                                          -RunPath $inst.DirectoryName `
                                          -IsActive $isActive `
                                          -IsAvailable $true))
        }
    }

    return $result.ToArray()
}
