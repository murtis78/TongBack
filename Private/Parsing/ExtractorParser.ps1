function Parse-ExtractorOutput {
    <#
    .SYNOPSIS
        Nettoie la sortie brute d'un outil *2john en supprimant le prefixe chemin.
        Convertit les messages XOR obfuscation en format interne $xor-obf$.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$RawOutput
    )

    foreach ($line in $RawOutput) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # XOR obfuscation (Word pre-97) : "... XOR obfuscation detected, Password Verifier : b'e7905ff9'"
        if ($line -match "XOR obfuscation detected.*Password Verifier\s*:\s*b'([0-9a-fA-F]+)'") {
            return "`$xor-obf`$$($Matches[1].ToLower())"
        }

        # Format standard : chemin:hash
        $stripped = $line -replace '^(?:[A-Za-z]:)?[^:]+:', ''
        if ($stripped -ne '' -and -not ($stripped -match '^(\s*WARNING|Error|NOTE|Using|Loaded|No password)')) {
            return $stripped
        }
    }

    return $null
}
