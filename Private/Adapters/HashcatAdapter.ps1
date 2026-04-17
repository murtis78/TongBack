function Invoke-Hashcat {
    <#
    .SYNOPSIS
        Execute hashcat avec les arguments fournis via Invoke-TbProcess.
        Jamais de Invoke-Expression. Les arguments sont un tableau strict.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [scriptblock]$OnOutput = $null,

        [Parameter()]
        [scriptblock]$OnError = $null,

        [Parameter()]
        [hashtable]$ProcessRef = $null,

        [Parameter()]
        [scriptblock]$OnStarted = $null,

        [Parameter()]
        [switch]$Wait = $true
    )

    $exe = Resolve-TbToolPath -Tool 'hashcat'
    $dir = Split-Path $exe -Parent

    Write-TbLog -Level Debug -Source 'HashcatAdapter' -Message "hashcat $($Arguments -join ' ')"

    return Invoke-TbProcess -Executable $exe `
                            -Arguments $Arguments `
                            -WorkingDirectory $dir `
                            -OnOutput $OnOutput `
                            -OnError $OnError `
                            -ProcessRef $ProcessRef `
                            -OnStarted $OnStarted `
                            -Wait:$Wait
}

function Build-HashcatArgs {
    <#
    .SYNOPSIS
        Construit le tableau d'arguments hashcat depuis les parametres d'un job.
    #>
    param(
        [int]$Mode,
        [int]$HashMode,
        [string]$Hash,
        [string[]]$Wordlist = @(),
        [string]$Mask = '',
        [string[]]$ExtraArgs = @(),
        [string]$SessionName = '',
        [string]$RestoreFilePath = ''
    )

    $args = [System.Collections.Generic.List[string]]::new()
    $args.Add('-m'); $args.Add([string]$HashMode)
    $args.Add('-a'); $args.Add([string]$Mode)

    if ($SessionName) {
        $args.Add('--session')
        $args.Add($SessionName)
    }

    if ($RestoreFilePath) {
        $args.Add('--restore-file-path')
        $args.Add($RestoreFilePath)
    }

    $args.Add($Hash)

    switch ($Mode) {
        0 { foreach ($wl in $Wordlist) { $args.Add($wl) } }
        1 { $args.Add($Wordlist[0]); $args.Add($Wordlist[1]) }
        3 { $args.Add($Mask) }
        6 { $args.Add($Wordlist[0]); $args.Add($Mask) }
        7 { $args.Add($Mask); $args.Add($Wordlist[0]) }
    }

    foreach ($ea in $ExtraArgs) { $args.Add($ea) }

    return $args.ToArray()
}
