function New-TbResultObject {
    param(
        [string]$JobId,
        [string]$Hash        = '',
        [string]$Password    = '',
        [string]$HashMode    = '',
        [string]$FoundAt     = ''
    )
    [PSCustomObject]@{
        PSTypeName = 'TongBack.Result'
        JobId      = $JobId
        Hash       = $Hash
        Password   = $Password
        HashMode   = $HashMode
        FoundAt    = if ($FoundAt) { $FoundAt } else { (Get-Date -Format 'o') }
    }
}
