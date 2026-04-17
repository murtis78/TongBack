function Get-TbProfilesInternal {
    $profilesFile = Join-Path $script:ConfigPath 'profiles.json'
    if (-not (Test-Path $profilesFile)) { return @() }
    $data = Get-Content $profilesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    return $data.Profiles
}

function Save-TbProfileInternal {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Profile
    )

    Test-TbProfile -Profile $Profile | Out-Null

    $profilesFile = Join-Path $script:ConfigPath 'profiles.json'
    $data = if (Test-Path $profilesFile) {
        Get-Content $profilesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        [PSCustomObject]@{ Profiles = @() }
    }

    $existing = $data.Profiles | Where-Object { $_.Id -eq $Profile.Id }
    if ($existing) {
        $data.Profiles = @($data.Profiles | Where-Object { $_.Id -ne $Profile.Id }) + $Profile
    } else {
        $data.Profiles = @($data.Profiles) + $Profile
    }

    $data | ConvertTo-Json -Depth 10 | Set-Content -Path $profilesFile -Encoding UTF8
    Write-TbLog -Level Info -Source 'ProfileService' -Message "Profil sauvegarde : $($Profile.Name)"
}

function Remove-TbProfileInternal {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileId
    )

    $profilesFile = Join-Path $script:ConfigPath 'profiles.json'
    if (-not (Test-Path $profilesFile)) { return }

    $data = Get-Content $profilesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $data.Profiles = @($data.Profiles | Where-Object { $_.Id -ne $ProfileId })
    $data | ConvertTo-Json -Depth 10 | Set-Content -Path $profilesFile -Encoding UTF8
}
