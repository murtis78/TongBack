function Save-TbJob {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job
    )
    $dir = $script:SessionsPath
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $path = Join-Path $dir "$($Job.Id).json"
    $Job | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
}

function Load-TbJob {
    param(
        [Parameter(Mandatory)]
        [string]$JobId
    )
    $path = Join-Path $script:SessionsPath "$JobId.json"
    if (-not (Test-Path $path)) { throw "Session introuvable : $path" }
    Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AllTbJobs {
    $dir = $script:SessionsPath
    if (-not (Test-Path $dir)) { return @() }
    Get-ChildItem $dir -Filter '*.json' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue } |
        Where-Object { $null -ne $_ }
}

function Save-TbResult {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )
    $dir = $script:ResultsPath
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $path = Join-Path $dir "$($Result.JobId).json"

    $results = [System.Collections.Generic.List[object]]::new()
    if (Test-Path $path) {
        $loaded = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue
        foreach ($item in @($loaded)) {
            if ($null -ne $item) { $results.Add($item) }
        }
    }

    $duplicate = $false
    foreach ($existing in $results) {
        if ($existing.Hash -eq $Result.Hash -and $existing.Password -eq $Result.Password) {
            $duplicate = $true
            break
        }
    }

    if (-not $duplicate) {
        $results.Add($Result)
    }

    ConvertTo-Json -InputObject @($results.ToArray()) -Depth 10 |
        Set-Content -Path $path -Encoding UTF8
}

function Load-TbResult {
    param([string]$JobId)
    $path = Join-Path $script:ResultsPath "$JobId.json"
    if (-not (Test-Path $path)) { return $null }
    $loaded = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($loaded)
}

function Get-AllTbResults {
    $dir = $script:ResultsPath
    if (-not (Test-Path $dir)) { return @() }
    $results = [System.Collections.Generic.List[object]]::new()
    Get-ChildItem $dir -Filter '*.json' -ErrorAction SilentlyContinue |
        ForEach-Object {
            $loaded = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue
            foreach ($item in @($loaded)) {
                if ($null -ne $item) { $results.Add($item) }
            }
        }
    return $results.ToArray()
}

function Merge-TbSettingsObject {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Base,

        [Parameter(Mandatory)]
        [PSCustomObject]$Override
    )

    foreach ($property in $Override.PSObject.Properties) {
        $name  = $property.Name
        $value = $property.Value

        if ($Base.PSObject.Properties.Name -contains $name) {
            $baseValue = $Base.$name
            if ($null -ne $baseValue -and
                $null -ne $value -and
                $baseValue -is [PSCustomObject] -and
                $value -is [PSCustomObject]) {
                Merge-TbSettingsObject -Base $baseValue -Override $value | Out-Null
            } else {
                $Base.$name = $value
            }
        } else {
            Add-Member -InputObject $Base -MemberType NoteProperty -Name $name -Value $value
        }
    }

    return $Base
}

function Get-TbSettings {
    $defaultPath = Join-Path $script:ConfigPath 'appsettings.json'
    $localPath   = Join-Path $script:ConfigPath 'appsettings.local.json'

    if (-not (Test-Path $defaultPath)) {
        throw "appsettings.json introuvable : $defaultPath"
    }

    $settings = Get-Content $defaultPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if (Test-Path $localPath) {
        $localSettings = Get-Content $localPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $settings = Merge-TbSettingsObject -Base $settings -Override $localSettings
    }

    return $settings
}

function Save-TbSettings {
    param([Parameter(Mandatory)][PSCustomObject]$Settings)
    $path = Join-Path $script:ConfigPath 'appsettings.local.json'
    $Settings | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
}
