function Test-TbProfile {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Profile
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace($Profile.Name)) {
        $errors.Add("Le nom du profil ne peut pas etre vide.")
    }
    if ($Profile.Tool -notin @('hashcat', 'john')) {
        $errors.Add("Tool doit etre 'hashcat' ou 'john'.")
    }
    if ($Profile.Mode -notin @(0, 1, 3, 6, 7)) {
        $errors.Add("Mode doit etre 0, 1, 3, 6 ou 7.")
    }

    if ($errors.Count -gt 0) {
        throw "Profil invalide : $($errors -join ' | ')"
    }
    return $true
}
