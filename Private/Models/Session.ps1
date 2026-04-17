function New-TbSessionObject {
    param(
        [string]$JobId,
        [string]$RestoreFile = '',
        [string]$PotFile     = ''
    )
    [PSCustomObject]@{
        PSTypeName   = 'TongBack.Session'
        JobId        = $JobId
        RestoreFile  = $RestoreFile
        PotFile      = $PotFile
        CreatedAt    = (Get-Date -Format 'o')
        UpdatedAt    = (Get-Date -Format 'o')
    }
}
