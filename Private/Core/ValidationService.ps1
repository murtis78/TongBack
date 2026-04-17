function Invoke-TbValidation {
    <#
    .SYNOPSIS
        Orchestrateur de validation — appelle les validators dans l'ordre.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    $splatArgs = @{}
    if ($Parameters.ContainsKey('Tool'))      { $splatArgs['Tool']      = $Parameters['Tool'] }
    if ($Parameters.ContainsKey('Mode'))      { $splatArgs['Mode']      = $Parameters['Mode'] }
    if ($Parameters.ContainsKey('HashMode'))  { $splatArgs['HashMode']  = $Parameters['HashMode'] }
    if ($Parameters.ContainsKey('Hash'))      { $splatArgs['Hash']      = $Parameters['Hash'] }
    if ($Parameters.ContainsKey('FilePath'))  { $splatArgs['FilePath']  = $Parameters['FilePath'] }
    if ($Parameters.ContainsKey('Wordlist'))  { $splatArgs['Wordlist']  = $Parameters['Wordlist'] }
    if ($Parameters.ContainsKey('Mask'))      { $splatArgs['Mask']      = $Parameters['Mask'] }
    if ($Parameters.ContainsKey('ExtraArgs')) { $splatArgs['ExtraArgs'] = $Parameters['ExtraArgs'] }

    Test-TbArguments @splatArgs
}
