function New-TbToolObject {
    param(
        [string]$Name,
        [string]$Version     = '',
        [string]$ExePath     = '',
        [string]$RunPath     = '',
        [bool]$IsActive      = $false,
        [bool]$IsAvailable   = $false
    )
    [PSCustomObject]@{
        PSTypeName   = 'TongBack.Tool'
        Name         = $Name
        Version      = $Version
        ExePath      = $ExePath
        RunPath      = $RunPath
        IsActive     = $IsActive
        IsAvailable  = $IsAvailable
    }
}
