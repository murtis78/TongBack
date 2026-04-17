function Start-TbJob {
    <#
    .SYNOPSIS
        Cree et lance un job hashcat ou john.
    .EXAMPLE
        Start-TbJob -Tool hashcat -Mode 0 -HashMode 10400 -FilePath .\doc.pdf -Wordlist .\wordlists\rockyou.txt
        Start-TbJob -Tool hashcat -Mode 3 -HashMode 1000 -Hash 'aad3...' -Mask '?u?l?l?l?d?d?d?d'
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByHash')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool = 'hashcat',

        [Parameter()]
        [ValidateSet(0, 1, 3, 6, 7)]
        [int]$Mode = 0,

        [Parameter()]
        [ValidateRange(0, 99999)]
        [int]$HashMode = 0,

        [Parameter(ParameterSetName = 'ByHash')]
        [string]$Hash = '',

        [Parameter(ParameterSetName = 'ByFile')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath = '',

        [Parameter()]
        [string[]]$Wordlist = @(),

        [Parameter()]
        [string]$Mask = '',

        [Parameter()]
        [string[]]$ExtraArgs = @(),

        [Parameter()]
        [scriptblock]$OnOutput = $null,

        [Parameter()]
        [scriptblock]$OnError = $null,

        [Parameter()]
        [scriptblock]$OnJobCreated = $null
    )

    $validateParams = @{
        Tool     = $Tool
        Mode     = $Mode
        HashMode = $HashMode
        Hash     = $Hash
        FilePath = $FilePath
        Wordlist = $Wordlist
        Mask     = $Mask
        ExtraArgs = $ExtraArgs
    }
    Test-TbArguments @validateParams

    if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
        Write-Host "[*] Extraction du hash depuis : $(Split-Path $FilePath -Leaf)" -ForegroundColor Cyan
        $Hash = Invoke-Extractor -FilePath $FilePath
        Write-Host "[*] Hash extrait : $Hash" -ForegroundColor DarkGray
    }

    $job = New-TbJobObject -Tool $Tool -Mode $Mode -HashMode $HashMode `
                           -Hash $Hash -FilePath $FilePath `
                           -Wordlist $Wordlist -Mask $Mask -ExtraArgs $ExtraArgs

    if (-not $PSCmdlet.ShouldProcess($job.Id, "Lancer job $Tool mode=$Mode hashMode=$HashMode")) { return $job }

    Write-Host "[*] Job $($job.Id) | $Tool mode=$Mode hashMode=$HashMode" -ForegroundColor Cyan
    Save-TbJob -Job $job
    if ($OnJobCreated) { & $OnJobCreated $job }

    return Start-TbJobInternal -Job $job -OnOutput $OnOutput -OnError $OnError
}

function Stop-TbJob {
    <#
    .SYNOPSIS
        Arrete un job en cours (status -> Cancelled).
    .EXAMPLE
        Stop-TbJob -Id 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    if (-not $PSCmdlet.ShouldProcess($Id, "Arreter le job")) { return }

    Stop-TbJobInternal -JobId $Id
    Write-Host "[*] Job $Id arrete." -ForegroundColor Yellow
}

function Resume-TbJob {
    <#
    .SYNOPSIS
        Reprend un job hashcat en pause ou echoue via --restore.
    .EXAMPLE
        Resume-TbJob -Id 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter()]
        [scriptblock]$OnOutput = $null,

        [Parameter()]
        [scriptblock]$OnError = $null
    )

    if (-not $PSCmdlet.ShouldProcess($Id, "Reprendre le job")) { return }

    Write-Host "[*] Reprise du job $Id..." -ForegroundColor Cyan
    return Resume-TbJobInternal -JobId $Id -OnOutput $OnOutput -OnError $OnError
}

function Get-TbJob {
    <#
    .SYNOPSIS
        Liste ou filtre les jobs persistes dans Sessions/.
    .EXAMPLE
        Get-TbJob
        Get-TbJob -Id 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
        Get-TbJob -Status Running
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([array])]
    param(
        [Parameter(ParameterSetName = 'ById')]
        [string]$Id = '',

        [Parameter(ParameterSetName = 'ByStatus')]
        [ValidateSet('Pending', 'Running', 'Paused', 'Completed', 'Failed', 'Cancelled')]
        [string]$Status = '',

        [Parameter(ParameterSetName = 'ByTool')]
        [ValidateSet('hashcat', 'john')]
        [string]$Tool = ''
    )

    $jobs = Get-AllTbJobs

    if ($Id)     { $jobs = $jobs | Where-Object { $_.Id     -eq $Id     } }
    if ($Status) { $jobs = $jobs | Where-Object { $_.Status -eq $Status } }
    if ($Tool)   { $jobs = $jobs | Where-Object { $_.Tool   -eq $Tool   } }

    return $jobs
}
