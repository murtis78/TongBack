
Add-Type -AssemblyName PresentationCore, PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName WindowsFormsIntegration

[xml]$xaml = Get-Content -Path "$PSScriptRoot\TongBack.xaml"
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$modeComboBox = $window.FindName("modeComboBox")
$hashModeTextBox = $window.FindName("hashModeTextBox")
$hashTextBox = $window.FindName("hashTextBox")
$fileTextBox = $window.FindName("fileTextBox")
$wordlistTextBox = $window.FindName("wordlistTextBox")
$maskTextBox = $window.FindName("maskTextBox")
$powershellHost = $window.FindName("powershellHost")
$searchTextBox = $window.FindName("searchTextBox")
$SearchButton = $window.FindName("SearchButton")
$BrowseHashModeButton = $window.FindName("BrowseHashModeButton")
$BrowseHashButton = $window.FindName("BrowseHashButton")
$BrowseFileButton = $window.FindName("BrowseFileButton")
$BrowseWordlistButton = $window.FindName("BrowseWordlistButton")
$BrowseMaskButton = $window.FindName("BrowseMaskButton")
$StartAttackButton = $window.FindName("StartAttackButton")

$scriptControl = New-Object System.Windows.Forms.RichTextBox
$scriptControl.Dock = 'Fill'
$powershellHost.Child = $scriptControl

function Append-Text {
    param (
        [string]$text,
        [System.Drawing.Color]$color
    )
    $scriptControl.SelectionStart = $scriptControl.TextLength
    $scriptControl.SelectionLength = 0
    $scriptControl.SelectionColor = $color
    $scriptControl.AppendText($text)
    $scriptControl.SelectionColor = $scriptControl.ForeColor
}

function Execute-PowerShellCommand {
    param (
        [string]$command
    )
    Append-Text "PS> $command`n" ([System.Drawing.Color]::Black)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = "-NoLogo -NoProfile -Command $command"
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.Start() | Out-Null

    $output = $process.StandardOutput.ReadToEnd()
    $error = $process.StandardError.ReadToEnd()

    Append-Text "$output`n" ([System.Drawing.Color]::Black)
    if ($error) {
        Append-Text "$error`n" ([System.Drawing.Color]::Red)
    }

    $process.WaitForExit()
}

$BrowseFileButton.Add_Click({
    $fileDialog = New-Object Microsoft.Win32.OpenFileDialog
    if ($fileDialog.ShowDialog() -eq $true) {
        $fileTextBox.Text = $fileDialog.FileName
    }
})

$BrowseWordlistButton.Add_Click({
    $fileDialog = New-Object Microsoft.Win32.OpenFileDialog
    $fileDialog.Multiselect = $true
    if ($fileDialog.ShowDialog() -eq $true) {
        $wordlistTextBox.Text = [string]::Join(" ", $fileDialog.FileNames)
    }
})

$BrowseHashModeButton.Add_Click({
    $fileDialog = New-Object Microsoft.Win32.OpenFileDialog
    if ($fileDialog.ShowDialog() -eq $true) {
        $hashModeTextBox.Text = $fileDialog.FileName
    }
})

$BrowseHashButton.Add_Click({
    $fileDialog = New-Object Microsoft.Win32.OpenFileDialog
    if ($fileDialog.ShowDialog() -eq $true) {
        $hashTextBox.Text = $fileDialog.FileName
    }
})

$BrowseMaskButton.Add_Click({
    $fileDialog = New-Object Microsoft.Win32.OpenFileDialog
    if ($fileDialog.ShowDialog() -eq $true) {
        $maskTextBox.Text = $fileDialog.FileName
    }
})

$SearchButton.Add_Click({
    $searchTerm = $searchTextBox.Text
    if (![string]::IsNullOrWhiteSpace($searchTerm)) {
        $command = "$PSScriptRoot\TongBack.ps1 -search `"$searchTerm`""
        Execute-PowerShellCommand $command
    }
})

$StartAttackButton.Add_Click({
    $mode = $modeComboBox.SelectedIndex
    $hashMode = $hashModeTextBox.Text
    $hash = $hashTextBox.Text
    $file = $fileTextBox.Text
    $wordlist = $wordlistTextBox.Text.Split(" ")
    $mask = $maskTextBox.Text

    if ([string]::IsNullOrWhiteSpace($hash) -and [string]::IsNullOrWhiteSpace($file)) {
        [System.Windows.MessageBox]::Show("Veuillez spécifier un hash ou un fichier contenant des hashes.", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    $params = @{}
    if ($hash) {
        $params['hash'] = $hash
    } elseif ($file) {
        $params['file'] = $file
    }

    if ($hashMode) {
        $params['hashmode'] = $hashMode
    }

    if ($wordlist) {
        $params['wordlist'] = $wordlist
    }

    if ($mask) {
        $params['mask'] = $mask
    }

    $params['mode'] = $mode

    $command = "$PSScriptRoot\TongBack.ps1 " + ($params.GetEnumerator() | ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }) -join " "
    Execute-PowerShellCommand $command
})

$window.ShowDialog()
