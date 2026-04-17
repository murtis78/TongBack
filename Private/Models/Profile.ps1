function New-TbProfileObject {
    param(
        [string]$Name,
        [string]$Tool        = 'hashcat',
        [int]$Mode           = 0,
        [int]$HashMode       = 0,
        [string[]]$Wordlist  = @(),
        [string]$Mask        = '',
        [string[]]$ExtraArgs = @(),
        [string]$Description = ''
    )
    [PSCustomObject]@{
        PSTypeName  = 'TongBack.Profile'
        Id          = [guid]::NewGuid().ToString()
        Name        = $Name
        Tool        = $Tool
        Mode        = $Mode
        HashMode    = $HashMode
        Wordlist    = $Wordlist
        Mask        = $Mask
        ExtraArgs   = $ExtraArgs
        Description = $Description
        CreatedAt   = (Get-Date -Format 'o')
    }
}
