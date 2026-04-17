function New-TbCapabilityObject {
    param(
        [string]$Tool,
        [object[]]$HashModes  = @(),
        [string[]]$Formats    = @(),
        [datetime]$CachedAt   = (Get-Date)
    )
    [PSCustomObject]@{
        PSTypeName = 'TongBack.Capability'
        Tool       = $Tool
        HashModes  = if ($null -eq $HashModes) { @() } else { @($HashModes) }
        Formats    = if ($null -eq $Formats)   { @() } else { @($Formats) }
        CachedAt   = $CachedAt.ToString('o')
    }
}

function New-TbHashModeEntry {
    param(
        [int]$Mode,
        [string]$Name,
        [string]$Category = ''
    )
    [PSCustomObject]@{
        PSTypeName = 'TongBack.HashModeEntry'
        Mode       = $Mode
        Name       = $Name
        Category   = $Category
    }
}
