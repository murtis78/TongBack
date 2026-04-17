function Write-TbLog {
    <#
    .SYNOPSIS
        Ecrit une entree de log au format JSONL dans Logs/tongback-YYYY-MM-DD.jsonl.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$JobId = '',

        [Parameter()]
        [string]$Source = '',

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [hashtable]$Data = @{}
    )

    $entry = [ordered]@{
        timestamp = (Get-Date -Format 'o')
        level     = $Level
        jobId     = $JobId
        source    = $Source
        message   = $Message
        data      = $Data
    }

    $logDir  = $script:LogsPath
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $logFile = Join-Path $logDir "tongback-$(Get-Date -Format 'yyyy-MM-dd').jsonl"
    ($entry | ConvertTo-Json -Compress -Depth 5) | Add-Content -Path $logFile -Encoding UTF8
}

function Get-TbLogInternal {
    param(
        [int]$Last      = 100,
        [string]$Level  = '',
        [string]$JobId  = '',
        [string]$Source = ''
    )

    $logDir = $script:LogsPath
    if (-not (Test-Path $logDir)) { return @() }

    $files = Get-ChildItem $logDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending

    $entries = foreach ($f in $files) {
        Get-Content $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '^\{' } |
            ForEach-Object { $_ | ConvertFrom-Json -ErrorAction SilentlyContinue }
    }

    $result = $entries | Where-Object { $null -ne $_ }

    if ($Level)  { $result = $result | Where-Object { $_.level  -eq $Level  } }
    if ($JobId)  { $result = $result | Where-Object { $_.jobId  -eq $JobId  } }
    if ($Source) { $result = $result | Where-Object { $_.source -eq $Source } }

    $result | Select-Object -Last $Last
}
