#Requires -Version 7.0
<#
.SYNOPSIS
    TongBack v3.0 - Interface graphique WPF multi-vues.
.DESCRIPTION
    Charge MainWindow.xaml et gere la navigation entre 7 vues :
    Dashboard, Outils, Formats, Jobs Hashcat, Jobs John, Sessions, Mode Expert.
    Chaque vue utilise les commandes Tb* du module TongBack.psm1.
    L execution des jobs est asynchrone (Runspace + Dispatcher) pour ne jamais
    bloquer l interface.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Windows.Forms

# ── Chargement du module ──────────────────────────────────────────────────────
$modulePath = Join-Path $PSScriptRoot 'TongBack.psm1'
if (-not (Test-Path $modulePath)) { Write-Error "Module introuvable : $modulePath"; exit 1 }
Import-Module $modulePath -Force

# ── Chargement de la fenetre principale ───────────────────────────────────────
$mainXamlPath = Join-Path $PSScriptRoot 'Gui\MainWindow.xaml'
if (-not (Test-Path $mainXamlPath)) { Write-Error "MainWindow.xaml introuvable : $mainXamlPath"; exit 1 }

[xml]$mainXaml = Get-Content $mainXamlPath -Encoding UTF8 -Raw
$mainXaml.Window.RemoveAttribute('x:Class')
$reader = [System.Xml.XmlNodeReader]::new($mainXaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# ── References aux controles principaux ───────────────────────────────────────
$MainContent = $window.FindName('MainContent')
$statusDot   = $window.FindName('statusDot')
$tbStatus    = $window.FindName('tbStatus')

$navButtons = @{
    Dashboard   = $window.FindName('btnNavDashboard')
    Tools       = $window.FindName('btnNavTools')
    Formats     = $window.FindName('btnNavFormats')
    JobsHashcat = $window.FindName('btnNavJobsHashcat')
    JobsJohn    = $window.FindName('btnNavJobsJohn')
    Sessions    = $window.FindName('btnNavSessions')
    ModeExpert  = $window.FindName('btnNavExpert')
}

$script:CurrentJobRunspace   = $null
$script:CurrentJobPowerShell = $null
$script:CurrentJobHandle     = $null
$script:CurrentJobState      = $null
$script:CurrentView          = 'Dashboard'
$script:GuiRoot              = $PSScriptRoot

# ── Helpers UI ────────────────────────────────────────────────────────────────
function Set-Status {
    param([string]$Text, [string]$Color = '#39d353')
    $window.Dispatcher.Invoke([Action]{
        $tbStatus.Text = $Text
        $statusDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    })
}

function Add-OutputLine {
    param(
        [AllowNull()]
        [System.Windows.Controls.TextBox]$OutputBox,

        [Parameter(Mandatory)]
        [string]$Line
    )

    if ($null -eq $OutputBox) { return }
    $OutputBox.Text += "$Line`n"
    $OutputBox.ScrollToEnd()
}

function Test-GuiJobRunning {
    return ($null -ne $script:CurrentJobState -and
            $script:CurrentJobState.ContainsKey('IsRunning') -and
            [bool]$script:CurrentJobState['IsRunning'])
}

function Get-GuiCurrentJobId {
    if ($null -eq $script:CurrentJobState -or -not $script:CurrentJobState.ContainsKey('Id')) {
        return ''
    }
    return [string]$script:CurrentJobState['Id']
}

function Clear-CompletedGuiJob {
    if (Test-GuiJobRunning) { return }

    if ($null -ne $script:CurrentJobPowerShell -and $null -ne $script:CurrentJobHandle) {
        try {
            if ($script:CurrentJobHandle.IsCompleted) {
                $script:CurrentJobPowerShell.EndInvoke($script:CurrentJobHandle) | Out-Null
            }
        } catch {}
    }

    if ($null -ne $script:CurrentJobPowerShell) {
        try { $script:CurrentJobPowerShell.Dispose() } catch {}
        $script:CurrentJobPowerShell = $null
    }
    if ($null -ne $script:CurrentJobRunspace) {
        try { $script:CurrentJobRunspace.Close(); $script:CurrentJobRunspace.Dispose() } catch {}
        $script:CurrentJobRunspace = $null
    }
    $script:CurrentJobHandle = $null
}

function Stop-GuiActiveJob {
    param(
        [AllowNull()]
        [System.Windows.Controls.TextBox]$OutputBox,

        [AllowNull()]
        [System.Windows.Controls.Button]$BtnStart,

        [AllowNull()]
        [System.Windows.Controls.Button]$BtnStop,

        [switch]$CloseRunspace
    )

    if ($null -ne $script:CurrentJobState) {
        $script:CurrentJobState['StopRequested'] = $true
    }

    $jobId = Get-GuiCurrentJobId
    if (-not [string]::IsNullOrWhiteSpace($jobId)) {
        try {
            Stop-TbJob -Id $jobId
            Add-OutputLine -OutputBox $OutputBox -Line "[*] Arret demande pour le job $jobId"
            Set-Status -Text 'Arret demande...' -Color '#e3b341'
        } catch {
            Add-OutputLine -OutputBox $OutputBox -Line "[!] Arret impossible : $_"
            Set-Status -Text 'Erreur arret' -Color '#f85149'
        }
    } else {
        Add-OutputLine -OutputBox $OutputBox -Line "[*] Arret demande avant initialisation du job."
        if ($null -ne $script:CurrentJobState) {
            $script:CurrentJobState['IsRunning'] = $false
        }
        if ($null -ne $script:CurrentJobRunspace) {
            try { $script:CurrentJobRunspace.Close() } catch {}
        }
        Set-Status -Text 'Arret demande...' -Color '#e3b341'
    }

    if ($null -ne $BtnStop) { $BtnStop.IsEnabled = $false }
    if ($null -ne $BtnStart -and [string]::IsNullOrWhiteSpace($jobId)) { $BtnStart.IsEnabled = $true }
    if ($CloseRunspace -and $null -ne $script:CurrentJobRunspace) {
        try { $script:CurrentJobRunspace.Close() } catch {}
    }
}

function Load-XamlView {
    param([string]$ViewName)
    $path = Join-Path $script:GuiRoot "Gui\Views\${ViewName}View.xaml"
    if (-not (Test-Path $path)) { return $null }
    [xml]$xaml = Get-Content $path -Encoding UTF8 -Raw
    $xaml.UserControl.RemoveAttribute('x:Class')
    $r = [System.Xml.XmlNodeReader]::new($xaml)
    return [System.Windows.Markup.XamlReader]::Load($r)
}

function Set-NavActive {
    param([string]$ViewName)
    $activeStyle  = $window.Resources['SidebarButtonActive']
    $normalStyle  = $window.Resources['SidebarButton']
    foreach ($k in $navButtons.Keys) {
        $navButtons[$k].Style = if ($k -eq $ViewName) { $activeStyle } else { $normalStyle }
    }
}

# ── Navigation principale ─────────────────────────────────────────────────────
function Navigate-To {
    param([string]$ViewName)
    $script:CurrentView = $ViewName
    Set-NavActive -ViewName $ViewName
    $view = Load-XamlView -ViewName $ViewName
    if (-not $view) {
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.Text       = "Vue '$ViewName' introuvable."
        $tb.Foreground = [System.Windows.Media.Brushes]::Gray
        $tb.Margin     = [System.Windows.Thickness]::new(24)
        $MainContent.Content = $tb
        return
    }
    $MainContent.Content = $view
    Wire-View -ViewName $ViewName -View $view
}

# ── Runspace asynchrone pour les jobs ─────────────────────────────────────────
function Start-AsyncJob {
    param(
        [hashtable]$JobParams,
        [System.Windows.Controls.TextBox]$OutputBox,
        [System.Windows.Controls.Button]$BtnStart,
        [System.Windows.Controls.Button]$BtnStop
    )

    Clear-CompletedGuiJob
    if (Test-GuiJobRunning) {
        [System.Windows.MessageBox]::Show("Un job est deja en cours. Arretez-le ou attendez sa fin avant d'en lancer un autre.", "TongBack", 'OK', 'Warning') | Out-Null
        return
    }

    $dispatcher  = $window.Dispatcher
    $modPath     = $modulePath
    $capturedStart = $BtnStart
    $capturedStop  = $BtnStop
    $capturedBox   = $OutputBox
    $capturedStatus = $tbStatus
    $capturedDot    = $statusDot
    $brushConverter = [System.Windows.Media.BrushConverter]::new()
    $jobState = [hashtable]::Synchronized(@{
        Id            = ''
        Tool          = if ($JobParams.ContainsKey('Tool')) { [string]$JobParams['Tool'] } else { '' }
        IsRunning     = $true
        StopRequested = $false
        FinalStatus   = ''
        Error         = ''
    })

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions   = 'ReuseThread'
    $rs.Open()

    $rs.SessionStateProxy.SetVariable('JobParams',   $JobParams)
    $rs.SessionStateProxy.SetVariable('Dispatcher',  $dispatcher)
    $rs.SessionStateProxy.SetVariable('OutputBox',   $capturedBox)
    $rs.SessionStateProxy.SetVariable('BtnStart',    $capturedStart)
    $rs.SessionStateProxy.SetVariable('BtnStop',     $capturedStop)
    $rs.SessionStateProxy.SetVariable('ModPath',     $modPath)
    $rs.SessionStateProxy.SetVariable('JobState',    $jobState)
    $rs.SessionStateProxy.SetVariable('StatusText',  $capturedStatus)
    $rs.SessionStateProxy.SetVariable('StatusDot',   $capturedDot)
    $rs.SessionStateProxy.SetVariable('BrushConv',   $brushConverter)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        Import-Module $ModPath -Force

        $append = {
            param([string]$line)
            $Dispatcher.Invoke([Action]{
                $OutputBox.Text += "$line`n"
                $OutputBox.ScrollToEnd()
            })
        }

        $JobParams['OnOutput'] = { param($l) & $append $l }
        $JobParams['OnError']  = { param($l) & $append "[ERR] $l" }
        $JobParams['OnJobCreated'] = {
            param($createdJob)
            $JobState['Id'] = [string]$createdJob.Id
            $JobState['Tool'] = [string]$createdJob.Tool
            & $append "[*] Job cree : $($createdJob.Id)"
        }

        try {
            $job = Start-TbJob @JobParams
            if ($null -ne $job) {
                $JobState['Id'] = [string]$job.Id
                $JobState['FinalStatus'] = [string]$job.Status
            }
        } catch {
            $JobState['Error'] = [string]$_
            & $append "[!] Erreur : $_"
        } finally {
            $JobState['IsRunning'] = $false
        }

        $Dispatcher.Invoke([Action]{
            $BtnStart.IsEnabled = $true
            $BtnStop.IsEnabled  = $false
            if ($JobState['StopRequested']) {
                $StatusText.Text = 'Arrete'
                $StatusDot.Fill = $BrushConv.ConvertFromString('#f85149')
            } elseif (-not [string]::IsNullOrWhiteSpace([string]$JobState['Error'])) {
                $StatusText.Text = 'Erreur'
                $StatusDot.Fill = $BrushConv.ConvertFromString('#f85149')
            } else {
                $StatusText.Text = 'Pret'
                $StatusDot.Fill = $BrushConv.ConvertFromString('#39d353')
            }
        })
    })

    $script:CurrentJobRunspace   = $rs
    $script:CurrentJobPowerShell = $ps
    $script:CurrentJobState      = $jobState
    $script:CurrentJobHandle     = $ps.BeginInvoke()

    $BtnStart.IsEnabled = $false
    $BtnStop.IsEnabled  = $true
    Set-Status -Text 'Job en cours...' -Color '#e3b341'
}

# ── Cablage de chaque vue ─────────────────────────────────────────────────────
function Wire-View {
    param([string]$ViewName, [System.Windows.FrameworkElement]$View)

    switch ($ViewName) {

        'Dashboard' {
            $dgJobs    = $View.FindName('dgRecentJobs')
            $dgResults = $View.FindName('dgRecentResults')
            $hcStatus  = $View.FindName('tbHashcatStatus')
            $jStatus   = $View.FindName('tbJohnStatus')
            $actJobs   = $View.FindName('tbActiveJobs')
            $resCount  = $View.FindName('tbResultCount')

            try { Resolve-TbToolPath -Tool 'hashcat' | Out-Null; $hcStatus.Text = 'OK' }
            catch { $hcStatus.Text = 'Manquant'; $hcStatus.Foreground = [System.Windows.Media.Brushes]::Salmon }

            try { Resolve-TbToolPath -Tool 'john' | Out-Null; $jStatus.Text = 'OK' }
            catch { $jStatus.Text = 'Manquant'; $jStatus.Foreground = [System.Windows.Media.Brushes]::Salmon }

            $jobs    = @(Get-TbJob)
            $results = @(Get-TbResult)
            $dgJobs.ItemsSource    = ($jobs    | Select-Object -Last 20)
            $dgResults.ItemsSource = ($results | Select-Object -Last 10)
            $actJobs.Text  = ($jobs | Where-Object { $_.Status -eq 'Running' }).Count.ToString()
            $resCount.Text = $results.Count.ToString()
        }

        'Tools' {
            $dgTools      = $View.FindName('dgTools')
            $btnSetActive = $View.FindName('btnSetActive')
            $btnRefresh   = $View.FindName('btnRefreshTools')

            $dgTools.ItemsSource = @(Get-TbTool)

            $btnRefresh.Add_Click({ $dgTools.ItemsSource = @(Get-TbTool) })

            $btnSetActive.Add_Click({
                $sel = $dgTools.SelectedItem
                if ($null -eq $sel) {
                    [System.Windows.MessageBox]::Show("Selectionnez un outil dans la liste.", "TongBack", 'OK', 'Information') | Out-Null
                    return
                }
                Set-TbActiveTool -Tool $sel.Name -ExePath $sel.ExePath
                $dgTools.ItemsSource = @(Get-TbTool)
            })
        }

        'Formats' {
            $tbSearch  = $View.FindName('tbFormatSearch')
            $btnSearch = $View.FindName('btnFormatSearch')
            $dgModes   = $View.FindName('dgHashcatModes')
            $lbJohn    = $View.FindName('lbJohnFormats')

            $tbSearch.GotFocus.Add({ if ($tbSearch.Text -match 'Rechercher') { $tbSearch.Text = '' } })

            $doSearch = {
                $q = $tbSearch.Text.Trim()
                if ([string]::IsNullOrWhiteSpace($q) -or $q -match 'Rechercher') { return }
                try {
                    $r = Find-HashFormat -Search $q
                    $dgModes.ItemsSource = $r.Hashcat
                    $lbJohn.ItemsSource  = $r.John
                } catch {
                    [System.Windows.MessageBox]::Show("Erreur : $_", "TongBack", 'OK', 'Error') | Out-Null
                }
            }
            $btnSearch.Add_Click($doSearch)
            $tbSearch.Add_KeyDown({
                param($s, $e)
                if ($e.Key -eq [System.Windows.Input.Key]::Return) { & $doSearch }
            })

            try {
                $cap = Get-TbCapability -Tool 'hashcat'
                $dgModes.ItemsSource = $cap.HashModes
            } catch {}
        }

        'JobsHashcat' {
            $cbMode    = $View.FindName('cbHcMode')
            $tbHM      = $View.FindName('tbHcHashMode')
            $btnFind   = $View.FindName('btnHcFindMode')
            $rbDirect  = $View.FindName('rbHcDirectHash')
            $rbFile    = $View.FindName('rbHcFromFile')
            $pnlHash   = $View.FindName('pnlHcHash')
            $pnlFile   = $View.FindName('pnlHcFile')
            $tbHash    = $View.FindName('tbHcHash')
            $tbFile    = $View.FindName('tbHcFile')
            $btnBrowse = $View.FindName('btnHcBrowseFile')
            $pnlWl     = $View.FindName('pnlHcWordlists')
            $tbWl1     = $View.FindName('tbHcWordlist1')
            $btnWl1    = $View.FindName('btnHcBrowseWl1')
            $pnlWl2    = $View.FindName('pnlHcWordlist2')
            $tbWl2     = $View.FindName('tbHcWordlist2')
            $btnWl2    = $View.FindName('btnHcBrowseWl2')
            $pnlMask   = $View.FindName('pnlHcMask')
            $tbMask    = $View.FindName('tbHcMask')
            $btnStart  = $View.FindName('btnHcStart')
            $btnStop   = $View.FindName('btnHcStop')
            $btnClear  = $View.FindName('btnHcClear')
            $tbOutput  = $View.FindName('tbHcOutput')

            $updatePanels = {
                $tag = ($cbMode.SelectedItem).Tag
                $pnlWl.Visibility   = if ($tag -in @('0','1','6','7')) { 'Visible' } else { 'Collapsed' }
                $pnlWl2.Visibility  = if ($tag -eq '1') { 'Visible' } else { 'Collapsed' }
                $pnlMask.Visibility = if ($tag -in @('3','6','7')) { 'Visible' } else { 'Collapsed' }
            }
            $cbMode.Add_SelectionChanged($updatePanels)
            & $updatePanels

            $rbDirect.Add_Checked({ $pnlHash.Visibility = 'Visible'; $pnlFile.Visibility = 'Collapsed' })
            $rbFile.Add_Checked({   $pnlFile.Visibility = 'Visible'; $pnlHash.Visibility = 'Collapsed' })

            $btnBrowse.Add_Click({
                $dlg = [Microsoft.Win32.OpenFileDialog]::new()
                $dlg.Filter = 'Tous les fichiers|*.*'
                if ($dlg.ShowDialog()) { $tbFile.Text = $dlg.FileName }
            })
            $btnWl1.Add_Click({
                $dlg = [Microsoft.Win32.OpenFileDialog]::new()
                $dlg.Filter = 'Wordlist|*.txt;*.lst|Tous|*.*'
                if ($dlg.ShowDialog()) { $tbWl1.Text = $dlg.FileName }
            })
            $btnWl2.Add_Click({
                $dlg = [Microsoft.Win32.OpenFileDialog]::new()
                $dlg.Filter = 'Wordlist|*.txt;*.lst|Tous|*.*'
                if ($dlg.ShowDialog()) { $tbWl2.Text = $dlg.FileName }
            })

            $btnClear.Add_Click({ $tbOutput.Text = '' })

            $btnFind.Add_Click({
                $query = $tbHM.Text.Trim()
                Navigate-To -ViewName 'Formats'
                if (-not [string]::IsNullOrWhiteSpace($query)) {
                    $formatView = $MainContent.Content
                    $formatSearch = $formatView.FindName('tbFormatSearch')
                    $formatModes  = $formatView.FindName('dgHashcatModes')
                    $formatJohn   = $formatView.FindName('lbJohnFormats')
                    $formatSearch.Text = $query
                    try {
                        $found = Find-HashFormat -Search $query
                        $formatModes.ItemsSource = $found.Hashcat
                        $formatJohn.ItemsSource  = $found.John
                    } catch {
                        [System.Windows.MessageBox]::Show("Recherche impossible : $_", "TongBack", 'OK', 'Error') | Out-Null
                    }
                }
            })

            $btnStart.Add_Click({
                $tbOutput.Text = ''
                $mode     = 0; try { $mode     = [int]($cbMode.SelectedItem).Tag } catch {}
                $hashMode = 0; try { $hashMode = [int]$tbHM.Text }               catch {}

                $params = @{ Tool = 'hashcat'; Mode = $mode; HashMode = $hashMode }

                if ($rbFile.IsChecked -and -not [string]::IsNullOrWhiteSpace($tbFile.Text)) {
                    $params['FilePath'] = $tbFile.Text
                } elseif (-not [string]::IsNullOrWhiteSpace($tbHash.Text)) {
                    $params['Hash'] = $tbHash.Text
                } else {
                    [System.Windows.MessageBox]::Show("Entrez un hash ou selectionnez un fichier.", "TongBack", 'OK', 'Warning') | Out-Null
                    return
                }

                $wl = [System.Collections.Generic.List[string]]::new()
                if (-not [string]::IsNullOrWhiteSpace($tbWl1.Text)) { $wl.Add($tbWl1.Text) }
                if (-not [string]::IsNullOrWhiteSpace($tbWl2.Text)) { $wl.Add($tbWl2.Text) }
                if ($wl.Count -gt 0) { $params['Wordlist'] = $wl.ToArray() }
                if (-not [string]::IsNullOrWhiteSpace($tbMask.Text)) { $params['Mask'] = $tbMask.Text }

                Start-AsyncJob -JobParams $params -OutputBox $tbOutput -BtnStart $btnStart -BtnStop $btnStop
            })

            $btnStop.Add_Click({
                Stop-GuiActiveJob -OutputBox $tbOutput -BtnStart $btnStart -BtnStop $btnStop
            })
        }

        'JobsJohn' {
            $rbDirect  = $View.FindName('rbJohnDirectHash')
            $rbFile    = $View.FindName('rbJohnFromFile')
            $pnlHash   = $View.FindName('pnlJohnHash')
            $pnlFile   = $View.FindName('pnlJohnFile')
            $tbHash    = $View.FindName('tbJohnHash')
            $tbFile    = $View.FindName('tbJohnFile')
            $btnBrowse = $View.FindName('btnJohnBrowseFile')
            $tbWl      = $View.FindName('tbJohnWordlist')
            $btnWl     = $View.FindName('btnJohnBrowseWl')
            $tbExtra   = $View.FindName('tbJohnExtraArgs')
            $btnStart  = $View.FindName('btnJohnStart')
            $btnStop   = $View.FindName('btnJohnStop')
            $tbOutput  = $View.FindName('tbJohnOutput')

            $rbDirect.Add_Checked({ $pnlHash.Visibility = 'Visible'; $pnlFile.Visibility = 'Collapsed' })
            $rbFile.Add_Checked({   $pnlFile.Visibility = 'Visible'; $pnlHash.Visibility = 'Collapsed' })

            $btnBrowse.Add_Click({
                $dlg = [Microsoft.Win32.OpenFileDialog]::new()
                $dlg.Filter = 'Tous les fichiers|*.*'
                if ($dlg.ShowDialog()) { $tbFile.Text = $dlg.FileName }
            })
            $btnWl.Add_Click({
                $dlg = [Microsoft.Win32.OpenFileDialog]::new()
                $dlg.Filter = 'Wordlist|*.txt;*.lst|Tous|*.*'
                if ($dlg.ShowDialog()) { $tbWl.Text = $dlg.FileName }
            })

            $btnStart.Add_Click({
                $tbOutput.Text = ''
                $params = @{ Tool = 'john'; Mode = 0; HashMode = 0 }

                if ($rbFile.IsChecked -and -not [string]::IsNullOrWhiteSpace($tbFile.Text)) {
                    $params['FilePath'] = $tbFile.Text
                } elseif (-not [string]::IsNullOrWhiteSpace($tbHash.Text)) {
                    $params['Hash'] = $tbHash.Text
                } else {
                    [System.Windows.MessageBox]::Show("Entrez un hash ou selectionnez un fichier.", "TongBack", 'OK', 'Warning') | Out-Null
                    return
                }
                if (-not [string]::IsNullOrWhiteSpace($tbWl.Text))  { $params['Wordlist']  = @($tbWl.Text) }
                if (-not [string]::IsNullOrWhiteSpace($tbExtra.Text)) {
                    $params['ExtraArgs'] = ($tbExtra.Text.Trim() -split '\s+')
                }

                Start-AsyncJob -JobParams $params -OutputBox $tbOutput -BtnStart $btnStart -BtnStop $btnStop
            })

            $btnStop.Add_Click({
                Stop-GuiActiveJob -OutputBox $tbOutput -BtnStart $btnStart -BtnStop $btnStop
            })
        }

        'Sessions' {
            $dgSessions = $View.FindName('dgSessions')
            $cbFilter   = $View.FindName('cbSessionFilter')
            $btnRefresh = $View.FindName('btnSessionRefresh')
            $btnResume  = $View.FindName('btnResumeJob')
            $btnStop    = $View.FindName('btnStopJob')

            $loadJobs = {
                $all    = @(Get-TbJob)
                $filter = if ($cbFilter.SelectedItem) { ($cbFilter.SelectedItem).Content } else { 'Tous' }
                if ($filter -and $filter -ne 'Tous') { $all = $all | Where-Object { $_.Status -eq $filter } }
                $dgSessions.ItemsSource = $all
            }
            $cbFilter.Add_SelectionChanged($loadJobs)
            $btnRefresh.Add_Click($loadJobs)
            & $loadJobs

            $btnStop.Add_Click({
                $sel = $dgSessions.SelectedItem
                if ($null -eq $sel) { return }
                Stop-TbJob -Id $sel.Id
                if ((Get-GuiCurrentJobId) -eq [string]$sel.Id -and $null -ne $script:CurrentJobState) {
                    $script:CurrentJobState['StopRequested'] = $true
                    Set-Status -Text 'Arret demande...' -Color '#e3b341'
                }
                & $loadJobs
            })

            $btnResume.Add_Click({
                $sel = $dgSessions.SelectedItem
                if ($null -eq $sel) { return }
                try { Resume-TbJob -Id $sel.Id; & $loadJobs }
                catch {
                    [System.Windows.MessageBox]::Show("Impossible de reprendre : $_", "TongBack", 'OK', 'Error') | Out-Null
                }
            })
        }

        'ModeExpert' {
            $cbTool    = $View.FindName('cbExpertTool')
            $tbMode    = $View.FindName('tbExpertMode')
            $tbHM      = $View.FindName('tbExpertHashMode')
            $tbHash    = $View.FindName('tbExpertHash')
            $tbArgs    = $View.FindName('tbExpertArgs')
            $tbPreview = $View.FindName('tbExpertPreview')
            $btnRun    = $View.FindName('btnExpertRun')
            $btnStop   = $View.FindName('btnExpertStop')
            $btnClear  = $View.FindName('btnExpertClear')
            $tbOutput  = $View.FindName('tbExpertOutput')

            $updatePreview = {
                $t = if ($cbTool.SelectedItem) { ($cbTool.SelectedItem).Content } else { 'hashcat' }
                $tbPreview.Text = "$t -a $($tbMode.Text.Trim()) -m $($tbHM.Text.Trim()) $($tbHash.Text.Trim()) $($tbArgs.Text.Trim())".Trim()
            }
            $cbTool.Add_SelectionChanged($updatePreview)
            $tbMode.Add_TextChanged($updatePreview)
            $tbHM.Add_TextChanged($updatePreview)
            $tbHash.Add_TextChanged($updatePreview)
            $tbArgs.Add_TextChanged($updatePreview)
            & $updatePreview

            $btnClear.Add_Click({ $tbOutput.Text = '' })

            $btnRun.Add_Click({
                $tbOutput.Text = ''
                $tool     = if ($cbTool.SelectedItem) { ($cbTool.SelectedItem).Content } else { 'hashcat' }
                $mode     = 0; try { $mode     = [int]$tbMode.Text } catch {}
                $hashMode = 0; try { $hashMode = [int]$tbHM.Text }  catch {}
                $params = @{ Tool = $tool; Mode = $mode; HashMode = $hashMode; Hash = $tbHash.Text.Trim() }
                $freeArgs = @()
                if (-not [string]::IsNullOrWhiteSpace($tbArgs.Text)) {
                    $freeArgs = @($tbArgs.Text.Trim() -split '\s+')
                }

                if ($tool -eq 'hashcat') {
                    switch ($mode) {
                        0 {
                            if ($freeArgs.Count -gt 0) {
                                $params['Wordlist'] = @($freeArgs[0])
                                if ($freeArgs.Count -gt 1) { $params['ExtraArgs'] = @($freeArgs | Select-Object -Skip 1) }
                            }
                        }
                        1 {
                            if ($freeArgs.Count -ge 2) {
                                $params['Wordlist'] = @($freeArgs[0], $freeArgs[1])
                                if ($freeArgs.Count -gt 2) { $params['ExtraArgs'] = @($freeArgs | Select-Object -Skip 2) }
                            }
                        }
                        3 {
                            if ($freeArgs.Count -gt 0) {
                                $params['Mask'] = $freeArgs[0]
                                if ($freeArgs.Count -gt 1) { $params['ExtraArgs'] = @($freeArgs | Select-Object -Skip 1) }
                            }
                        }
                        6 {
                            if ($freeArgs.Count -ge 2) {
                                $params['Wordlist'] = @($freeArgs[0])
                                $params['Mask'] = $freeArgs[1]
                                if ($freeArgs.Count -gt 2) { $params['ExtraArgs'] = @($freeArgs | Select-Object -Skip 2) }
                            }
                        }
                        7 {
                            if ($freeArgs.Count -ge 2) {
                                $params['Mask'] = $freeArgs[0]
                                $params['Wordlist'] = @($freeArgs[1])
                                if ($freeArgs.Count -gt 2) { $params['ExtraArgs'] = @($freeArgs | Select-Object -Skip 2) }
                            }
                        }
                    }
                } elseif ($freeArgs.Count -gt 0) {
                    $params['ExtraArgs'] = $freeArgs
                }
                Start-AsyncJob -JobParams $params -OutputBox $tbOutput -BtnStart $btnRun -BtnStop $btnStop
            })

            $btnStop.Add_Click({
                Stop-GuiActiveJob -OutputBox $tbOutput -BtnStart $btnRun -BtnStop $btnStop
            })
        }
    }
}

# ── Cablage des boutons de navigation ─────────────────────────────────────────
foreach ($k in $navButtons.Keys) {
    $viewName = $k
    $navButtons[$k].Add_Click({
        Navigate-To -ViewName $viewName
    }.GetNewClosure())
}

# ── Confirmation fermeture si job actif ───────────────────────────────────────
$window.Add_Closing({
    param($s, $e)
    if (Test-GuiJobRunning) {
        $res = [System.Windows.MessageBox]::Show(
            "Un job est en cours. L'arreter et fermer TongBack ?",
            "TongBack", 'YesNo', 'Warning')
        if ($res -eq 'No') {
            $e.Cancel = $true
        } else {
            Stop-GuiActiveJob -OutputBox $null -BtnStart $null -BtnStop $null -CloseRunspace
        }
    } else {
        Clear-CompletedGuiJob
    }
})

# ── Chargement initial ────────────────────────────────────────────────────────
Navigate-To -ViewName 'Dashboard'

# ── Affichage (bloquant jusqu a fermeture) ────────────────────────────────────
$window.ShowDialog() | Out-Null
