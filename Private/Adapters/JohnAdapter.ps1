function Invoke-John {
    <#
    .SYNOPSIS
        Execute john avec les arguments fournis via Invoke-TbProcess.
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

    $exe = Resolve-TbToolPath -Tool 'john'
    $dir = Split-Path $exe -Parent

    Write-TbLog -Level Debug -Source 'JohnAdapter' -Message "john $($Arguments -join ' ')"

    return Invoke-TbProcess -Executable $exe `
                            -Arguments $Arguments `
                            -WorkingDirectory $dir `
                            -OnOutput $OnOutput `
                            -OnError $OnError `
                            -ProcessRef $ProcessRef `
                            -OnStarted $OnStarted `
                            -Wait:$Wait
}
