[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$File
)

if (-not (Test-Path $File)) {
    Write-Error "Le fichier spécifié n'existe pas : $File"
    return
}

$ToolsPATH = ".\Tools\john-1.9.0-jumbo-1-win64\run\"

$executableFiles = @{
    "bitlocker2john.exe" = @(".bek")
    "dmg2john.exe" = @(".dmg")
    "gpg2john.exe" = @(".gpg")
    "hccap2john.exe" = @(".hccap")
    "keepass2john.exe" = @(".kdbx")
    "wpapcap2john.exe" = @(".pcap")
    "putty2john.exe" = @(".ppk")
    "racf2john.exe" = @(".racf")
    "rar2john.exe" = @(".rar")
    "uaf2john.exe" = @(".uaf")
    "zip2john.exe" = @(".zip")
}

$pythonFiles = @{
    "1password2john.py" = @(".1pif")
    "multibit2john.py" = @(".aes.wallet")
    "axcrypt2john.py" = @(".axx")
    "bestcrypt2john.py" = @(".bcv")
    "bks2john.py" = @(".bks")
    "bitwarden2john.py" = @(".bwdb")
    "dashlane2john.py" = @(".dashlane")
    "electrum2john.py" = @(".dat")
    "diskcryptor2john.py" = @(".dc")
    "dmg2john.py" = @(".dmg")
    "DPAPImk2john.py" = @(".dpapimk")
    "deepsound2john.py" = @(".ds2")
    "ecryptfs2john.py" = @(".ecryptfs")
    "geli2john.py" = @(".eli")
    "encfs2john.py" = @(".encfs6")
    "enpass2john.py" = @(".enpass")
    "hccapx2john.py" = @(".hccapx")
    "htdigest2john.py" = @(".htdigest")
    "lotus2john.py" = @(".id")
    "keystore2john.py" = @(".jks")
    "ethereum2john.py" = @(".json")
    "keychain2john.py" = @(".keychain")
    "monero2john.py" = @(".keys")
    "kirbi2john.py" = @(".kirbi")
    "known_hosts2john.py" = @(".known_hosts")
    "krb2john.py" = @(".krb")
    "kwallet2john.py" = @(".kwl")
    "lastpass2john.py" = @(".lpdb")
    "luks2john.py" = @(".luks")
    "mcafee_epo2john.py" = @(".mdb")
    "money2john.py" = @(".mny")
    "neo2john.py" = @(".neo")
    "libreoffice2john.py" = @(".odb")
    "pcap2john.py" = @(".pcap")
    "padlock2john.py" = @(".pdl")
    "openssl2john.py" = @(".pem")
    "pem2john.py" = @(".pem")
    "pfx2john.py" = @(".pfx")
    "pgpdisk2john.py" = @(".pgd")
    "pgpsda2john.py" = @(".pgp")
    "pgpwde2john.py" = @(".pgpwde")
    "pse2john.py" = @(".pse")
    "ssh2john.py" = @(".pub")
    "pwsafe2john.py" = @(".pws")
    "cracf2john.py" = @(".racf")
    "adxcsouf2john.py" = @(".souf")
    "mozilla2john.py" = @(".sqlite")
    "truecrypt2john.py" = @(".tc")
    "vmx2john.py" = @(".vmx")
    "filezilla2john.py" = @(".xml")
    "office2john.py" = @(".accdb",".doc",".docm",".docx",".dot",".dotm",".dotx",".mdb",".pot",".potm",".potx",".pps",".ppsm",".ppsx",".ppt",".pptm",".pptx",".vsd",".vsdm",".vsdx",".xls",".xlsm",".xlsx",".xlt",".xltm",".xltx")
}

$perlFiles = @{
    "7z2john.pl" = @(".7z")
    "ldif2john.pl" = @(".ldif")
    "pdf2john.pl" = @(".pdf")
    "vdi2john.pl" = @(".vdi")
}


$fileExtension = (Get-Item $File).Extension.ToLower().TrimStart('.')

$foundTool = $null

$hashType = $fileExtension

if ($executableFiles.Values | Where-Object { $_ -contains ".$fileExtension" }) {
    $foundTool = $executableFiles.Keys | Where-Object { $executableFiles[$_] -contains ".$fileExtension" }
}

if (-not $foundTool -and ($pythonFiles.Values | Where-Object { $_ -contains ".$fileExtension" })) {
    $foundTool = $pythonFiles.Keys | Where-Object { $pythonFiles[$_] -contains ".$fileExtension" }
}

if (-not $foundTool -and ($perlFiles.Values | Where-Object { $_ -contains ".$fileExtension" })) {
    $foundTool = $perlFiles.Keys | Where-Object { $perlFiles[$_] -contains ".$fileExtension" }
}

if (-not $foundTool) {
    Write-Error "Type de fichier non supporté: $fileExtension"
    return
}

if ($executableFiles.ContainsKey($foundTool)) {
    $isExecutable = $true
} elseif ($pythonFiles.ContainsKey($foundTool)) {
    $isPython = $true
} elseif ($perlFiles.ContainsKey($foundTool)) {
    $isPerl = $true
}

$toolPath = Join-Path -Path $ToolsPATH -ChildPath $foundTool

if (-not (Test-Path $toolPath)) {
    Write-Error "L'outil spécifié n'existe pas : $toolPath"
    return
}

if ($isExecutable) {
    $command = "$toolPath $File"
} 
elseif ($isPython) {
    $command = "python.exe $toolPath $File"
}

elseif ($isPerl) {
    $command = "perl.exe $toolPath $File"
}

if ($command) {
    $hashValue = Invoke-Expression $command | ForEach-Object { $_ -replace "^[^:]+:", "" }
    return $hashValue
}

#[PSCustomObject]@{
#    HashType = $hashType
#    HashValue = $hashValue
#}


######## UTILISATION ########
# .\Get-Hash.ps1 -File $File