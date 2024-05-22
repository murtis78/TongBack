# TongBack

## IMPORTANT
Il faut créer un dossier `Tools/` dans lequel il faudra dézipper les fichiers qui se trouvent dans `Requirements/` :
  - **john-1.9.0-jumbo-1-win64.zip**
  - **hashcat-6.2.6.7z**

Il faut également installer Python, et on peut utiliser une Wordlist contenue dans `SecLists-master.zip`.

## Synopsis
Ce script PowerShell facilite l'utilisation de l'outil Hashcat.

## Description
Ce script PowerShell simplifie l'utilisation de l'outil Hashcat en fournissant des fonctions pour rechercher des formats de hash, extraire des hashes à partir de fichiers et exécuter des attaques de craquage de mots de passe. Le script prend en charge différents modes d'attaque, l'utilisation de listes de mots et les attaques par force brute.

## Paramètres

- **help**
  - Affiche l'aide pour le script.

- **search**
  - Effectue une recherche de format de hash à l'aide de la chaîne de recherche spécifiée.

- **wordlist**
  - Spécifie une ou deux listes de mots pour l'attaque.

- **file**
  - Spécifie le fichier contenant le hash ou à partir duquel extraire le hash.

- **hash**
  - Spécifie le hash directement.

- **hashmode**
  - Spécifie le format de hash à craquer.

- **mask**
  - Spécifie le jeu de caractères pour une attaque par force brute.
    - `?l` = abcdefghijklmnopqrstuvwxyz
    - `?u` = ABCDEFGHIJKLMNOPQRSTUVWXYZ
    - `?d` = 0123456789
    - `?h` = 0123456789abcdef
    - `?H` = 0123456789ABCDEF
    - `?s` = « espace »!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
    - `?a` = ?l?u?d?s
    - `?b` = 0x00 - 0xff

- **mode**
  - Spécifie le mode d'attaque (0, 1, 3, 6, 7).
    - `0` = Attaque par dictionnaire
    - `1` = Attaque par combinaison (Wordlist + Wordlist)
    - `3` = Attaque par dictionnaire avec masque (Wordlist + Masque)
    - `6` = Attaque hybride (Wordlist + Masque)
    - `7` = Attaque hybride (Masque + Wordlist)

## Exemples

```powershell
.\TongBack.ps1 -mode 1 -hash "votre_hash_ici" -wordlist "liste1.txt" "liste2.txt"
```
Cet exemple exécute une attaque de craquage de mot de passe en mode 1 en utilisant le hash spécifié et deux listes de mots.

```powershell
.\TongBack.ps1 -mode 1 -file "chemin\vers\hashes.txt" -wordlist "liste1.txt" "liste2.txt"
```
Cet exemple exécute une attaque de craquage de mot de passe en mode 1 en utilisant le hash extrait du fichier spécifié et deux listes de mots.

## Notes

- **Auteur :** Othmane AZIRAR
- **Version :** 1.0

## Installation

Clonez ce dépôt et naviguez vers le répertoire cloné.

```bash
git clone <URL_DU_DEPOT>
cd <REPERTOIRE_CLONE>
```

## Utilisation

Pour exécuter le script, utilisez PowerShell et spécifiez les paramètres appropriés selon votre besoin. Par exemple, pour exécuter une attaque de combinaison avec deux listes de mots :

```powershell
.\TongBack.ps1 -mode 1 -hash "votre_hash_ici" -wordlist "liste1.txt" "liste2.txt"
```

Pour plus d'aide sur l'utilisation du script, exécutez :

```powershell
.\TongBack.ps1 -help
```

Cela affichera un message d'aide détaillant toutes les options disponibles et comment les utiliser.
