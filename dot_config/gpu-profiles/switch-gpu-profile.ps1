<#
.SYNOPSIS
Switches each game in gpu-profiles.json to the settings for the GPU present.

.DESCRIPTION
The first GPU in the manifest whose name matches a working display adapter
picks the profile. The eGPU can only change while the machine is off, so a
logon task runs this once per boot.

Switching saves the game's live settings file as the outgoing GPU's copy, then
restores the incoming GPU's saved copy, so changes made in the game's menus
stay with the GPU they were made on. A GPU with no saved copy yet gets the
manifest's settings applied to the live file. -Reseed applies the manifest's
settings to the current GPU's file again, after the manifest changes. Each
profile's rtssLimit sets the game's RTSS frame cap; watch-games.ps1 applies its
panelHz while the game runs.

A running game is left alone. Saved copies, the active profile per game and a
log live under %LOCALAPPDATA%\gpu-profiles.

.EXAMPLE
pwsh -NoProfile -File switch-gpu-profile.ps1

.EXAMPLE
pwsh -NoProfile -File switch-gpu-profile.ps1 -Reseed

.EXAMPLE
pwsh -NoProfile -File switch-gpu-profile.ps1 -GpuProfile 890m
#>
#Requires -Version 7.2
param(
  [string] $GpuProfile,
  [switch] $Reseed,
  [string] $ManifestPath = (Join-Path $PSScriptRoot 'gpu-profiles.json'),
  [string] $StoreDirectory = (Join-Path $env:LOCALAPPDATA 'gpu-profiles')
)
$ErrorActionPreference = 'Stop'

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json -AsHashtable
New-Item -ItemType Directory -Force -Path $StoreDirectory | Out-Null
$logPath = Join-Path $StoreDirectory 'switch.log'
$statePath = Join-Path $StoreDirectory 'state.json'

function Write-SwitchLog([string] $message) {
  Add-Content -LiteralPath $logPath -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $message) -Encoding utf8
  Write-Host $message
}

function Get-PresentGpuProfile {
  $workingAdapters = @(Get-CimInstance Win32_VideoController | Where-Object ConfigManagerErrorCode -EQ 0 | ForEach-Object Name)
  foreach ($gpu in $manifest.gpus) {
    if ($workingAdapters | Where-Object { $_ -like $gpu.match }) { return $gpu.name }
  }
}

function Set-JsonValue($document, [string] $path, $value) {
  $segments = $path.Split('.')
  $node = $document
  foreach ($segment in ($segments | Select-Object -SkipLast 1)) {
    $node = $node.$segment
    if ($null -eq $node) { throw "No '$segment' on the way to '$path'." }
  }
  $leaf = $segments[-1]
  if ($node.PSObject.Properties.Name -contains $leaf) {
    $node.$leaf = $value
  } else {
    $node | Add-Member -NotePropertyName $leaf -NotePropertyValue $value
  }
}

# Games write their settings tab-indented, so convert ConvertTo-Json's
# two-space indent back and keep the file's line endings and trailing newline.
function Update-JsonFile([string] $settingsPath, $settings) {
  $original = [IO.File]::ReadAllText($settingsPath)
  $document = $original | ConvertFrom-Json
  foreach ($path in $settings.Keys) { Set-JsonValue $document $path $settings[$path] }
  $lineEnding = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
  $tabbedLines = ($document | ConvertTo-Json -Depth 32) -split "`r?`n" | ForEach-Object {
    $trimmed = $_.TrimStart(' ')
    ("`t" * (($_.Length - $trimmed.Length) / 2)) + $trimmed
  }
  $trailingNewline = if ($original.EndsWith("`n")) { $lineEnding } else { '' }
  [IO.File]::WriteAllText($settingsPath, ($tabbedLines -join $lineEnding) + $trailingNewline, [Text.UTF8Encoding]::new($false))
}

function Set-RtssLimit([string] $exeName, [int] $limit) {
  $profilesDirectory = Join-Path ${env:ProgramFiles(x86)} 'RivaTuner Statistics Server\Profiles'
  if (-not (Test-Path -LiteralPath $profilesDirectory)) { return }
  $profilePath = Join-Path $profilesDirectory "$exeName.cfg"
  $lines = [Collections.Generic.List[string]]::new()
  if (Test-Path -LiteralPath $profilePath) { $lines.AddRange([IO.File]::ReadAllLines($profilePath)) }
  $original = $lines -join "`r`n"
  $sectionStart = $lines.IndexOf('[Framerate]')
  if ($sectionStart -lt 0) {
    $lines.Add('[Framerate]')
    $lines.Add("Limit=$limit")
  } else {
    $sectionEnd = $sectionStart + 1
    while ($sectionEnd -lt $lines.Count -and -not $lines[$sectionEnd].StartsWith('[')) { $sectionEnd++ }
    $limitLine = -1
    for ($lineIndex = $sectionStart + 1; $lineIndex -lt $sectionEnd; $lineIndex++) {
      if ($lines[$lineIndex] -like 'Limit=*') { $limitLine = $lineIndex; break }
    }
    if ($limitLine -ge 0) { $lines[$limitLine] = "Limit=$limit" } else { $lines.Insert($sectionStart + 1, "Limit=$limit") }
  }
  $updated = $lines -join "`r`n"
  if ($updated -ne $original) { [IO.File]::WriteAllText($profilePath, "$updated`r`n", [Text.Encoding]::ASCII) }
}

$targetGpu = if ($GpuProfile) { $GpuProfile } else { Get-PresentGpuProfile }
if (-not $targetGpu) {
  Write-SwitchLog 'No GPU in the manifest is present; nothing switched.'
  exit 1
}

$state = if (Test-Path -LiteralPath $statePath) { Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -AsHashtable } else { @{} }

foreach ($gameKey in $manifest.games.Keys) {
  $game = $manifest.games[$gameKey]
  $targetProfile = $game.profiles[$targetGpu]
  if (-not $targetProfile) { continue }
  $activeGpu = $state[$gameKey]

  if (Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($game.exe)) -ErrorAction SilentlyContinue) {
    if ($activeGpu -ne $targetGpu) { Write-SwitchLog "${gameKey}: running, so left on $activeGpu." }
    continue
  }
  if ($targetProfile.rtssLimit) { Set-RtssLimit $game.exe $targetProfile.rtssLimit }
  if (-not $game.settingsFile -or ($activeGpu -eq $targetGpu -and -not $Reseed)) { continue }

  $settingsPath = [Environment]::ExpandEnvironmentVariables($game.settingsFile)
  if (-not (Test-Path -LiteralPath $settingsPath)) {
    Write-SwitchLog "${gameKey}: no settings file at $settingsPath; skipped."
    continue
  }
  $fileName = Split-Path -Leaf $settingsPath

  if ($activeGpu -and $activeGpu -ne $targetGpu) {
    $outgoingDirectory = Join-Path $StoreDirectory "$gameKey\$activeGpu"
    New-Item -ItemType Directory -Force -Path $outgoingDirectory | Out-Null
    Copy-Item -LiteralPath $settingsPath -Destination (Join-Path $outgoingDirectory $fileName) -Force
  }

  $savedCopy = Join-Path $StoreDirectory "$gameKey\$targetGpu\$fileName"
  if (-not $Reseed -and (Test-Path -LiteralPath $savedCopy)) {
    Copy-Item -LiteralPath $savedCopy -Destination $settingsPath -Force
    $change = "restored the $targetGpu copy"
  } else {
    Update-JsonFile $settingsPath $targetProfile.settings
    $change = 'applied the manifest settings'
  }
  $state[$gameKey] = $targetGpu
  $from = if ($activeGpu) { $activeGpu } else { '(none)' }
  Write-SwitchLog "${gameKey}: $from -> $targetGpu; $change, RTSS limit $($targetProfile.rtssLimit)."
}

$state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8
