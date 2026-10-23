#Requires -Version 7.0

<#
.SYNOPSIS
    Adds the games in games.json to Steam as non-Steam shortcuts, with artwork.

.DESCRIPTION
    Each game with a `steam` block gets a shortcut in the Steam account's
    shortcuts.vdf, matched by name. A game behind a launcher starts through
    game-launch.vbs so Steam keeps tracking it past the launcher's handoff; a
    game with no launcher, or one whose launcher's strategy is `direct`, runs
    its `exe` directly.

    Artwork goes to the account's config\grid folder, named by the shortcut's
    app id. A URL pinned under `steam.art` always wins. An unpinned slot with no
    image yet gets SteamGridDB's top-scored image for the game named by
    `steam.steamGridDb` (a game id, or a name to search), and the URL is printed
    so it can be pinned. Art set by hand in Steam fills a slot too, so it is
    left alone. The lookup needs a SteamGridDB API key in the credential store,
    which -Setup stores.

    Steam rewrites shortcuts.vdf when it exits, so shortcuts are only written
    while Steam is closed. Artwork is written either way and shows once Steam
    restarts.

.EXAMPLE
    pwsh -NoProfile -File steam-shortcuts.ps1

.EXAMPLE
    pwsh -NoProfile -File steam-shortcuts.ps1 -Game clone-hero

.EXAMPLE
    pwsh -NoProfile -File steam-shortcuts.ps1 -Setup
#>

param(
    [string]$Game,
    [string]$AccountId,

    # Prompts for a SteamGridDB API key and stores it in the credential store.
    [switch]$Setup
)

$ErrorActionPreference = 'Stop'

$registryPath = Join-Path $PSScriptRoot 'games.json'
$runnerPath = Join-Path $PSScriptRoot 'game-launch.vbs'
$artStatePath = Join-Path $env:LOCALAPPDATA 'steam-shortcuts\art.json'
$steamGridDbApi = 'https://www.steamgriddb.com/api/v2'
$keyringArguments = @('--quiet', '--from', 'keyring==25.7.0', 'keyring')
$steamId64Base = 76561197960265728

if ($Setup) {
    Write-Host 'Get an API key at https://www.steamgriddb.com/profile/preferences/api.'
    $secureKey = Read-Host -AsSecureString -Prompt 'SteamGridDB API key (input is hidden)'
    $plainKey = [Net.NetworkCredential]::new('', $secureKey).Password.Trim()
    if (-not $plainKey) { throw 'No key entered; nothing stored.' }

    # Piped on stdin, so keyring stores it without its own password prompt.
    $plainKey | & uvx @keyringArguments set steamgriddb api-key
    if ($LASTEXITCODE) { throw 'keyring could not store the key.' }
    Write-Host 'Stored the SteamGridDB API key.'
    return
}

# Steam's grid file suffix for each artwork slot, and where SteamGridDB serves it.
$artSlots = [ordered]@{
    portrait = @{ suffix = 'p'; endpoint = 'grids'; query = 'dimensions=600x900' }
    wide     = @{ suffix = ''; endpoint = 'grids'; query = 'dimensions=920x430,460x215' }
    hero     = @{ suffix = '_hero'; endpoint = 'heroes'; query = $null }
    logo     = @{ suffix = '_logo'; endpoint = 'logos'; query = $null }
    icon     = @{ suffix = '_icon'; endpoint = 'icons'; query = $null }
}
$artExtensions = @('.png', '.jpg', '.jpeg', '.webp', '.ico')

function Read-VdfString([IO.BinaryReader]$Reader) {
    $buffer = [Collections.Generic.List[byte]]::new()
    while (($next = $Reader.ReadByte()) -ne 0) { $buffer.Add($next) }
    return [Text.Encoding]::UTF8.GetString($buffer.ToArray())
}

function Read-VdfMap([IO.BinaryReader]$Reader) {
    $map = [ordered]@{}
    while ($true) {
        $type = $Reader.ReadByte()
        if ($type -eq 0x08) { return $map }
        $key = Read-VdfString $Reader
        $map[$key] = switch ($type) {
            0x00 { Read-VdfMap $Reader }
            0x01 { Read-VdfString $Reader }
            0x02 { $Reader.ReadInt32() }
            0x03 { $Reader.ReadSingle() }
            0x07 { $Reader.ReadUInt64() }
            default { throw ("Unsupported binary VDF type 0x{0:x2} at key '{1}'." -f $type, $key) }
        }
    }
}

function Write-VdfString([IO.BinaryWriter]$Writer, [string]$Text) {
    $Writer.Write([Text.Encoding]::UTF8.GetBytes($Text))
    $Writer.Write([byte]0)
}

function Get-VdfType([string]$Key, $Value) {
    if ($Value -is [Collections.IDictionary]) { return 0x00 }
    if ($Value -is [string]) { return 0x01 }
    if ($Value -is [int]) { return 0x02 }
    if ($Value -is [single]) { return 0x03 }
    if ($Value -is [uint64]) { return 0x07 }
    throw "No binary VDF type for '$Key' ($($Value.GetType().Name))."
}

function Write-VdfMap([IO.BinaryWriter]$Writer, [Collections.IDictionary]$Map) {
    foreach ($key in $Map.Keys) {
        $value = $Map[$key]
        $type = Get-VdfType $key $value
        $Writer.Write([byte]$type)
        Write-VdfString $Writer $key
        switch ($type) {
            0x00 { Write-VdfMap $Writer $value }
            0x01 { Write-VdfString $Writer $value }
            default { $Writer.Write($value) }
        }
    }
    $Writer.Write([byte]0x08)
}

function ConvertFrom-BinaryVdf([byte[]]$Bytes) {
    $reader = [IO.BinaryReader]::new([IO.MemoryStream]::new($Bytes))
    try { return Read-VdfMap $reader } finally { $reader.Dispose() }
}

function ConvertTo-BinaryVdf([Collections.IDictionary]$Document) {
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    try {
        Write-VdfMap $writer $Document
        $writer.Flush()
        return , $stream.ToArray()
    } finally { $writer.Dispose() }
}

function Get-Crc32([byte[]]$Bytes) {
    $crc = 0xFFFFFFFFL
    foreach ($byte in $Bytes) {
        $crc = $crc -bxor $byte
        for ($bit = 0; $bit -lt 8; $bit++) {
            $crc = if ($crc -band 1) { ($crc -shr 1) -bxor 0xEDB88320L } else { $crc -shr 1 }
        }
    }
    return $crc -bxor 0xFFFFFFFFL
}

# Steam's own id for a shortcut: the CRC of its target and name with the top bit
# set, stored signed in shortcuts.vdf and unsigned in grid file names.
function Get-ShortcutAppId([string]$Exe, [string]$Name) {
    $unsignedId = (Get-Crc32 ([Text.Encoding]::UTF8.GetBytes($Exe + $Name))) -bor 0x80000000L
    return [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$unsignedId), 0)
}

function Get-SteamAccountId([string]$SteamPath) {
    $loginUsersPath = Join-Path $SteamPath 'config\loginusers.vdf'
    if (Test-Path -LiteralPath $loginUsersPath) {
        $mostRecent = [regex]::Match((Get-Content -Raw -LiteralPath $loginUsersPath), '"(\d{17})"\s*\{[^}]*?"MostRecent"\s*"1"', 'IgnoreCase')
        if ($mostRecent.Success) { return [string]([long]$mostRecent.Groups[1].Value - $steamId64Base) }
    }
    $accounts = @(Get-ChildItem (Join-Path $SteamPath 'userdata') -Directory | Where-Object Name -Match '^[1-9]\d*$')
    if ($accounts.Count -eq 1) { return $accounts[0].Name }
    throw 'Could not tell which Steam account to use; pass -AccountId.'
}

function Get-SteamGridDbKey {
    if ($null -eq $script:steamGridDbKey) {
        $script:steamGridDbKey = ''
        try {
            $stored = & uvx @keyringArguments get steamgriddb api-key 2>$null
            if ($LASTEXITCODE -eq 0 -and $stored) { $script:steamGridDbKey = "$stored".Trim() }
        } catch [Management.Automation.CommandNotFoundException] {
            Write-Warning 'uvx is not on PATH, so the SteamGridDB key cannot be read.'
        }
    }
    return $script:steamGridDbKey
}

function Invoke-SteamGridDb([string]$Path) {
    $response = Invoke-RestMethod -Uri "$steamGridDbApi$Path" -Headers @{ Authorization = "Bearer $(Get-SteamGridDbKey)" }
    if (-not $response.success) { throw "SteamGridDB request failed: $Path" }
    return $response.data
}

function Resolve-SteamGridDbGameId($Reference) {
    if ("$Reference" -match '^\d+$') { return [int]$Reference }
    $searchResults = @(Invoke-SteamGridDb "/search/autocomplete/$([uri]::EscapeDataString($Reference))")
    if (-not $searchResults) { throw "SteamGridDB has no game matching '$Reference'." }
    Write-Host "  SteamGridDB matched '$Reference' to $($searchResults[0].name) ($($searchResults[0].id))."
    return [int]$searchResults[0].id
}

function Find-SteamGridDbImage([int]$GameId, [hashtable]$Slot) {
    $query = @('types=static', 'nsfw=false', 'humor=false', $Slot.query) | Where-Object { $_ }
    $images = @(Invoke-SteamGridDb "/$($Slot.endpoint)/game/$($GameId)?$($query -join '&')")
    return ($images | Sort-Object score -Descending | Select-Object -First 1).url
}

function Find-SlotFile([string]$GridDirectory, [string]$BaseName) {
    foreach ($extension in $artExtensions) {
        $candidate = Join-Path $GridDirectory "$BaseName$extension"
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
}

function Save-SlotArt([string]$GridDirectory, [string]$BaseName, [string]$Url, [hashtable]$ArtState) {
    $extension = [IO.Path]::GetExtension(([uri]$Url).AbsolutePath).ToLowerInvariant()
    if ($extension -notin $artExtensions) { $extension = '.png' }
    $target = Join-Path $GridDirectory "$BaseName$extension"
    if ((Test-Path -LiteralPath $target) -and $ArtState[$target] -eq $Url) { return $target }

    # Steam reads one file per slot, so another format's copy would compete.
    foreach ($otherExtension in $artExtensions | Where-Object { $_ -ne $extension }) {
        Remove-Item -LiteralPath (Join-Path $GridDirectory "$BaseName$otherExtension") -ErrorAction SilentlyContinue
    }
    Invoke-WebRequest -Uri $Url -OutFile $target
    $ArtState[$target] = $Url
    return $target
}

$steamPath = (Get-ItemProperty HKCU:\Software\Valve\Steam).SteamPath
if (-not $AccountId) { $AccountId = Get-SteamAccountId $steamPath }
$configDirectory = Join-Path $steamPath "userdata\$AccountId\config"
$shortcutsPath = Join-Path $configDirectory 'shortcuts.vdf'
$gridDirectory = Join-Path $configDirectory 'grid'
New-Item -ItemType Directory -Force -Path $gridDirectory, (Split-Path $artStatePath) | Out-Null

$originalBytes = if (Test-Path -LiteralPath $shortcutsPath) { [IO.File]::ReadAllBytes($shortcutsPath) } else { $null }
$document = if ($originalBytes) { ConvertFrom-BinaryVdf $originalBytes } else { [ordered]@{ shortcuts = [ordered]@{} } }
$shortcuts = $document['shortcuts']
$artState = if (Test-Path -LiteralPath $artStatePath) { Get-Content -Raw -LiteralPath $artStatePath | ConvertFrom-Json -AsHashtable } else { @{} }

$registry = Get-Content -Raw -LiteralPath $registryPath | ConvertFrom-Json -AsHashtable
$gameKeys = $registry.games.Keys | Where-Object { $registry.games[$_].steam -and (-not $Game -or $_ -eq $Game) } | Sort-Object
if ($Game -and -not $gameKeys) { throw "No game '$Game' with a steam block in $registryPath." }

$pinSuggestions = [ordered]@{}
foreach ($gameKey in $gameKeys) {
    $entry = $registry.games[$gameKey]
    $steamEntry = $entry.steam
    $name = $steamEntry.name

    $runsThroughRunner = $entry.launcher -and $registry.launchers[$entry.launcher].strategy -ne 'direct'
    if ($runsThroughRunner) {
        $exe = Join-Path $env:SystemRoot 'System32\wscript.exe'
        $startDirectory = $PSScriptRoot
        $launchOptions = "`"$runnerPath`" $gameKey"
    } else {
        $exe = [Environment]::ExpandEnvironmentVariables($entry.exe)
        $startDirectory = Split-Path $exe
        $launchOptions = if ($steamEntry.launchOptions) { $steamEntry.launchOptions } else { '' }
    }
    $quotedExe = "`"$exe`""

    $shortcut = $shortcuts.Values | Where-Object { $_['AppName'] -eq $name } | Select-Object -First 1
    $status = 'updated'
    if (-not $shortcut) {
        $shortcut = [ordered]@{
            appid = Get-ShortcutAppId $quotedExe $name
            AppName = $name
            Exe = ''
            StartDir = ''
            icon = ''
            ShortcutPath = ''
            LaunchOptions = ''
            IsHidden = 0
            AllowDesktopConfig = 1
            AllowOverlay = 1
            OpenVR = 0
            Devkit = 0
            DevkitGameID = ''
            DevkitOverrideAppID = 0
            LastPlayTime = 0
            FlatpakAppID = ''
            tags = [ordered]@{}
        }
        $nextIndex = if ($shortcuts.Count) { ($shortcuts.Keys | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum + 1 } else { 0 }
        $shortcuts[[string][int]$nextIndex] = $shortcut
        $status = 'added'
    } elseif (-not $shortcut.Contains('appid')) {
        $shortcut['appid'] = Get-ShortcutAppId $quotedExe $name
    }

    # The comparison ignores case, so a path Steam stored as C:\Windows stays as is.
    $desiredFields = @{ Exe = $quotedExe; StartDir = $startDirectory;LaunchOptions = $launchOptions }
    foreach ($field in $desiredFields.Keys) {
        if ($shortcut[$field] -ne $desiredFields[$field]) { $shortcut[$field] = $desiredFields[$field] }
    }

    $gridId = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$shortcut['appid']), 0)
    $artReport = [Collections.Generic.List[string]]::new()
    $steamGridDbGameId = $null
    foreach ($slotName in $artSlots.Keys) {
        $slot = $artSlots[$slotName]
        $baseName = "$gridId$($slot.suffix)"
        $pinnedUrl = if ($steamEntry.art) { $steamEntry.art[$slotName] } else { $null }

        if ($pinnedUrl) {
            Save-SlotArt $gridDirectory $baseName $pinnedUrl $artState | Out-Null
            $artReport.Add("$slotName pinned")
        } elseif (Find-SlotFile $gridDirectory $baseName) {
            $artReport.Add("$slotName kept")
        } elseif (-not $steamEntry.steamGridDb) {
            $artReport.Add("$slotName none")
        } elseif (-not (Get-SteamGridDbKey)) {
            $artReport.Add("$slotName needs a SteamGridDB key")
        } else {
            if ($null -eq $steamGridDbGameId) { $steamGridDbGameId = Resolve-SteamGridDbGameId $steamEntry.steamGridDb }
            $foundUrl = Find-SteamGridDbImage $steamGridDbGameId $slot
            if ($foundUrl) {
                Save-SlotArt $gridDirectory $baseName $foundUrl $artState | Out-Null
                if (-not $pinSuggestions.Contains($gameKey)) { $pinSuggestions[$gameKey] = [ordered]@{ steamGridDb = $steamGridDbGameId; art = [ordered]@{} } }
                $pinSuggestions[$gameKey].art[$slotName] = $foundUrl
                $artReport.Add("$slotName fetched")
            } else {
                $artReport.Add("$slotName none on SteamGridDB")
            }
        }
    }

    $iconFile = Find-SlotFile $gridDirectory "$($gridId)_icon"
    if ($iconFile) { $shortcut['icon'] = $iconFile }
    elseif (-not $runsThroughRunner) { $shortcut['icon'] = $exe }

    Write-Host "${gameKey}: $name, shortcut $status ($gridId); art: $($artReport -join ', ')."
}

$artState | ConvertTo-Json | Set-Content -LiteralPath $artStatePath -Encoding utf8

$updatedBytes = ConvertTo-BinaryVdf $document
$changed = -not $originalBytes -or [Convert]::ToBase64String($originalBytes) -ne [Convert]::ToBase64String($updatedBytes)
if (-not $changed) {
    Write-Host 'shortcuts.vdf already up to date.'
} elseif (Get-Process -Name steam -ErrorAction SilentlyContinue) {
    Write-Warning 'Steam is running, so shortcuts.vdf was left alone; close Steam and run this again to write the shortcuts.'
} else {
    if ($originalBytes) { Copy-Item -LiteralPath $shortcutsPath -Destination "$shortcutsPath.bak" -Force }
    [IO.File]::WriteAllBytes($shortcutsPath, $updatedBytes)
    Write-Host "Wrote $shortcutsPath."
}

if ($pinSuggestions.Count) {
    Write-Host "`nPin these in games.json so every machine gets the same art:"
    Write-Host ($pinSuggestions | ConvertTo-Json -Depth 4)
}
