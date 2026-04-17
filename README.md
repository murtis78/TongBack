# TongBack v3.0

TongBack est un wrapper PowerShell pour **Hashcat** et **John the Ripper**. Il fournit trois facons d'utiliser les outils :

- une **CLI** avec `Cli/TongBack.Cli.ps1` ;
- un **module PowerShell** avec des commandes publiques prefixees `Tb` ;
- une **interface graphique WPF** avec plusieurs vues : dashboard, outils, formats, jobs Hashcat, jobs John, sessions et mode expert.

Le projet sert a rechercher des formats de hash, extraire des hashes depuis des fichiers proteges, lancer des attaques autorisees, suivre les jobs, lire les resultats et consulter les logs.

> Utilisez TongBack uniquement sur des hashes, fichiers ou environnements pour lesquels vous avez une autorisation explicite.

---

## Sommaire

- [Prérequis](#prerequis)
- [Installation](#installation)
- [Structure du projet](#structure-du-projet)
- [Préparation GitHub](#preparation-github)
- [Utilisation rapide](#utilisation-rapide)
- [CLI](#cli)
- [Module PowerShell](#module-powershell)
- [Interface graphique](#interface-graphique)
- [Cas d'usage détaillés](#cas-dusage-detailles)
- [Modes Hashcat](#modes-hashcat)
- [Extraction de hash depuis fichiers](#extraction-de-hash-depuis-fichiers)
- [Jobs, sessions et résultats](#jobs-sessions-et-resultats)
- [Logs](#logs)
- [Configuration](#configuration)
- [Architecture interne](#architecture-interne)
- [Compatibilité v2](#compatibilite-v2)
- [Tests](#tests)
- [Dépannage](#depannage)

---

## Prerequis

| Element | Obligatoire | Role |
|---|---:|---|
| PowerShell 7.0+ | Oui | Runtime du module, de la CLI et de la GUI |
| Windows + WPF | Pour la GUI | Execution de `TongBack-GUI.ps1` |
| Hashcat | Pour les jobs Hashcat | Craquage par dictionnaire, masque, combinaison et hybride |
| John the Ripper jumbo | Pour l'extraction et les jobs John | Outils `*2john` et moteur John |
| Python 3.x dans le `PATH` | Selon formats | Scripts `*2john.py` : Office, LUKS, TrueCrypt, KeePass, etc. |
| Perl dans le `PATH` | Selon formats | Scripts `*2john.pl` : PDF, 7z, VDI, LDIF |
| 7-Zip (`7z.exe`) ou WinRAR | Pour `Install-TbTool` avec `.7z` ou `.rar` | Extraction automatique des archives telechargees |
| Pester 3.4+ ou 5.x | Pour les tests | Execution de `Tests/Invoke-TongBackTests.ps1` |

Le module cible PowerShell 7.0 via [TongBack.psm1](TongBack.psm1) et [TongBack.psd1](TongBack.psd1).

---

## Installation

### 1. Ouvrir un terminal dans le dossier du projet

```powershell
git clone https://github.com/murtis78/TongBack.git
cd TongBack
```

### 2. Charger le module

```powershell
Import-Module .\TongBack.psm1 -Force
```

### 3. Installer ou declarer les outils

TongBack cherche les executables dans cet ordre :

1. chemins actifs dans `Config/appsettings.local.json` si ce fichier existe ;
2. scan du dossier `Tools/` ;
3. erreur explicite si l'outil est introuvable.

Structure attendue :

```text
TongBack/
└── Tools/
    ├── hashcat-<version>/
    │   └── hashcat.exe
    └── john-<version>/
        └── run/
            ├── john.exe
            ├── *2john.exe
            ├── *2john.py
            ├── *2john.pl
            └── lib/
```

Installation automatique depuis `Config/sources.json` :

```powershell
Import-Module .\TongBack.psm1 -Force

# Installe la derniere version declaree dans Config/sources.json
Install-TbTool -Tool hashcat
Install-TbTool -Tool john

# Ou une version precise si elle existe dans Config/sources.json
Install-TbTool -Tool hashcat -Version '7.1.2'
```

Sources declarees :

| Outil | Version | Source | Verification |
|---|---|---|---|
| Hashcat | `7.1.2` | `https://github.com/hashcat/hashcat/releases/download/v7.1.2/hashcat-7.1.2.7z` | SHA256 `80db0316387794ce9d14ed376da75b8a7742972485b45db790f5f8260307ff98` |
| John the Ripper | `1.9.1-ce-winX64` | `https://github.com/openwall/john-packages/releases/download/v1.9.1-ce/winX64_1_JtR.7z` | Non fournie |

Declaration manuelle d'un executable deja installe :

```powershell
Set-TbActiveTool -Tool hashcat -ExePath 'C:\Tools\hashcat-7.1.2\hashcat.exe'
Set-TbActiveTool -Tool john    -ExePath 'C:\Tools\John_the_Ripper_v1.9.1\run\john.exe'
```

### 4. Installer une wordlist

Les wordlists ne sont pas fournies avec TongBack et ne doivent pas etre commitees dans le depot. Pour des listes de reference, consultez le projet SecLists :

```text
https://github.com/danielmiessler/SecLists
```

Exemple d'emplacement local ignore par Git :

```text
TongBack/
└── wordlists/
    └── rockyou.txt
```

### 5. Verifier l'environnement

```powershell
Get-TbEnvironment
```

ou via la CLI :

```powershell
.\Cli\TongBack.Cli.ps1 -Environment
```

---

## Structure du projet

```text
TongBack/
├── TongBack.psm1                  # Chargeur du module
├── TongBack.psd1                  # Manifest PowerShell
├── TongBack.ps1                   # Ancien point d'entree compatible v2
├── TongBack-GUI.ps1               # Point d'entree GUI WPF
├── Cli/
│   └── TongBack.Cli.ps1           # Point d'entree CLI v3
├── Config/
│   ├── appsettings.json           # Configuration par defaut sans chemin local
│   ├── appsettings.template.json  # Modele de configuration publiable
│   ├── appsettings.local.json     # Configuration locale ignoree par Git
│   ├── sources.json               # Sources de telechargement des outils
│   └── profiles.json              # Profils internes
├── Data/
│   ├── HashFormats.json           # Base statique Hashcat + John
│   └── capabilities/              # Cache genere par Get/Update-TbCapability
├── Gui/
│   ├── MainWindow.xaml
│   └── Views/
│       ├── DashboardView.xaml
│       ├── ToolsView.xaml
│       ├── FormatsView.xaml
│       ├── JobsHashcatView.xaml
│       ├── JobsJohnView.xaml
│       ├── SessionsView.xaml
│       └── ModeExpertView.xaml
├── Public/                        # Commandes exportees
├── Private/                       # Services, adaptateurs, modeles, parsing
├── Tests/
│   ├── TongBack.Tests.ps1         # Suite Pester P0/P1/P2
│   └── Invoke-TongBackTests.ps1   # Runner compatible Pester 3 et 5
├── Logs/                          # Logs JSONL runtime
├── Sessions/                      # Jobs persistés runtime
├── Results/                       # Resultats runtime
├── Temp/                          # Fichiers temporaires runtime
├── Requirements/                  # Archives locales ignorees par Git
└── Tools/                         # Hashcat et John, non fourni par defaut
```

Les dossiers `Logs/`, `Sessions/`, `Results/`, `Temp/`, `Requirements/`, `Tools/` et `Data/capabilities/` sont conserves dans le depot avec un `.gitkeep`, mais leur contenu runtime est ignore par `.gitignore`.

---

## Preparation GitHub

Le depot est prepare pour ne pas publier les donnees locales :

- `Config/appsettings.json` et `Config/appsettings.template.json` ne contiennent aucun chemin absolu lie a une machine ;
- `Config/appsettings.local.json` est ignore par Git et recoit les chemins propres au poste local ;
- `Config/sources.json` pointe vers Hashcat `7.1.2` et John the Ripper `1.9.1-ce-winX64` ;
- `Install-TbTool` verifie le SHA256 lorsque la source en fournit un ;
- les dossiers `Logs/`, `Sessions/`, `Results/`, `Temp/`, `Data/capabilities/`, `Requirements/` et `Tools/` gardent seulement leur `.gitkeep` ;
- `.gitignore` exclut les archives, outils extraits, potfiles, logs, sessions, resultats, wordlists, corpus de documents et fichiers bureautiques ;
- `.gitattributes` normalise les fins de ligne et marque les binaires courants.

Avant un commit public, verifiez l'absence de chemins personnels :

```powershell
rg -n "<nom-utilisateur>|<chemin-absolu-local>" .
```

Si ces fichiers etaient deja suivis dans un depot Git existant, `.gitignore` ne suffit pas a les retirer de l'index. Retirez-les une fois de l'index avec des commandes adaptees, par exemple :

```powershell
git rm -r --cached Tools Requirements Logs Sessions Results Temp Data/capabilities
git rm --cached hashcat.potfile
```

---

## Utilisation rapide

```powershell
# Charger le module
Import-Module .\TongBack.psm1 -Force

# Verifier Hashcat, John, Python, Perl et les dossiers runtime
Get-TbEnvironment

# Rechercher le mode Hashcat d'un format
Find-HashFormat -Search 'pdf'

# Extraire un hash depuis un PDF avec pdf2john.pl
Get-TbHash -FilePath .\document.pdf

# Lancer un job Hashcat par dictionnaire
Start-TbJob -Tool hashcat -Mode 0 -HashMode 10400 -FilePath .\document.pdf -Wordlist .\wordlists\rockyou.txt

# Consulter les jobs et resultats
Get-TbJob
Get-TbResult
```

---

## CLI

La CLI recommandee est :

```powershell
.\Cli\TongBack.Cli.ps1 [options]
```

Options principales :

| Option | Description |
|---|---|
| `-Help` | Affiche l'aide detaillee |
| `-GUI` | Lance l'interface graphique |
| `-Environment` | Affiche l'etat de l'environnement |
| `-Search <texte>` | Recherche un format Hashcat ou John |
| `-Mode <0|1|3|6|7>` | Mode d'attaque Hashcat |
| `-HashMode <id>` | Identifiant Hashcat `-m` |
| `-Hash <hash>` | Hash donne directement |
| `-File <chemin>` | Fichier protege a convertir en hash |
| `-Wordlist <chemin...>` | Une ou deux wordlists selon le mode |
| `-Mask <masque>` | Masque Hashcat |
| `-ExtraArgs <args...>` | Arguments avances passes a Hashcat |

Exemples :

```powershell
# Aide CLI
.\Cli\TongBack.Cli.ps1 -Help

# GUI
.\Cli\TongBack.Cli.ps1 -GUI

# Etat de l'environnement
.\Cli\TongBack.Cli.ps1 -Environment

# Recherche de format
.\Cli\TongBack.Cli.ps1 -Search 'ntlm'

# Hash direct + dictionnaire
.\Cli\TongBack.Cli.ps1 -Mode 0 -HashMode 1000 -Hash 'aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c' -Wordlist .\wordlists\rockyou.txt

# Fichier protege + dictionnaire
.\Cli\TongBack.Cli.ps1 -Mode 0 -HashMode 10400 -File .\document.pdf -Wordlist .\wordlists\rockyou.txt

# Masque
.\Cli\TongBack.Cli.ps1 -Mode 3 -HashMode 1000 -Hash '8846f7eaee8fb117ad06bdd830b7586c' -Mask '?l?l?l?l?d?d'
```

La CLI lance un job via `Start-TbJob` et affiche les resultats trouves avec `Get-TbResult` lorsque le job se termine avec succes.

---

## Module PowerShell

Charger le module :

```powershell
Import-Module .\TongBack.psm1 -Force
```

Commandes exportees :

| Commande | Role |
|---|---|
| `Get-TbTool` | Liste les installations Hashcat et John detectees |
| `Set-TbActiveTool` | Definit l'executable actif dans `Config/appsettings.local.json` |
| `Install-TbTool` | Telecharge et extrait un outil depuis `Config/sources.json` |
| `Get-TbCapability` | Retourne les modes Hashcat ou formats John, via cache ou detection |
| `Update-TbCapability` | Force la regeneration du cache de capacites |
| `Find-HashFormat` | Recherche dans `Data/HashFormats.json` |
| `Get-TbHash` | Extrait un hash depuis un fichier protege via `*2john` |
| `Start-TbJob` | Cree, persiste et lance un job Hashcat ou John |
| `Stop-TbJob` | Annule un job et arrete le processus externe si son `ProcessId` est connu |
| `Resume-TbJob` | Reprend un job Hashcat via le fichier `.restore` place dans `Sessions/` |
| `Get-TbJob` | Liste ou filtre les jobs persistés dans `Sessions/` |
| `Get-TbResult` | Lit les resultats persistés dans `Results/` |
| `Export-TbResult` | Exporte les resultats en CSV ou JSON |
| `Get-TbLog` | Lit les logs JSONL |
| `Get-TbEnvironment` | Verifie outils, versions et dossiers runtime |
| `Show-TongBackLogo` | Affiche le logo ASCII, compatibilite v2 |
| `Get-HashFromFile` | Alias de compatibilite pour `Get-TbHash` |
| `Start-HashcatAttack` | Alias de compatibilite pour `Start-TbJob -Tool hashcat` |

---

## Interface graphique

Lancer la GUI :

```powershell
.\TongBack-GUI.ps1
```

ou :

```powershell
.\Cli\TongBack.Cli.ps1 -GUI
```

Vues disponibles :

| Vue | Utilisation |
|---|---|
| Dashboard | Voir l'etat Hashcat/John, le nombre de jobs actifs, les derniers jobs et resultats |
| Outils | Lister les outils detectes dans `Tools/`, rafraichir la liste, definir l'outil actif |
| Formats de hash | Rechercher dans les modes Hashcat et formats John |
| Jobs Hashcat | Lancer un job Hashcat depuis un hash direct ou un fichier protege |
| Jobs John | Lancer un job John depuis un hash direct ou un fichier protege |
| Sessions | Filtrer les jobs par statut, reprendre ou arreter un job |
| Mode Expert | Construire une commande avancee avec outil, mode, hash mode, hash et arguments |

La GUI lance les jobs dans un runspace separe pour eviter de bloquer l'interface. Les sorties sont redirigees vers la zone de sortie de la vue.

Lorsqu'un job est cree, la GUI conserve son `JobId`. Les boutons `Arreter` des vues Hashcat, John, Sessions et Mode Expert appellent `Stop-TbJob`, ce qui annule la session et tente d'arreter le processus externe associe. La fermeture de la fenetre propose aussi d'arreter le job actif avant de quitter.

Dans la vue Jobs Hashcat, le bouton `?` du champ `Mode hash (-m)` ouvre la vue Formats et lance une recherche sur la valeur saisie.

Dans le Mode Expert Hashcat, les premiers arguments libres sont affectes aux champs requis selon le mode : wordlist pour le mode `0`, deux wordlists pour le mode `1`, masque pour le mode `3`, wordlist + masque pour le mode `6`, masque + wordlist pour le mode `7`. Les arguments restants sont transmis comme `ExtraArgs`.

---

## Cas d'usage detailles

### 1. Verifier que TongBack voit les outils

Utilisez ce cas apres installation ou apres modification de `Tools/`.

```powershell
Import-Module .\TongBack.psm1 -Force
Get-TbEnvironment
Get-TbTool
```

`Get-TbEnvironment` affiche l'etat de Hashcat, John, Python, Perl et des dossiers runtime. `Get-TbTool` retourne des objets `TongBack.Tool` avec `Name`, `Version`, `ExePath`, `RunPath`, `IsActive` et `IsAvailable`.

### 2. Choisir explicitement une version de Hashcat ou John

Utilisez ce cas si plusieurs versions sont presentes dans `Tools/`.

```powershell
Get-TbTool -Tool hashcat
Set-TbActiveTool -Tool hashcat -ExePath 'C:\Tools\hashcat-7.1.2\hashcat.exe'
```

Pour John, donnez le chemin vers `john.exe` :

```powershell
Set-TbActiveTool -Tool john -ExePath 'C:\Tools\John_the_Ripper_v1.9.1\run\john.exe'
```

### 3. Rechercher le bon mode de hash

Utilisez ce cas avant une attaque lorsque vous ne connaissez pas le `HashMode`.

```powershell
Find-HashFormat -Search 'pdf'
Find-HashFormat -Search 'ntlm'
'office','zip','keepass' | Find-HashFormat
```

La sortie contient deux collections :

- `Hashcat` : objets avec `Mode` et `Name` ;
- `John` : noms de formats John correspondants.

La recherche utilise `-match`, donc `Search` est interprete comme une expression reguliere PowerShell.

### 4. Mettre a jour les capacites depuis les outils installes

Utilisez ce cas pour lire les capacites reelles de la version de Hashcat ou John active.

```powershell
Update-TbCapability -Tool hashcat
Update-TbCapability -Tool john

Get-TbCapability -Tool hashcat
Get-TbCapability -Tool john
```

TongBack essaye d'abord d'interroger l'outil :

- Hashcat : `hashcat.exe --help` ;
- John : `john.exe --list=formats`.

Si l'outil n'est pas disponible, TongBack retombe sur `Data/HashFormats.json`. Le cache est ecrit dans `Data/capabilities/` et expire selon la configuration chargee depuis `Config/appsettings.json`, avec surcharge locale optionnelle depuis `Config/appsettings.local.json`.

### 5. Extraire un hash depuis un fichier protege

Utilisez ce cas pour transformer un fichier en chaine de hash exploitable par Hashcat ou John.

```powershell
Get-TbHash -FilePath .\archive.zip
Get-TbHash -FilePath .\document.pdf
Get-Item .\coffre.kdbx | Get-TbHash
```

TongBack choisit l'outil `*2john` selon l'extension :

- `.zip` utilise `zip2john.exe` ;
- `.rar` utilise `rar2john.exe` ;
- `.pdf` utilise `pdf2john.pl` ;
- `.docx`, `.xlsx`, `.pptx`, `.doc`, `.xls` utilisent `office2john.py` ;
- `.7z` utilise `7z2john.pl`.

Si l'extension n'est pas connue ou si John/Python/Perl manque, une erreur explicite est levee.

### 6. Lancer une attaque Hashcat par dictionnaire

Utilisez ce cas lorsqu'une wordlist est disponible.

```powershell
# Hash direct
$job = Start-TbJob -Tool hashcat -Mode 0 -HashMode 1000 `
    -Hash '8846f7eaee8fb117ad06bdd830b7586c' `
    -Wordlist .\wordlists\rockyou.txt

# Fichier protege avec extraction automatique
$job = Start-TbJob -Tool hashcat -Mode 0 -HashMode 10400 `
    -FilePath .\document.pdf `
    -Wordlist .\wordlists\rockyou.txt
```

Mode `0` construit une commande Hashcat equivalent a :

```text
hashcat.exe -m <HashMode> -a 0 --session <JobId> --restore-file-path Sessions/<JobId>.restore <hash> <wordlist>
```

### 7. Lancer une attaque Hashcat par combinaison

Utilisez ce cas pour combiner deux wordlists.

```powershell
$job = Start-TbJob -Tool hashcat -Mode 1 -HashMode 0 `
    -Hash '5f4dcc3b5aa765d61d8327deb882cf99' `
    -Wordlist .\prenoms.txt, .\suffixes.txt
```

Mode `1` exige deux wordlists. TongBack valide leur existence avant de lancer le job.

### 8. Lancer une attaque Hashcat par masque

Utilisez ce cas pour tester une structure connue : longueur, chiffres, majuscules, etc.

```powershell
$job = Start-TbJob -Tool hashcat -Mode 3 -HashMode 1000 `
    -Hash '8846f7eaee8fb117ad06bdd830b7586c' `
    -Mask '?u?l?l?l?d?d?d?d'
```

Mode `3` construit :

```text
hashcat.exe -m <HashMode> -a 3 --session <JobId> --restore-file-path Sessions/<JobId>.restore <hash> <mask>
```

### 9. Lancer une attaque hybride Hashcat

Utilisez ce cas lorsqu'une partie du mot de passe vient d'une wordlist et l'autre suit un masque.

```powershell
# Mode 6 : wordlist + masque
Start-TbJob -Tool hashcat -Mode 6 -HashMode 0 `
    -Hash '5f4dcc3b5aa765d61d8327deb882cf99' `
    -Wordlist .\base.txt `
    -Mask '?d?d?d?d'

# Mode 7 : masque + wordlist
Start-TbJob -Tool hashcat -Mode 7 -HashMode 0 `
    -Hash '5f4dcc3b5aa765d61d8327deb882cf99' `
    -Mask '?d?d?d?d' `
    -Wordlist .\base.txt
```

### 10. Ajouter des arguments Hashcat avances

Utilisez ce cas pour passer des options non exposees par TongBack.

```powershell
Start-TbJob -Tool hashcat -Mode 0 -HashMode 1000 `
    -Hash '8846f7eaee8fb117ad06bdd830b7586c' `
    -Wordlist .\wordlists\rockyou.txt `
    -ExtraArgs '--username', '--status', '--status-timer', '30'
```

`ExtraArgs` est ajoute a la fin du tableau d'arguments. Le lancement interne utilise `ProcessStartInfo.ArgumentList`, pas `Invoke-Expression`.

### 11. Lancer un job John

Utilisez ce cas pour faire travailler John directement.

```powershell
Start-TbJob -Tool john -FilePath .\archive.zip -Wordlist .\wordlists\rockyou.txt
```

Si `FilePath` est fourni, TongBack extrait d'abord le hash via `Get-TbHash`, ecrit ensuite le hash dans `Temp/<JobId>.hash`, puis lance John avec :

```text
john.exe --wordlist=<wordlist> Temp/<JobId>.hash
```

Les arguments supplementaires sont acceptes :

```powershell
Start-TbJob -Tool john -FilePath .\archive.zip `
    -Wordlist .\wordlists\rockyou.txt `
    -ExtraArgs '--format=zip'
```

### 12. Gerer le cas Word XOR obfuscation

`office2john.py` peut signaler une protection Word ancienne de type XOR obfuscation. TongBack convertit cette sortie en format interne :

```text
$xor-obf$<verifier>
```

Si un job recoit un hash commencant par `$xor-obf$`, TongBack n'appelle pas Hashcat ou John : il utilise un craqueur dictionnaire PowerShell natif base sur le verifier XOR.

```powershell
Start-TbJob -Tool john -FilePath .\ancien-document.doc -Wordlist .\wordlists\rockyou.txt
```

Note : le verifier XOR est court, donc des collisions sont possibles. Un mot de passe trouve peut verifier le document sans etre necessairement le mot de passe original exact.

### 13. Suivre les jobs

```powershell
Get-TbJob
Get-TbJob -Tool hashcat
Get-TbJob -Status Running
Get-TbJob -Id '<job-guid>'
```

Statuts possibles :

| Statut | Signification |
|---|---|
| `Pending` | Job cree mais pas encore lance |
| `Running` | Job en cours |
| `Paused` | Etat prevu pour reprise |
| `Completed` | Process termine avec code `0` ou `1` |
| `Failed` | Erreur ou code de sortie inattendu |
| `Cancelled` | Job annule, avec tentative d'arret du processus externe |

### 14. Arreter ou reprendre un job

```powershell
Stop-TbJob -Id '<job-guid>'
Resume-TbJob -Id '<job-guid>'
```

`Stop-TbJob` met le job en `Cancelled`. Si le job contient un `ProcessId`, TongBack tente aussi d'arreter le processus Hashcat ou John associe.

`Resume-TbJob` est reserve aux jobs Hashcat et attend le fichier de restauration declare au lancement :

```text
Sessions/<JobId>.restore
```

TongBack passe ce chemin a Hashcat avec `--restore-file-path`, ce qui evite de dependre du repertoire courant de `hashcat.exe`. Si ce fichier n'existe pas, la reprise echoue avec une erreur descriptive.

### 15. Lire et exporter les resultats

```powershell
Get-TbResult
Get-TbResult -JobId '<job-guid>'

Export-TbResult -Path .\results.csv -Format CSV
Export-TbResult -Path .\results.json -Format JSON
Export-TbResult -JobId '<job-guid>' -Path .\one-job.csv -Format CSV
```

Un resultat contient :

| Champ | Description |
|---|---|
| `JobId` | Identifiant du job |
| `Hash` | Hash associe |
| `Password` | Mot de passe trouve |
| `HashMode` | Mode Hashcat ou type interne |
| `FoundAt` | Date ISO 8601 |

---

## Modes Hashcat

| Mode | Nom Hashcat | Parametres TongBack requis | Ordre construit |
|---:|---|---|---|
| `0` | Dictionnaire | `-Wordlist` | `<hash> <wordlist...>` |
| `1` | Combinaison | Deux wordlists | `<hash> <wordlist1> <wordlist2>` |
| `3` | Masque | `-Mask` | `<hash> <mask>` |
| `6` | Wordlist + masque | `-Wordlist` + `-Mask` | `<hash> <wordlist1> <mask>` |
| `7` | Masque + wordlist | `-Mask` + `-Wordlist` | `<hash> <mask> <wordlist1>` |

Caracteres masque usuels :

| Symbole | Jeu |
|---|---|
| `?l` | lettres minuscules |
| `?u` | lettres majuscules |
| `?d` | chiffres |
| `?s` | caracteres speciaux |
| `?a` | `?l?u?d?s` |
| `?b` | octets `0x00` a `0xff` |

---

## Extraction de hash depuis fichiers

TongBack s'appuie sur John jumbo et ses outils `*2john`.

| Type d'outil | Outils | Extensions |
|---|---|---|
| Executables | `bitlocker2john.exe`, `dmg2john.exe`, `gpg2john.exe`, `hccap2john.exe`, `keepass2john.exe`, `wpapcap2john.exe`, `putty2john.exe`, `rar2john.exe`, `zip2john.exe` | `.bek`, `.dmg`, `.gpg`, `.hccap`, `.kdbx`, `.pcap`, `.ppk`, `.rar`, `.zip` |
| Python | `1password2john.py`, `axcrypt2john.py`, `bitwarden2john.py`, `electrum2john.py`, `encfs2john.py`, `ethereum2john.py`, `keychain2john.py`, `keepass2john.py`, `luks2john.py`, `openssl2john.py`, `pfx2john.py`, `ssh2john.py`, `pwsafe2john.py`, `mozilla2john.py`, `truecrypt2john.py`, `office2john.py` | `.1pif`, `.axx`, `.bwdb`, `.dat`, `.encfs6`, `.json`, `.keychain`, `.kdbx`, `.luks`, `.pem`, `.pfx`, `.pub`, `.pws`, `.sqlite`, `.tc`, formats Office |
| Perl | `7z2john.pl`, `ldif2john.pl`, `pdf2john.pl`, `vdi2john.pl` | `.7z`, `.ldif`, `.pdf`, `.vdi` |

Formats Office couverts par `office2john.py` :

```text
.accdb .doc .docm .docx .dot .dotm .dotx .mdb
.pot .potm .potx .pps .ppsm .ppsx .ppt .pptm .pptx
.vsd .vsdm .vsdx .xls .xlsm .xlsx .xlt .xltm .xltx
```

---

## Jobs, sessions et resultats

### Jobs

Chaque job est sauvegarde dans :

```text
Sessions/<JobId>.json
```

Le modele `TongBack.Job` contient notamment :

- `Id`
- `Tool`
- `Mode`
- `HashMode`
- `Hash`
- `FilePath`
- `Wordlist`
- `Mask`
- `ExtraArgs`
- `Status`
- `StartTime`
- `EndTime`
- `SessionFile`
- `ResultFile`
- `HashFile`
- `ProcessId`
- `ExitCode`
- `Output`

### Resultats

Les resultats sont sauvegardes dans :

```text
Results/<JobId>.json
```

Le fichier contient un tableau de resultats. Plusieurs mots de passe pour un meme job sont ajoutes sans ecraser les resultats deja presents, et les doublons `Hash` + `Password` sont ignores.

Pour Hashcat, TongBack lance automatiquement une recuperation via :

```text
hashcat.exe -m <HashMode> <hash> --show
```

Le parseur gere les hashes contenant des `:` en utilisant le hash attendu du job quand il est disponible, puis un fallback sur le dernier separateur.

Pour John, TongBack lance automatiquement :

```text
john --show Temp/<JobId>.hash
```

Les lignes de resultats sont parsees sous les formes usuelles :

```text
hash:password
password (hash)
```

### Fichiers temporaires

Les jobs John creent un fichier temporaire :

```text
Temp/<JobId>.hash
```

---

## Logs

Les logs sont ecrits au format JSONL :

```text
Logs/tongback-YYYY-MM-DD.jsonl
```

Lire les logs :

```powershell
Get-TbLog
Get-TbLog -Last 50
Get-TbLog -Level Error
Get-TbLog -JobId '<job-guid>'
Get-TbLog -Source 'JobService'
```

Structure d'une entree :

```json
{
  "timestamp": "2026-04-17T10:18:51.0000000+02:00",
  "level": "Info",
  "jobId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "source": "JobService",
  "message": "Job demarre",
  "data": {
    "tool": "hashcat",
    "mode": 0,
    "hashMode": 10400
  }
}
```

---

## Configuration

### `Config/appsettings.json`

Contient :

- version de configuration ;
- valeurs par defaut sans chemin local ;
- retention des logs ;
- duree de vie du cache de capacites ;
- preferences UI.

Extrait :

```json
{
  "Tools": {
    "hashcat": {
      "ActivePath": "",
      "WorkingDirectory": ""
    },
    "john": {
      "ActiveRunPath": "",
      "PerlLibPath": ""
    }
  }
}
```

Ces valeurs restent vides dans le depot public. Les chemins propres a la machine sont ecrits dans `Config/appsettings.local.json`, qui est ignore par Git.

### `Config/appsettings.local.json`

Ce fichier est cree automatiquement par `Set-TbActiveTool` ou `Install-TbTool`. Il surcharge `Config/appsettings.json` et peut contenir :

- chemin actif Hashcat ;
- dossier actif John `run/` ;
- chemin `lib/` Perl pour John.

Il ne doit pas etre committe. Si le fichier est absent, TongBack scanne simplement `Tools/` sans modifier la configuration publique.

### `Config/appsettings.template.json`

Modele publiable de configuration. Il sert de reference propre pour recreer une configuration par defaut sans chemin local.

### `Config/sources.json`

Declare les versions telechargeables par `Install-TbTool`. Dans l'etat actuel, les sources incluent Hashcat `7.1.2` avec verification SHA256 et John `1.9.1-ce-winX64`.

### `Data/HashFormats.json`

Base statique utilisee par `Find-HashFormat` et comme fallback de `Get-TbCapability`.

---

## Architecture interne

```text
Entrypoints
├── Cli/TongBack.Cli.ps1
├── TongBack-GUI.ps1
└── TongBack.ps1
        │
        ▼
TongBack.psm1
        │
        ├── Public/                 # API exportee
        └── Private/
            ├── Models/             # Job, Result, Tool, Capability, Profile, Session
            ├── Infrastructure/     # Process, logs, persistence, download, archives
            ├── Validation/         # Validation arguments, chemins, profils
            ├── Parsing/            # Sorties Hashcat, John, extracteurs
            ├── Adapters/           # Hashcat, John, extracteurs, outils
            └── Core/               # JobService, CapabilityService, ProfileService
```

Points importants :

- `TongBack.psm1` charge les fichiers dans un ordre fixe : modeles, infrastructure, validation, parsing, adaptateurs, core, public.
- Les processus externes passent par `Invoke-TbProcess`.
- Les arguments sont transmis via `ProcessStartInfo.ArgumentList`.
- Les jobs sont persistés dans `Sessions/`.
- La GUI recupere le `JobId` via le callback `OnJobCreated` de `Start-TbJob`.
- Les resultats sont persistés dans `Results/`.
- Les logs sont ecrits en JSONL dans `Logs/`.
- Le cache des capacites est dans `Data/capabilities/`.

---

## Compatibilite v2

Le projet conserve des commandes et un point d'entree compatibles avec l'ancienne version :

```powershell
.\TongBack.ps1 -Search 'pdf'
.\TongBack.ps1 -Mode 0 -HashMode 10400 -File .\document.pdf -Wordlist .\wordlists\rockyou.txt
.\TongBack.ps1 -GUI
```

Commandes compatibles :

| Ancien usage | Equivalent v3 |
|---|---|
| `Find-HashFormat` | Recherche dans `Data/HashFormats.json` |
| `Get-HashFromFile` | `Get-TbHash` |
| `Start-HashcatAttack` | `Start-TbJob -Tool hashcat` |
| `Show-TongBackLogo` | Logo CLI |

Le point d'entree recommande pour les nouveaux usages reste :

```powershell
.\Cli\TongBack.Cli.ps1
```

---

## Tests

TongBack fournit une suite Pester dans `Tests/TongBack.Tests.ps1`.

Lancer tous les tests :

```powershell
.\Tests\Invoke-TongBackTests.ps1
```

Lancer les tests et nettoyer les artefacts runtime generes pendant l'execution :

```powershell
.\Tests\Invoke-TongBackTests.ps1 -CleanRuntime
```

Le runner detecte automatiquement Pester 3 ou Pester 5 et utilise le mode d'invocation adapte.

La suite couvre notamment :

- import du module et commandes exportees ;
- syntaxe PowerShell des scripts ;
- validite JSON des fichiers de configuration ;
- validite XML des vues XAML ;
- absence de chemins locaux dans `Config/appsettings.json` et `Config/appsettings.template.json` ;
- absence de mutation de `appsettings.json` pendant la detection Hashcat/John ;
- presence des `.gitkeep` runtime ;
- parsing Hashcat avec hashes contenant des `:` ;
- parsing John runtime et `john --show` ;
- sauvegarde multi-resultats sans doublons ;
- arguments Hashcat avec `--restore-file-path` ;
- annulation de jobs `Pending` et `Running` ;
- arret d'un processus via `ProcessId` ;
- integration GUI via `OnJobCreated` et `Stop-TbJob`.

Les tests ne lancent pas de crack Hashcat ou John reel. Ils testent le contrat PowerShell, le parsing, la persistence et le cycle de vie des jobs avec des fixtures locales.

---

## Depannage

### `hashcat.exe introuvable dans Tools/`

Installez Hashcat ou declarez son chemin :

```powershell
Install-TbTool -Tool hashcat
# ou
Set-TbActiveTool -Tool hashcat -ExePath 'C:\...\hashcat.exe'
```

### `john.exe introuvable dans Tools/`

Installez John jumbo ou declarez `john.exe` :

```powershell
Install-TbTool -Tool john
# ou
Set-TbActiveTool -Tool john -ExePath 'C:\...\john.exe'
```

### Extracteur `.7z` ou `.rar` introuvable

`Install-TbTool` extrait automatiquement les archives `.zip`, `.7z` et `.rar`. Pour `.7z`, TongBack cherche d'abord 7-Zip puis WinRAR. Pour `.rar`, TongBack cherche 7-Zip puis WinRAR/UnRAR.

Solutions :

- installer 7-Zip dans `C:\Program Files\7-Zip\7z.exe` ;
- ou installer WinRAR dans `C:\Program Files\WinRAR\WinRAR.exe` ;
- ou ajouter `7z.exe`, `WinRAR.exe` ou `UnRAR.exe` au `PATH` ;
- ou extraire l'archive manuellement dans `Tools/`.

### `python.exe introuvable dans le PATH`

Certains extracteurs `*2john.py` ne peuvent pas tourner. Installez Python 3 et verifiez :

```powershell
python --version
```

### `perl.exe introuvable dans le PATH`

Les extracteurs Perl comme `pdf2john.pl` ou `7z2john.pl` ne peuvent pas tourner. Installez Perl et verifiez :

```powershell
perl --version
```

### `Arguments invalides`

TongBack valide les combinaisons avant lancement :

- mode `0` : au moins une wordlist ;
- mode `1` : deux wordlists ;
- mode `3` : un masque ;
- modes `6` et `7` : wordlist + masque ;
- `Hash` ou `FilePath` obligatoire.

### Aucun resultat dans `Get-TbResult`

Verifiez :

```powershell
Get-TbJob -Id '<job-guid>'
Get-TbLog -JobId '<job-guid>'
```

Un job avec exit code `1` peut etre marque `Completed` meme si aucun mot de passe n'a ete trouve.

### GUI ne se lance pas

La GUI requiert Windows, WPF et PowerShell 7 :

```powershell
$PSVersionTable.PSVersion
.\TongBack-GUI.ps1
```

---

## Notes de developpement

Le dossier `Temp/` est reserve aux fichiers generes localement et reste ignore par Git, sauf son `.gitkeep`. La documentation officielle se base sur les commandes exportees par `TongBack.psm1`.

---

## Auteur

**Othmane AZIRAR**

Projet : TongBack v3.0.0
