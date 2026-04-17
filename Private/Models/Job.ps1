function New-TbJobObject {
    param(
        [string]$Tool      = 'hashcat',
        [int]$Mode         = 0,
        [int]$HashMode     = 0,
        [string]$Hash      = '',
        [string]$FilePath  = '',
        [string[]]$Wordlist = @(),
        [string]$Mask      = '',
        [string[]]$ExtraArgs = @()
    )
    [PSCustomObject]@{
        PSTypeName  = 'TongBack.Job'
        Id          = [guid]::NewGuid().ToString()
        Tool        = $Tool
        Mode        = $Mode
        HashMode    = $HashMode
        Hash        = $Hash
        FilePath    = $FilePath
        Wordlist    = $Wordlist
        Mask        = $Mask
        ExtraArgs   = $ExtraArgs
        Status      = 'Pending'
        StartTime   = $null
        EndTime     = $null
        SessionFile = $null
        ResultFile  = $null
        HashFile    = $null
        ProcessId   = $null
        ExitCode    = $null
        Output      = [System.Collections.Generic.List[string]]::new()
    }
}
