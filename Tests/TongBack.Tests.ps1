$script:TestsPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot  = Split-Path -Parent $script:TestsPath
$script:ModulePath = Join-Path $script:RepoRoot 'TongBack.psm1'
$script:ConfigPath = Join-Path $script:RepoRoot 'Config'
$script:RuntimeDirs = @(
    'Logs',
    'Sessions',
    'Results',
    'Temp',
    'Data\capabilities'
)
$script:TongBackModule = $null

function Invoke-InTongBackModule {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @()
    )

    if (-not $script:TongBackModule) {
        Remove-Module TongBack -Force -ErrorAction SilentlyContinue
        $script:TongBackModule = Import-Module $script:ModulePath -Force -PassThru
    }

    & $script:TongBackModule $ScriptBlock @ArgumentList
}

function Remove-TbTestJobArtifacts {
    param([string]$JobId)

    if ([string]::IsNullOrWhiteSpace($JobId)) { return }

    $paths = @(
        (Join-Path $script:RepoRoot "Sessions\$JobId.json"),
        (Join-Path $script:RepoRoot "Sessions\$JobId.restore"),
        (Join-Path $script:RepoRoot "Results\$JobId.json"),
        (Join-Path $script:RepoRoot "Temp\$JobId.hash")
    )

    foreach ($path in $paths) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
    }
}

function Remove-TbTestFixture {
    param([string]$Name)

    Remove-Item -Path (Join-Path $script:RepoRoot "Temp\$Name") -Force -ErrorAction SilentlyContinue
}

Describe 'TongBack module contract' {
    It 'imports and exposes the public commands' {
        Remove-Module TongBack -Force -ErrorAction SilentlyContinue
        $module = Import-Module $script:ModulePath -Force -PassThru
        $module | Should Not Be $null

        $commands = Get-Command -Module TongBack | Select-Object -ExpandProperty Name
        foreach ($name in @(
            'Get-TbTool',
            'Set-TbActiveTool',
            'Install-TbTool',
            'Start-TbJob',
            'Stop-TbJob',
            'Resume-TbJob',
            'Get-TbResult',
            'Get-TbEnvironment'
        )) {
            ($commands -contains $name) | Should Be $true
        }
    }

    It 'has parseable PowerShell files' {
        $errors = @()
        Get-ChildItem -Path $script:RepoRoot -Recurse -File -Include *.ps1, *.psm1, *.psd1 |
            ForEach-Object {
                $tokens = $null
                $parseErrors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
                if ($parseErrors) {
                    $errors += $parseErrors | ForEach-Object { "$($_.Extent.File):$($_.Extent.StartLineNumber): $($_.Message)" }
                }
            }

        $errors.Count | Should Be 0
    }

    It 'has parseable configuration JSON files' {
        foreach ($file in @('appsettings.json', 'appsettings.template.json', 'sources.json', 'profiles.json')) {
            $jsonPath = Join-Path $script:ConfigPath $file
            $parsed = Get-Content -Path $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $parsed | Should Not Be $null
        }
    }

    It 'has parseable GUI XAML files' {
        $errors = @()
        Get-ChildItem -Path (Join-Path $script:RepoRoot 'Gui') -Recurse -File -Filter *.xaml |
            ForEach-Object {
                try {
                    $null = [xml](Get-Content -Path $_.FullName -Raw -Encoding UTF8)
                } catch {
                    $errors += "$($_.FullName): $_"
                }
            }

        $errors.Count | Should Be 0
    }

    It 'supports zip, 7z and rar archive extraction paths' {
        $archiveService = Get-Content -Path (Join-Path $script:RepoRoot 'Private\Infrastructure\ArchiveService.ps1') -Raw -Encoding UTF8

        ($archiveService -match "\[ValidateSet\('zip', '7z', 'rar', 'auto'\)\]") | Should Be $true
        ($archiveService -match "'\.rar'\s*\{\s*'rar'\s*\}") | Should Be $true
        ($archiveService -match 'WinRAR\.exe') | Should Be $true
        ($archiveService -match 'UnRAR\.exe') | Should Be $true
    }
}

Describe 'TongBack repository hygiene' {
    It 'keeps public appsettings files free of local paths' {
        foreach ($file in @('appsettings.json', 'appsettings.template.json')) {
            $path = Join-Path $script:ConfigPath $file
            $content = Get-Content -Path $path -Raw -Encoding UTF8

            ($content -match 'C:\\\\Users|C:/Users|Desktop\\\\|Desktop/') | Should Be $false

            $settings = $content | ConvertFrom-Json
            [string]$settings.Tools.hashcat.ActivePath | Should Be ''
            [string]$settings.Tools.hashcat.WorkingDirectory | Should Be ''
            [string]$settings.Tools.john.ActiveRunPath | Should Be ''
            [string]$settings.Tools.john.PerlLibPath | Should Be ''
        }
    }

    It 'ignores local configuration and runtime directories' {
        $ignore = Get-Content -Path (Join-Path $script:RepoRoot '.gitignore') -Raw -Encoding UTF8

        foreach ($pattern in @(
            'Config/appsettings.local.json',
            'Tools/*',
            'Logs/*',
            'Sessions/*',
            'Results/*',
            'Temp/*',
            'Data/capabilities/*'
        )) {
            ($ignore -match [regex]::Escape($pattern)) | Should Be $true
        }
    }

    It 'does not mutate appsettings during tool discovery' {
        $settingsPath = Join-Path $script:ConfigPath 'appsettings.json'
        $localPath = Join-Path $script:ConfigPath 'appsettings.local.json'
        $hadLocal = Test-Path $localPath
        $localBefore = if ($hadLocal) { Get-Content -Path $localPath -Raw -Encoding UTF8 } else { $null }
        $before = Get-Content -Path $settingsPath -Raw -Encoding UTF8

        Invoke-InTongBackModule {
            foreach ($tool in @('hashcat', 'john')) {
                try { Resolve-TbToolPath -Tool $tool | Out-Null } catch {}
            }
        }

        $after = Get-Content -Path $settingsPath -Raw -Encoding UTF8
        $after | Should Be $before

        if ($hadLocal) {
            (Get-Content -Path $localPath -Raw -Encoding UTF8) | Should Be $localBefore
        } else {
            (Test-Path $localPath) | Should Be $false
        }
    }

    It 'keeps runtime placeholders present' {
        foreach ($dir in $script:RuntimeDirs) {
            Test-Path (Join-Path $script:RepoRoot "$dir\.gitkeep") | Should Be $true
        }
    }
}

Describe 'TongBack parsing and persistence' {
    It 'parses hashcat output with colon-heavy hashes' {
        Invoke-InTongBackModule {
            $expectedHash = 'user:hash:salt'
            $parsed = Parse-HashcatOutput -Line "${expectedHash}:secret" -ExpectedHash $expectedHash
            $parsed.Hash | Should Be $expectedHash
            $parsed.Password | Should Be 'secret'

            $fallback = Parse-HashcatOutput -Line 'hash:salt:plain'
            $fallback.Hash | Should Be 'hash:salt'
            $fallback.Password | Should Be 'plain'
        }
    }

    It 'parses john runtime and show output' {
        Invoke-InTongBackModule {
            $runtime = Parse-JohnOutput -Line 'secret (document.pdf)'
            $runtime.Hash | Should Be 'document.pdf'
            $runtime.Password | Should Be 'secret'

            $show = Parse-JohnOutput -Line 'document.pdf:secret:extra'
            $show.Hash | Should Be 'document.pdf'
            $show.Password | Should Be 'secret'

            $summary = Parse-JohnOutput -Line '1 password hash cracked, 0 left'
            $summary | Should Be $null
        }
    }

    It 'appends and deduplicates results by hash and password' {
        $jobId = [guid]::NewGuid().ToString()
        try {
            Invoke-InTongBackModule {
                param($jobId)

                $r1 = New-TbResultObject -JobId $jobId -Hash 'h1' -Password 'p1' -HashMode 'test'
                $r2 = New-TbResultObject -JobId $jobId -Hash 'h2' -Password 'p2' -HashMode 'test'
                Save-TbResult -Result $r1
                Save-TbResult -Result $r2
                Save-TbResult -Result $r1

                $loaded = @(Load-TbResult -JobId $jobId)
                $loaded.Count | Should Be 2
                ($loaded | Where-Object { $_.Hash -eq 'h1' -and $_.Password -eq 'p1' }).Count | Should Be 1
                ($loaded | Where-Object { $_.Hash -eq 'h2' -and $_.Password -eq 'p2' }).Count | Should Be 1
            } -ArgumentList @($jobId)
        } finally {
            Remove-TbTestJobArtifacts -JobId $jobId
        }
    }
}

Describe 'TongBack job lifecycle' {
    It 'adds restore-file-path to hashcat arguments' {
        Invoke-InTongBackModule {
            $args = Build-HashcatArgs -Mode 0 -HashMode 0 -Hash 'abc' -Wordlist @('words.txt') `
                                      -SessionName 'session-test' -RestoreFilePath 'Sessions\session-test.restore'

            ($args -contains '--restore-file-path') | Should Be $true
            ($args -contains 'Sessions\session-test.restore') | Should Be $true
        }
    }

    It 'cancels pending jobs without starting external tools' {
        $jobId = [guid]::NewGuid().ToString()
        try {
            Invoke-InTongBackModule {
                param($jobId)

            $job = New-TbJobObject -Tool hashcat -Hash 'dummy'
            $job.Id = $jobId
                Save-TbJob -Job $job
                Stop-TbJobInternal -JobId $job.Id
                (Load-TbJob -JobId $job.Id).Status | Should Be 'Cancelled'
            } -ArgumentList @($jobId)
        } finally {
            Remove-TbTestJobArtifacts -JobId $jobId
        }
    }

    It 'does not start a job already cancelled on disk' {
        $jobId = [guid]::NewGuid().ToString()
        try {
            Invoke-InTongBackModule {
                param($jobId)

            $job = New-TbJobObject -Tool hashcat -Mode 0 -HashMode 0 -Hash 'dummy'
            $job.Id = $jobId
                Save-TbJob -Job $job
                Stop-TbJobInternal -JobId $job.Id
                $returned = Start-TbJobInternal -Job $job
                $returned.Status | Should Be 'Cancelled'
            } -ArgumentList @($jobId)
        } finally {
            Remove-TbTestJobArtifacts -JobId $jobId
        }
    }

    It 'stops a persisted process id' {
        $jobId = [guid]::NewGuid().ToString()
        try {
            Invoke-InTongBackModule {
                param($jobId)

            $exe = (Get-Process -Id $PID).Path
            $proc = Start-Process -FilePath $exe -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -PassThru -WindowStyle Hidden
            $job = New-TbJobObject -Tool hashcat -Hash 'dummy'
            $job.Id = $jobId
            try {
                $job.Status = 'Running'
                $job.ProcessId = $proc.Id
                Save-TbJob -Job $job
                Stop-TbJobInternal -JobId $job.Id
                Start-Sleep -Milliseconds 500
                $proc.Refresh()
                $proc.HasExited | Should Be $true
                (Load-TbJob -JobId $job.Id).Status | Should Be 'Cancelled'
            } finally {
                try {
                    $proc.Refresh()
                    if (-not $proc.HasExited) { $proc.Kill() }
                } catch {}
            }
            } -ArgumentList @($jobId)
        } finally {
            Remove-TbTestJobArtifacts -JobId $jobId
        }
    }
}

Describe 'TongBack GUI integration surface' {
    It 'keeps Start-TbJob callback compatible with WhatIf' {
        $fixture = Join-Path $script:RepoRoot 'Temp\pester-wordlist.txt'
        Set-Content -Path $fixture -Value 'password' -Encoding UTF8

        try {
            $createdId = ''
            $job = Start-TbJob -Tool hashcat -Mode 0 -HashMode 0 -Hash 'dummy' -Wordlist @($fixture) `
                               -WhatIf -OnJobCreated { param($createdJob) $script:createdId = $createdJob.Id }

            $createdId | Should Be ''
            $job.Status | Should Be 'Pending'
        } finally {
            Remove-Item -Path $fixture -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses Stop-TbJob from the GUI stop path' {
        $gui = Get-Content -Path (Join-Path $script:RepoRoot 'TongBack-GUI.ps1') -Raw -Encoding UTF8

        ($gui -match 'function Stop-GuiActiveJob') | Should Be $true
        ($gui -match 'Stop-TbJob -Id \$jobId') | Should Be $true
        ($gui -match 'OnJobCreated') | Should Be $true
        ($gui -match 'Fermer quand meme') | Should Be $false
    }
}
