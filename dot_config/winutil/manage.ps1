# WinUtil tweak-config manager.
#   manage.ps1            (no args) check whether a newer WinUtil release exists
#   manage.ps1 -Apply     apply config.json with the pinned WinUtil, headless
#
# The `winutil-apply` shell command runs this with -Apply. -Apply self-elevates
# (one UAC prompt) because WinUtil edits HKLM.
#
# WinUtil's config format and tweak IDs are version-specific, so the config is
# pinned to $PinnedVersion; when the checker reports a newer release, bump
# $PinnedVersion, re-verify config.json against it, then run winutil-apply.
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$PinnedVersion = '26.09.29'
$configPath = Join-Path $PSScriptRoot 'config.json'

function Get-LatestWinUtilTag {
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  (Invoke-RestMethod 'https://api.github.com/repos/ChrisTitusTech/winutil/releases/latest' -Headers @{ 'User-Agent' = 'dotfiles-winutil' }).tag_name
}

if ($Apply) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    # Relaunch elevated (one UAC prompt); -NoExit keeps the window open so the
    # tweak log stays readable.
    $self = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    if (-not $self) { Write-Warning 'Cannot resolve the script path to self-elevate; run from an elevated shell.'; exit 1 }
    Start-Process -FilePath 'pwsh' -Verb RunAs -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self, '-Apply')
    exit 0
  }
  if (-not (Test-Path $configPath)) { Write-Warning "config.json not found at $configPath"; exit 1 }

  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  # Kept out of %TEMP%: WinUtil deletes a winutil-*.ps1 there once a headless run finishes.
  $winutilDir = Join-Path $env:LOCALAPPDATA 'winutil'
  $winutil = Join-Path $winutilDir "release-$PinnedVersion.ps1"
  if (-not (Test-Path $winutil)) {
    New-Item -ItemType Directory -Force -Path $winutilDir | Out-Null
    Write-Host "Downloading WinUtil $PinnedVersion..."
    Invoke-WebRequest "https://github.com/ChrisTitusTech/winutil/releases/download/$PinnedVersion/winutil.ps1" -OutFile $winutil -UseBasicParsing
    Unblock-File $winutil
  }

  # WinUtil's -Config run builds no window and reports through $LASTEXITCODE:
  # 0 done (possibly with warnings), 1 a step failed or timed out or config.json
  # names a tweak this version lacks, 2 nothing selected. Its stray pipeline
  # output is discarded. Fall back to the GUI if a build lacks that runner.
  $source = [System.IO.File]::ReadAllText($winutil)
  if (-not $source.Contains('function Write-WinUtilAutoRunSummary')) {
    Write-Warning "WinUtil $PinnedVersion has no native headless runner. Launching the GUI - import $configPath, then click Run Tweaks."
    & $winutil
    exit 1
  }

  # Invoke-WinUtilTweaks catches a missing service as
  # [System.ServiceProcess.ServiceNotFoundException], a type .NET does not have, so
  # any listed service absent from this edition (CscService on Home) throws
  # "Unable to find type" and aborts every tweak after it. Catch the exception
  # Get-Service really throws; Set-WinUtilService already warns and skips a missing
  # service. A build without the bad type runs unpatched.
  $badServiceCatch = 'catch [System.ServiceProcess.ServiceNotFoundException]'
  if ($source.Contains($badServiceCatch)) {
    $winutil = Join-Path $winutilDir "release-$PinnedVersion-patched.ps1"
    $patchedSource = $source.Replace($badServiceCatch, 'catch [Microsoft.PowerShell.Commands.ServiceCommandException]')
    [System.IO.File]::WriteAllText($winutil, $patchedSource, (New-Object System.Text.UTF8Encoding($false)))
  }

  Write-Host "Applying config.json headless with WinUtil $PinnedVersion..."
  $global:LASTEXITCODE = 0
  $null = & $winutil -Config $configPath
  $winutilExitCode = $LASTEXITCODE
  if ($winutilExitCode -ne 0) {
    Write-Warning "WinUtil exited with code $winutilExitCode. The log is under $winutilDir\logs."
    exit $winutilExitCode
  }
  Write-Host 'WinUtil apply finished. Some tweaks need a reboot to fully take effect.'
  exit 0
}

# Default: best-effort update check; stays silent when up to date or offline.
try {
  $latest = Get-LatestWinUtilTag
  if ($latest -and $latest -ne $PinnedVersion) {
    Write-Host "WinUtil $latest is available (pinned: $PinnedVersion)." -ForegroundColor Yellow
    Write-Host "  Review it, bump `$PinnedVersion in manage.ps1, re-verify config.json, then run: winutil-apply" -ForegroundColor Yellow
  }
} catch {
  # Network/API failure — checking for updates is best-effort, so ignore.
}
