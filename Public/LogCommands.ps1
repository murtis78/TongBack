function Get-TbLog {
    <#
    .SYNOPSIS
        Lit les logs JSONL avec filtrage par niveau, jobId ou source.
    .EXAMPLE
        Get-TbLog -Last 50
        Get-TbLog -Level Error
        Get-TbLog -JobId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter()]
        [int]$Last = 100,

        [Parameter()]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Critical', '')]
        [string]$Level = '',

        [Parameter()]
        [string]$JobId = '',

        [Parameter()]
        [string]$Source = ''
    )

    return Get-TbLogInternal -Last $Last -Level $Level -JobId $JobId -Source $Source
}
