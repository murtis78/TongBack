@{
    ModuleVersion     = '3.0.0'
    GUID              = 'c4a7f1e2-3b89-4d56-a012-8f7e9c3d5a01'
    Author            = 'Othmane AZIRAR'
    CompanyName       = 'TongBack Project'
    Copyright         = '(c) 2024 Othmane AZIRAR. Tous droits reserves.'
    Description       = 'Wrapper PowerShell enterprise pour Hashcat et John the Ripper. Architecture en couches (Infrastructure/Core/Adapters/Public), 14 commandes Tb-prefixees, GUI WPF multi-vues, CLI complete, logs JSONL.'

    PowerShellVersion = '7.0'
    RootModule        = 'TongBack.psm1'

    FunctionsToExport = @(
        # 14 commandes publiques v3
        'Get-TbTool',
        'Set-TbActiveTool',
        'Install-TbTool',
        'Get-TbCapability',
        'Update-TbCapability',
        'Start-TbJob',
        'Stop-TbJob',
        'Resume-TbJob',
        'Get-TbJob',
        'Get-TbResult',
        'Export-TbResult',
        'Get-TbLog',
        'Get-TbEnvironment',
        'Get-TbHash',
        # Compatibilite v2
        'Show-TongBackLogo',
        'Find-HashFormat',
        'Get-HashFromFile',
        'Start-HashcatAttack'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList          = @(
        'TongBack.psm1',
        'TongBack.psd1',
        'Cli\TongBack.Cli.ps1',
        'Config\appsettings.json',
        'Config\appsettings.template.json',
        'Config\sources.json',
        'Config\profiles.json',
        'Data\HashFormats.json'
    )

    PrivateData       = @{
        PSData = @{
            Tags         = @('Hashcat', 'JohnTheRipper', 'PasswordCracking', 'Security', 'CTF', 'Pentest', 'WPF', 'GUI', 'Enterprise')
            ProjectUri   = 'https://github.com/murtis78/TongBack'
            ReleaseNotes = @'
v3.0.0
- Architecture enterprise en couches : Infrastructure / Models / Parsing / Validation / Adapters / Core / Public
- 14 commandes publiques avec prefixe Tb (Get-TbTool, Start-TbJob, Get-TbLog, etc.)
- ProcessLauncher : zero Invoke-Expression, arguments en tableau strict, async non-bloquant
- JobService : machine d etat complete Pending->Running->Completed/Failed/Cancelled/Paused
- CapabilityService : decouverte dynamique hashcat --help / john --list, cache JSONL 7 jours
- ToolManagerAdapter : decouverte automatique des outils dans Tools/, configuration locale ignoree par Git
- LoggingService : logs JSONL structures avec correlation JobId
- GUI WPF multi-vues : Dashboard, Outils, Formats, Jobs Hashcat, Jobs John, Sessions, Mode Expert
- CLI entrypoint : Cli/TongBack.Cli.ps1
- Compatibilite v2 : Show-TongBackLogo, Find-HashFormat, Get-HashFromFile, Start-HashcatAttack
- Cible PowerShell 7.0
'@
        }
    }
}
