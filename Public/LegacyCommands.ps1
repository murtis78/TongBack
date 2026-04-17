function Start-HashcatAttack {
    <#
    .SYNOPSIS
        Alias de compatibilite v2 — delegue vers Start-TbJob.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByHash')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(0, 1, 3, 6, 7)]
        [int]$Mode,

        [Parameter(Mandatory)]
        [ValidateRange(0, 99999)]
        [int]$HashMode,

        [Parameter(Mandatory, ParameterSetName = 'ByHash')]
        [ValidateNotNullOrEmpty()]
        [string]$Hash,

        [Parameter(Mandatory, ParameterSetName = 'ByFile')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [string[]]$Wordlist  = @(),
        [string]$Mask        = '',
        [string[]]$ExtraArgs = @(),
        [switch]$NoShow
    )

    $params = @{
        Tool     = 'hashcat'
        Mode     = $Mode
        HashMode = $HashMode
        Wordlist = $Wordlist
        ExtraArgs = $ExtraArgs
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByFile') {
        $params['FilePath'] = $FilePath
    } else {
        $params['Hash'] = $Hash
    }
    if (-not [string]::IsNullOrWhiteSpace($Mask)) {
        $params['Mask'] = $Mask
    }

    $job = Start-TbJob @params
    return $job
}
