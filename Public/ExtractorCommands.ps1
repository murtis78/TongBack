function Get-TbHash {
    <#
    .SYNOPSIS
        Extrait le hash d'un fichier protege par mot de passe via John the Ripper.
    .DESCRIPTION
        Determine l'outil *2john approprie selon l'extension du fichier
        et retourne la chaine de hash prete pour Hashcat.
        Formats supportes : .pdf, .zip, .rar, .docx, .kdbx, .pfx, .7z, etc.
    .EXAMPLE
        Get-TbHash -FilePath 'C:\docs\secret.pdf'
        Get-Item '.\archive.zip' | Get-TbHash
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath
    )

    process {
        return Invoke-Extractor -FilePath $FilePath
    }
}

function Get-HashFromFile {
    <#
    .SYNOPSIS
        Alias de compatibilite v2 pour Get-TbHash.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath
    )

    process {
        return Get-TbHash -FilePath $FilePath
    }
}
