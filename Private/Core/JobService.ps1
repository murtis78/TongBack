$script:ActiveJobs = [System.Collections.Concurrent.ConcurrentDictionary[string, PSCustomObject]]::new()

# ── Craqueur XOR natif (Word pre-97 obfuscation) ──────────────────────────────

function Get-TbXorVerifier {
    # Calcule le verifier 16-bit XOR selon ECMA-376 / MS-DOC pour une chaine donnee
    param([string]$Password)
    $pb = [System.Text.Encoding]::Latin1.GetBytes($Password)
    $cb = $pb.Length
    $h  = [int]0
    for ($i = $cb - 1; $i -ge 0; $i--) {
        $h = (($h -shr 14) -band 1) -bor (($h -shl 1) -band 0x7FFF)
        $h = $h -bxor $pb[$i]
    }
    $h = (($h -shr 14) -band 1) -bor (($h -shl 1) -band 0x7FFF)
    $h = ($h -bxor $cb) -bxor 0xCE4B
    return $h -band 0xFFFF
}

function Invoke-TbXorCrack {
    # Attaque dictionnaire contre un hash $xor-obf$. Retourne le mot de passe ou $null.
    param(
        [string]$HashString,
        [string]$Wordlist,
        [scriptblock]$OnProgress = $null
    )

    if ($HashString -notmatch '^\$xor-obf\$([0-9a-f]{8})$') {
        throw "Format XOR invalide : $HashString"
    }
    $hex = $Matches[1]
    # Verifier = premier mot 16-bit en little-endian
    $b0 = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $b1 = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $storedVerifier = ($b1 -shl 8) -bor $b0

    $enc    = [System.Text.Encoding]::Latin1
    $reader = [System.IO.StreamReader]::new($Wordlist, $enc)
    $count  = 0
    try {
        while (-not $reader.EndOfStream) {
            $word = $reader.ReadLine()
            if ([string]::IsNullOrEmpty($word)) { continue }
            $count++
            if ($count % 500000 -eq 0 -and $OnProgress) { & $OnProgress "[$count mots tries...]" }
            if ((Get-TbXorVerifier -Password $word) -eq $storedVerifier) {
                return $word
            }
        }
    } finally {
        $reader.Dispose()
    }
    return $null
}

function Set-TbObjectProperty {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($InputObject.PSObject.Properties.Name -contains $Name) {
        $InputObject.$Name = $Value
    } else {
        Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Add-TbJobOutputLine {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,

        [Parameter(Mandatory)]
        [string]$Line
    )

    if (-not ($Job.PSObject.Properties.Name -contains 'Output') -or $null -eq $Job.Output) {
        Set-TbObjectProperty -InputObject $Job -Name 'Output' -Value ([System.Collections.Generic.List[string]]::new())
    }

    if ($Job.Output -is [System.Collections.Generic.List[string]]) {
        $Job.Output.Add($Line)
        return
    }

    $output = [System.Collections.Generic.List[string]]::new()
    foreach ($existing in @($Job.Output)) {
        if ($null -ne $existing) { $output.Add([string]$existing) }
    }
    $output.Add($Line)
    Set-TbObjectProperty -InputObject $Job -Name 'Output' -Value $output
}

function Get-TbHashcatRestoreFilePath {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job
    )

    if ($Job.PSObject.Properties.Name -contains 'SessionFile' -and
        -not [string]::IsNullOrWhiteSpace([string]$Job.SessionFile)) {
        return [string]$Job.SessionFile
    }

    return (Join-Path $script:SessionsPath "$($Job.Id).restore")
}

function Get-TbJohnHashFilePath {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job
    )

    if ($Job.PSObject.Properties.Name -contains 'HashFile' -and
        -not [string]::IsNullOrWhiteSpace([string]$Job.HashFile)) {
        return [string]$Job.HashFile
    }

    return (Join-Path $script:TempPath "$($Job.Id).hash")
}

function Set-TbJobProcess {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,

        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,

        [Parameter()]
        [hashtable]$ProcessRef = $null
    )

    if ($null -ne $ProcessRef) {
        $ProcessRef['Process'] = $Process
    }

    Set-TbObjectProperty -InputObject $Job -Name 'ProcessId' -Value $Process.Id
    Save-TbJob -Job $Job
    Write-TbLog -Level Debug -JobId $Job.Id -Source 'JobService' `
                -Message "Processus externe demarre" -Data @{ processId = $Process.Id }
}

function Set-TbJobFinishedFromExitCode {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,

        [Parameter(Mandatory)]
        [int]$ExitCode
    )

    $Job.ExitCode = $ExitCode
    if ($Job.Status -ne 'Cancelled') {
        $Job.Status = if ($ExitCode -eq 0 -or $ExitCode -eq 1) { 'Completed' } else { 'Failed' }
    }
    $Job.EndTime = (Get-Date -Format 'o')
}

function Save-TbParsedResult {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,

        [Parameter(Mandatory)]
        [string]$Hash,

        [Parameter(Mandatory)]
        [string]$Password,

        [Parameter()]
        [string]$HashMode = ''
    )

    if ([string]::IsNullOrWhiteSpace($Password)) { return }

    $result = New-TbResultObject -JobId $Job.Id -Hash $Hash -Password $Password -HashMode $HashMode
    Save-TbResult -Result $result
    Set-TbObjectProperty -InputObject $Job -Name 'ResultFile' -Value (Join-Path $script:ResultsPath "$($Job.Id).json")
    Write-TbLog -Level Info -JobId $Job.Id -Source 'JobService' `
                -Message "Mot de passe trouve" -Data @{ password = $Password }
}

function Get-TbHashcatShowArguments {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job
    )

    $args = [System.Collections.Generic.List[string]]::new()
    $args.Add('-m'); $args.Add([string]$Job.HashMode)

    foreach ($ea in @($Job.ExtraArgs)) {
        if ($ea -match '^--(username|hex-salt|hex-charset|encoding-from|encoding-to)(=|$)') {
            $args.Add([string]$ea)
        }
    }

    $args.Add([string]$Job.Hash)
    $args.Add('--show')
    return $args.ToArray()
}

function Save-TbHashcatResults {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job
    )

    try {
        $showLines = [System.Collections.Generic.List[string]]::new()
        $exe = Resolve-TbToolPath -Tool 'hashcat'
        $dir = Split-Path $exe -Parent
        Invoke-TbProcess -Executable $exe `
                         -Arguments (Get-TbHashcatShowArguments -Job $Job) `
                         -WorkingDirectory $dir `
                         -OnOutput { param($l) $showLines.Add($l) } `
                         -OnError { param($l) Write-TbLog -Level Debug -JobId $Job.Id -Source 'JobService' -Message "[hashcat --show] $l" } | Out-Null

        foreach ($sl in $showLines) {
            $parsed = Parse-HashcatOutput -Line $sl -ExpectedHash $Job.Hash
            if ($parsed) {
                Save-TbParsedResult -Job $Job -Hash $parsed.Hash -Password $parsed.Password -HashMode ([string]$Job.HashMode)
            }
        }
    } catch {
        Write-TbLog -Level Warning -JobId $Job.Id -Source 'JobService' -Message "Lecture resultats hashcat impossible : $_"
    }
}

function Get-TbJohnShowArguments {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,

        [Parameter(Mandatory)]
        [string]$HashFile
    )

    $args = [System.Collections.Generic.List[string]]::new()
    foreach ($ea in @($Job.ExtraArgs)) {
        if ($ea -match '^--(format|encoding|field-separator-char)(=|$)') {
            $args.Add([string]$ea)
        }
    }

    $args.Add('--show')
    $args.Add($HashFile)
    return $args.ToArray()
}

function Save-TbJohnResults {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job
    )

    $hashFile = Get-TbJohnHashFilePath -Job $Job
    if (-not (Test-Path $hashFile -PathType Leaf)) {
        Write-TbLog -Level Warning -JobId $Job.Id -Source 'JobService' `
                    -Message "Fichier hash John introuvable pour --show : $hashFile"
        return
    }

    try {
        $showLines = [System.Collections.Generic.List[string]]::new()
        Invoke-John -Arguments (Get-TbJohnShowArguments -Job $Job -HashFile $hashFile) `
                    -OnOutput { param($l) $showLines.Add($l) } `
                    -OnError { param($l) Write-TbLog -Level Debug -JobId $Job.Id -Source 'JobService' -Message "[john --show] $l" } | Out-Null

        foreach ($sl in $showLines) {
            $parsed = Parse-JohnOutput -Line $sl
            if ($parsed) {
                Save-TbParsedResult -Job $Job -Hash $parsed.Hash -Password $parsed.Password -HashMode 'john'
            }
        }
    } catch {
        Write-TbLog -Level Warning -JobId $Job.Id -Source 'JobService' -Message "Lecture resultats john impossible : $_"
    }
}

# ── Cycle de vie des jobs ─────────────────────────────────────────────────────

function Start-TbJobInternal {
    <#
    .SYNOPSIS
        Lance un job (hashcat, john, ou XOR natif), gere le cycle de vie et persiste l'etat.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,

        [Parameter()]
        [scriptblock]$OnOutput = $null,

        [Parameter()]
        [scriptblock]$OnError = $null
    )

    try {
        $persistedJob = Load-TbJob -JobId $Job.Id
        if ($persistedJob.Status -eq 'Cancelled') {
            $Job.Status  = 'Cancelled'
            $Job.EndTime = (Get-Date -Format 'o')
            Save-TbJob -Job $Job
            Write-TbLog -Level Info -JobId $Job.Id -Source 'JobService' -Message "Job annule avant demarrage"
            return $Job
        }
    } catch {}

    $Job.Status    = 'Running'
    $Job.StartTime = (Get-Date -Format 'o')
    Save-TbJob -Job $Job

    Write-TbLog -Level Info -JobId $Job.Id -Source 'JobService' -Message "Job demarre" -Data @{
        tool = $Job.Tool; mode = $Job.Mode; hashMode = $Job.HashMode
    }

    $procRef = @{}
    $script:ActiveJobs[$Job.Id] = [PSCustomObject]@{
        Job        = $Job
        ProcessRef = $procRef
    }

    $capturedJob      = $Job
    $capturedOnOutput = $OnOutput
    $capturedOnError  = $OnError

    $outputHandler = {
        param($line)
        if ($null -ne $capturedJob) { Add-TbJobOutputLine -Job $capturedJob -Line $line }
        Write-TbLog -Level Debug -JobId $capturedJob.Id -Source 'JobService' -Message $line
        if ($capturedOnOutput) { & $capturedOnOutput $line }
    }

    $errorHandler = {
        param($line)
        if ($null -ne $capturedJob) { Add-TbJobOutputLine -Job $capturedJob -Line "[ERR] $line" }
        Write-TbLog -Level Warning -JobId $capturedJob.Id -Source 'JobService' -Message "[ERR] $line"
        if ($capturedOnError) { & $capturedOnError $line }
    }

    $startedHandler = {
        param([System.Diagnostics.Process]$process)
        if ($null -ne $capturedJob) {
            Set-TbJobProcess -Job $capturedJob -Process $process -ProcessRef $procRef
        }
    }

    try {
        # ── Branche XOR obfuscation (Word pre-97) : craqueur PS natif ────────
        if ($Job.Hash -match '^\$xor-obf\$') {
            if (-not $Job.Wordlist -or $Job.Wordlist.Count -eq 0) {
                throw "Un wordlist est obligatoire pour cracker un hash XOR obfuscation."
            }
            & $outputHandler "[*] Hash XOR obfuscation detecte — craqueur PS natif"
            & $outputHandler "[*] Wordlist : $($Job.Wordlist[0])"

            $password = Invoke-TbXorCrack -HashString  $Job.Hash `
                                           -Wordlist    $Job.Wordlist[0] `
                                           -OnProgress  $outputHandler
            if ($password) {
                $exitCode = 0
                & $outputHandler "[+] Mot de passe trouve : $password"
                Save-TbParsedResult -Job $Job -Hash $Job.Hash -Password $password -HashMode 'xor-obf'
            } else {
                $exitCode = 1
                & $outputHandler "[-] Mot de passe non trouve dans le wordlist"
            }

        # ── Branche hashcat ───────────────────────────────────────────────────
        } elseif ($Job.Tool -eq 'hashcat') {
            $restoreFile = Get-TbHashcatRestoreFilePath -Job $Job
            Set-TbObjectProperty -InputObject $Job -Name 'SessionFile' -Value $restoreFile
            Save-TbJob -Job $Job

            $hashArgs = Build-HashcatArgs -Mode      $Job.Mode `
                                          -HashMode  $Job.HashMode `
                                          -Hash      $Job.Hash `
                                          -Wordlist  $Job.Wordlist `
                                          -Mask      $Job.Mask `
                                          -ExtraArgs $Job.ExtraArgs `
                                          -SessionName $Job.Id `
                                          -RestoreFilePath $restoreFile

            $exitCode = Invoke-Hashcat -Arguments  $hashArgs `
                                       -OnOutput   $outputHandler `
                                       -OnError    $errorHandler `
                                       -ProcessRef $procRef `
                                       -OnStarted  $startedHandler

        # ── Branche john ──────────────────────────────────────────────────────
        } else {
            $johnArgList = [System.Collections.Generic.List[string]]::new()
            if ($Job.Wordlist -and $Job.Wordlist.Count -gt 0) {
                $johnArgList.Add("--wordlist=$($Job.Wordlist[0])")
            }
            $hashFile = Get-TbJohnHashFilePath -Job $Job
            Set-TbObjectProperty -InputObject $Job -Name 'HashFile' -Value $hashFile
            $Job.Hash | Set-Content -Path $hashFile -Encoding UTF8
            Save-TbJob -Job $Job
            $johnArgList.Add($hashFile)
            foreach ($ea in $Job.ExtraArgs) { $johnArgList.Add($ea) }

            $exitCode = Invoke-John -Arguments  $johnArgList.ToArray() `
                                    -OnOutput   $outputHandler `
                                    -OnError    $errorHandler `
                                    -ProcessRef $procRef `
                                    -OnStarted  $startedHandler
        }

        Set-TbJobFinishedFromExitCode -Job $Job -ExitCode $exitCode

        Write-TbLog -Level Info -JobId $Job.Id -Source 'JobService' `
                    -Message "Job termine (code=$exitCode, status=$($Job.Status))"

        if ($Job.Status -eq 'Completed' -and $Job.Tool -eq 'hashcat') {
            Save-TbHashcatResults -Job $Job
        } elseif ($Job.Status -eq 'Completed' -and $Job.Tool -eq 'john') {
            Save-TbJohnResults -Job $Job
        }

    } catch {
        if ($Job.Status -ne 'Cancelled') {
            $Job.Status = 'Failed'
        }
        $Job.EndTime = (Get-Date -Format 'o')
        Write-TbLog -Level Error -JobId $Job.Id -Source 'JobService' -Message "Job echoue : $_"
    } finally {
        Save-TbJob -Job $Job
        $script:ActiveJobs.TryRemove($Job.Id, [ref]$null) | Out-Null
    }

    return $Job
}

function Stop-TbJobInternal {
    param(
        [Parameter(Mandatory)]
        [string]$JobId
    )

    $updated = $false

    # Mise a jour en memoire si le job est actif
    if ($script:ActiveJobs.ContainsKey($JobId)) {
        $record = $script:ActiveJobs[$JobId]
        $job = if ($record.PSObject.Properties.Name -contains 'Job') { $record.Job } else { $record }
        $process = $null

        if ($record.PSObject.Properties.Name -contains 'ProcessRef' -and
            $null -ne $record.ProcessRef -and
            $record.ProcessRef.ContainsKey('Process')) {
            $process = $record.ProcessRef['Process']
        }

        if ($null -ne $job -and $job.Status -in @('Pending', 'Running')) {
            $job.Status  = 'Cancelled'
            $job.EndTime = (Get-Date -Format 'o')
            Save-TbJob -Job $job

            if ($null -ne $process) {
                try {
                    Stop-TbProcess -Process $process
                    Write-TbLog -Level Info -JobId $JobId -Source 'JobService' `
                                -Message "Processus externe arrete" -Data @{ processId = $process.Id }
                } catch {
                    Write-TbLog -Level Warning -JobId $JobId -Source 'JobService' `
                                -Message "Arret du processus externe impossible : $_"
                }
            }

            Write-TbLog -Level Info -JobId $JobId -Source 'JobService' -Message "Job annule"
            $updated = $true
        }
    }

    # Si pas en memoire, tenter la mise a jour sur disque (ex: job lance depuis un autre runspace)
    if (-not $updated) {
        try {
            $job = Load-TbJob -JobId $JobId
            if ($job.Status -in @('Pending', 'Running')) {
                $job.Status  = 'Cancelled'
                $job.EndTime = (Get-Date -Format 'o')
                Save-TbJob -Job $job

                if ($job.PSObject.Properties.Name -contains 'ProcessId' -and $null -ne $job.ProcessId) {
                    try {
                        $process = Get-Process -Id ([int]$job.ProcessId) -ErrorAction Stop
                        Stop-TbProcess -Process $process
                        Write-TbLog -Level Info -JobId $JobId -Source 'JobService' `
                                    -Message "Processus externe arrete depuis disque" -Data @{ processId = $job.ProcessId }
                    } catch {
                        Write-TbLog -Level Warning -JobId $JobId -Source 'JobService' `
                                    -Message "Processus externe introuvable ou deja arrete : $_"
                    }
                }

                Write-TbLog -Level Info -JobId $JobId -Source 'JobService' -Message "Job annule (depuis disque)"
            }
        } catch { }
    }
}

function Resume-TbJobInternal {
    param(
        [Parameter(Mandatory)]
        [string]$JobId,

        [Parameter()]
        [scriptblock]$OnOutput = $null,

        [Parameter()]
        [scriptblock]$OnError = $null
    )

    $job = Load-TbJob -JobId $JobId

    if ($job.Status -notin @('Paused', 'Failed', 'Cancelled')) {
        throw "Le job $JobId ne peut pas etre repris (statut : $($job.Status))."
    }
    if ($job.Tool -ne 'hashcat') {
        throw "La reprise n'est supportee que pour les jobs hashcat."
    }

    $sessionFile = Get-TbHashcatRestoreFilePath -Job $job
    Set-TbObjectProperty -InputObject $job -Name 'SessionFile' -Value $sessionFile
    if (-not (Test-Path $sessionFile -PathType Leaf)) {
        throw "Fichier de session introuvable : $sessionFile — impossible de reprendre."
    }

    $job.Status    = 'Running'
    $job.StartTime = (Get-Date -Format 'o')
    $job.EndTime   = $null
    Save-TbJob -Job $job

    $procRef = @{}
    $script:ActiveJobs[$job.Id] = [PSCustomObject]@{
        Job        = $job
        ProcessRef = $procRef
    }

    $capturedJob      = $job
    $capturedOnOutput = $OnOutput
    $capturedOnError  = $OnError

    $outputHandler = {
        param($line)
        if ($null -ne $capturedJob) { Add-TbJobOutputLine -Job $capturedJob -Line $line }
        Write-TbLog -Level Debug -JobId $capturedJob.Id -Source 'JobService' -Message $line
        if ($capturedOnOutput) { & $capturedOnOutput $line }
    }

    $errorHandler = {
        param($line)
        if ($null -ne $capturedJob) { Add-TbJobOutputLine -Job $capturedJob -Line "[ERR] $line" }
        Write-TbLog -Level Warning -JobId $capturedJob.Id -Source 'JobService' -Message "[ERR] $line"
        if ($capturedOnError) { & $capturedOnError $line }
    }

    $startedHandler = {
        param([System.Diagnostics.Process]$process)
        if ($null -ne $capturedJob) {
            Set-TbJobProcess -Job $capturedJob -Process $process -ProcessRef $procRef
        }
    }

    try {
        $resumeArgs = @('--session', $JobId, '--restore-file-path', $sessionFile, '--restore')
        $exitCode   = Invoke-Hashcat -Arguments  $resumeArgs `
                                      -OnOutput   $outputHandler `
                                      -OnError    $errorHandler `
                                      -ProcessRef $procRef `
                                      -OnStarted  $startedHandler

        Set-TbJobFinishedFromExitCode -Job $job -ExitCode $exitCode
        Write-TbLog -Level Info -JobId $job.Id -Source 'JobService' `
                    -Message "Reprise terminee (code=$exitCode, status=$($job.Status))"

        if ($job.Status -eq 'Completed') {
            Save-TbHashcatResults -Job $job
        }
    } catch {
        if ($job.Status -ne 'Cancelled') {
            $job.Status = 'Failed'
        }
        $job.EndTime = (Get-Date -Format 'o')
        Write-TbLog -Level Error -JobId $job.Id -Source 'JobService' -Message "Reprise echouee : $_"
    } finally {
        Save-TbJob -Job $job
        $script:ActiveJobs.TryRemove($job.Id, [ref]$null) | Out-Null
    }

    return $job
}
