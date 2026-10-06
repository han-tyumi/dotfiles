<#
.SYNOPSIS
Finds an installed Steam game by name: app id, install folder, candidate game
executables, and folders likely to hold its settings files.

.DESCRIPTION
Matches -Name against every library's app manifests: a case-insensitive
substring of the store name or install folder, ignoring spaces and punctuation
('witcher3' finds "The Witcher 3: Wild Hunt"). Config candidates come from the
usual per-user roots, matched on the game's name words and numbering, plus an
Unreal Engine game's project folder; they are leads to inspect, not a guaranteed
list.

.EXAMPLE
pwsh -NoProfile -File find-game.ps1 -Name 'witcher 3'
#>
#Requires -Version 7.2
param(
  [Parameter(Mandatory)] [string] $Name
)
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'

$steamRoot = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
if (-not $steamRoot) { throw 'Steam is not installed for this user.' }
$steamRoot = $steamRoot -replace '/', '\'

$libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
$libraryRoots = @($steamRoot) + @(
  Select-String -LiteralPath $libraryFile -Pattern '"path"\s+"([^"]+)"' |
    ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
) | Sort-Object -Unique

function Get-ManifestField([string] $manifestText, [string] $fieldName) {
  if ($manifestText -match ('"' + $fieldName + '"\s+"([^"]*)"')) { return $Matches[1] }
}

function ConvertTo-Compact([string] $text) { ($text -replace '[^\p{L}\p{N}]+', '').ToLowerInvariant() }

# Sequel numbering as a set of tokens: digits without leading zeros, and Roman
# numerals only in capitals so the word "I" in a title isn't one.
function Get-Numerals([string] $text) {
  @($text -split '[^\p{L}\p{N}]+' | Where-Object { $_ -cmatch '^(\d+|[IVXLC]+)$' } |
      ForEach-Object { $_ -replace '^0+(?=\d)', '' } | Sort-Object -Unique)
}

$compactQuery = ConvertTo-Compact $Name
if (-not $compactQuery) { throw "'$Name' has no letters or digits to match." }

# Compacting erases word breaks ("I & II" reads as "III"), so numbering in the
# query must also appear in the game's name.
$queryNumerals = Get-Numerals $Name
$matchedGames = foreach ($libraryRoot in $libraryRoots) {
  $steamApps = Join-Path $libraryRoot 'steamapps'
  foreach ($manifest in Get-ChildItem -LiteralPath $steamApps -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue) {
    $manifestText = Get-Content -LiteralPath $manifest.FullName -Raw
    $storeName = Get-ManifestField $manifestText 'name'
    $installFolder = Get-ManifestField $manifestText 'installdir'
    if (-not ((ConvertTo-Compact $storeName).Contains($compactQuery) -or (ConvertTo-Compact $installFolder).Contains($compactQuery))) { continue }
    $gameNumerals = Get-Numerals "$storeName $installFolder"
    if ($queryNumerals | Where-Object { $_ -notin $gameNumerals }) { continue }
    [pscustomobject] @{
      AppId         = Get-ManifestField $manifestText 'appid'
      Name          = $storeName
      InstallFolder = $installFolder
      InstallPath   = Join-Path $steamApps "common\$installFolder"
    }
  }
}
if (-not $matchedGames) { throw "No installed Steam game matches '$Name'." }

$configRoots = @(
  [Environment]::GetFolderPath('MyDocuments'),
  (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games'),
  (Join-Path $env:USERPROFILE 'Saved Games'),
  $env:LOCALAPPDATA,
  $env:APPDATA,
  (Join-Path $env:USERPROFILE 'AppData\LocalLow'),
  (Join-Path $env:APPDATA 'Godot\app_userdata')
) | Where-Object { Test-Path -LiteralPath $_ }
$launcherNoise = 'redist|crash|report|setup|unins|install|helper|launcher|_be\.exe|easyanticheat|vc_?redist|dxsetup|ue4prereq|dotnet'

foreach ($game in $matchedGames) {
  $nameWords = @(($game.Name -replace '[^\p{L}\p{N}]+', ' ').Split(' ', [StringSplitOptions]::RemoveEmptyEntries) |
      Where-Object { $_.Length -ge 3 -and $_ -notmatch '^(the|and|for|edition|remastered|definitive)$' })
  $nameNumerals = (Get-Numerals $game.Name) -join ' '
  $compactInstallFolder = ConvertTo-Compact $game.InstallFolder
  $allExecutables = @(Get-ChildItem -LiteralPath $game.InstallPath -Filter *.exe -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch $launcherNoise } | Sort-Object Length -Descending)
  $executables = @($allExecutables | Select-Object -First 5 | ForEach-Object FullName)

  # Two levels covers both "<root>\<Game>" and "<root>\<Studio>\<Game>" layouts. A
  # folder qualifies when it is named after the install folder, or when it shares
  # two of the store name's words and the same numbering, so a sequel's folder
  # doesn't pass for the original's.
  $configFolders = @(foreach ($configRoot in $configRoots) {
      Get-ChildItem -LiteralPath $configRoot -Directory -Depth 1 -ErrorAction SilentlyContinue |
        Where-Object {
          $folderName = $_.Name
          $compactFolderName = ConvertTo-Compact $folderName
          if ($compactFolderName.Length -ge 4 -and $compactFolderName.Contains($compactInstallFolder)) { return $true }
          $matchingWords = @($nameWords | Where-Object { $folderName -match [regex]::Escape($_) })
          $sameNumerals = ((Get-Numerals $folderName) -join ' ') -eq $nameNumerals
          $nameWords.Count -gt 0 -and $matchingWords.Count -ge [math]::Min(2, $nameWords.Count) -and $sameNumerals
        } | ForEach-Object FullName
    })

  # Unreal Engine games ship <Project>\Binaries\Win64\<Project>-Win64-Shipping.exe
  # and keep settings under <root>\<Project>\Saved\Config, whatever the game's name.
  $unrealProjects = @($allExecutables.FullName | ForEach-Object {
      if ($_ -match '\\([^\\]+)\\Binaries\\Win64\\\1-Win64-Shipping\.exe$') { $Matches[1] }
    } | Sort-Object -Unique)
  $unrealConfigFolders = @(foreach ($configRoot in $configRoots) {
      foreach ($unrealProject in $unrealProjects) {
        $projectFolder = Join-Path $configRoot $unrealProject
        if (Test-Path -LiteralPath $projectFolder) { (Get-Item -LiteralPath $projectFolder).FullName }
      }
    })

  $cloudFolders = @(Get-ChildItem -Path (Join-Path $steamRoot 'userdata\*') -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Join-Path $_.FullName $game.AppId } | Where-Object { Test-Path -LiteralPath $_ })

  [pscustomobject] @{
    AppId         = $game.AppId
    Name          = $game.Name
    InstallPath   = $game.InstallPath
    Executables   = $executables -join "`n"
    ConfigFolders = ($configFolders + $unrealConfigFolders + $cloudFolders | Sort-Object -Unique) -join "`n"
  } | Format-List
}
