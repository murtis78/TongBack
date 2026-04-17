function Invoke-TbProcess {
    <#
    .SYNOPSIS
        Lance un processus externe et capture sa sortie sans deadlock.
    .DESCRIPTION
        Utilise ReadToEndAsync() pour drainer stdout et stderr en parallele,
        puis invoque les callbacks OnOutput/OnError sur le thread principal apres WaitForExit().
        Aucun Invoke-Expression. Les arguments sont passes via ArgumentList.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Executable,

        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter()]
        [string]$WorkingDirectory = '',

        [Parameter()]
        [scriptblock]$OnOutput = $null,

        [Parameter()]
        [scriptblock]$OnError = $null,

        [Parameter()]
        [hashtable]$ProcessRef = $null,

        [Parameter()]
        [scriptblock]$OnStarted = $null,

        [Parameter()]
        [switch]$Wait = $true
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = $Executable
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true

    if ($WorkingDirectory -and (Test-Path $WorkingDirectory -PathType Container)) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

    foreach ($arg in $Arguments) {
        $psi.ArgumentList.Add([string]$arg)
    }

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null

    if ($null -ne $ProcessRef) {
        $ProcessRef['Process'] = $proc
    }

    if ($OnStarted) {
        & $OnStarted $proc
    }

    if ($Wait) {
        # Read both streams concurrently to prevent buffer deadlock
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()

        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()

        # Invoke PS callbacks on main thread (safe — no runspace issues)
        if ($OnOutput) {
            foreach ($line in ($stdout -split "`r?`n")) {
                if ($line.Length -gt 0) { & $OnOutput $line }
            }
        }
        if ($OnError) {
            foreach ($line in ($stderr -split "`r?`n")) {
                if ($line.Length -gt 0) { & $OnError $line }
            }
        }

        return $proc.ExitCode
    }

    # Non-blocking: drain pipes via .NET tasks to prevent buffer deadlock
    $proc.StandardOutput.ReadToEndAsync() | Out-Null
    $proc.StandardError.ReadToEndAsync()  | Out-Null
    return $proc
}

function Stop-TbProcess {
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process
    )
    if (-not $Process.HasExited) {
        try {
            $Process.Kill($true)
        } catch {
            $Process.Kill()
        }
        $Process.WaitForExit(5000) | Out-Null
    }
}
