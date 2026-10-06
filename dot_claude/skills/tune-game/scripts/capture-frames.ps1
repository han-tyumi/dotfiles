<#
.SYNOPSIS
Records a game's frames with PresentMon, then summarizes them with
analyze-frames.ps1.

.DESCRIPTION
With -Seconds, records for that long and stops. With -Seconds 0, records until
the game exits, which suits a whole play session analyzed afterwards. The CSV is
kept under -OutputDirectory so later runs can be compared with earlier ones.
Runs unelevated; the game must run under the same Windows account. Start it
before the game launches to fill the HybridPresent column, which PresentMon only
learns when the game creates its swap chain.

Without -RefreshHz, the refresh rate comes from the one display Windows reports
as active (the internal panel when nothing else is connected).

.EXAMPLE
pwsh -NoProfile -File capture-frames.ps1 -Process witcher3.exe -Seconds 60 -Label novigrad-rt
#>
#Requires -Version 7.2
param(
  [Parameter(Mandatory)] [string] $Process,
  [int] $Seconds = 60,
  [int] $DelaySeconds = 0,
  [string] $Label = 'capture',
  [string] $OutputDirectory = (Join-Path $env:LOCALAPPDATA 'tune-game\captures'),
  [double] $RefreshHz
)
$ErrorActionPreference = 'Stop'

$presentMon = (Get-Command presentmon -ErrorAction SilentlyContinue).Source
if (-not $presentMon) { throw 'presentmon not found on PATH; install it with: winget install --id Intel.PresentMon.Console --exact' }

$processName = if ($Process -like '*.exe') { $Process } else { "$Process.exe" }
if (-not (Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($processName)) -ErrorAction SilentlyContinue)) {
  Write-Warning "$processName is not running yet; PresentMon records once it starts presenting."
}

if (-not $RefreshHz) {
  $activeDisplays = @(Get-CimInstance Win32_VideoController | Where-Object CurrentRefreshRate -GT 1)
  if ($activeDisplays.Count -eq 1) {
    $RefreshHz = $activeDisplays[0].CurrentRefreshRate
  } else {
    $RefreshHz = 60
    Write-Warning "Found $($activeDisplays.Count) active displays; assuming 60 Hz. Pass -RefreshHz to match the one the game is on."
  }
}
Write-Host "Analyzing at $RefreshHz Hz."

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$gameName = [IO.Path]::GetFileNameWithoutExtension($processName)
$outputPath = Join-Path $OutputDirectory ('{0}-{1}-{2:yyyyMMdd-HHmmss}.csv' -f $gameName, $Label, (Get-Date))

$presentMonArguments = @(
  '--process_name', $processName,
  '--output_file', $outputPath,
  '--session_name', "tune-game-$Label",
  '--stop_existing_session',
  '--no_console_stats',
  '--v2_metrics',
  '--track_hybrid_present'
)
if ($DelaySeconds -gt 0) { $presentMonArguments += '--delay', $DelaySeconds }
if ($Seconds -gt 0) {
  $presentMonArguments += '--timed', $Seconds, '--terminate_after_timed'
} else {
  $presentMonArguments += '--terminate_on_proc_exit'
}

& $presentMon @presentMonArguments
if ($LASTEXITCODE -ne 0) { throw "presentmon exited with $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $outputPath) -or (Get-Content -LiteralPath $outputPath -TotalCount 2).Count -lt 2) {
  throw "No frames recorded for $processName. Is it running and presenting under this account?"
}

Write-Host "Saved $outputPath"
& (Join-Path $PSScriptRoot 'analyze-frames.ps1') -Path $outputPath -Process $processName -RefreshHz $RefreshHz
