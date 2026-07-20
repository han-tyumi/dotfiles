# WinUtil tweak-config manager.
#   manage.ps1            (no args) check whether a newer WinUtil release exists
#   manage.ps1 -Apply     null-guard the pinned WinUtil and apply config.json headless
#
# Run -Apply from an ELEVATED shell. If the execution policy blocks the script
# (Windows PowerShell 5.1 defaults to Restricted), invoke it as:
#   pwsh -ExecutionPolicy Bypass -File "$HOME\.config\winutil\manage.ps1" -Apply
#
# WinUtil's config format and tweak IDs are version-specific, so the config is
# pinned to $PinnedVersion; when the checker reports a newer release, review it,
# re-verify/re-export config.json against it, bump $PinnedVersion, then -Apply.
# Apply needs an elevated shell: WinUtil edits HKLM and, under automation, its
# self-elevation would trigger an interactive UAC prompt.
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$PinnedVersion = '26.07.17'
$configPath = Join-Path $PSScriptRoot 'config.json'

function Get-LatestWinUtilTag {
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  (Invoke-RestMethod 'https://api.github.com/repos/ChrisTitusTech/winutil/releases/latest' -Headers @{ 'User-Agent' = 'dotfiles-winutil' }).tag_name
}

if ($Apply) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Write-Warning 'Apply needs an elevated shell (WinUtil edits HKLM). Re-run from an Administrator PowerShell.'
    exit 1
  }
  if (-not (Test-Path $configPath)) { Write-Warning "config.json not found at $configPath"; exit 1 }

  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $winutil = Join-Path $env:TEMP "winutil-$PinnedVersion.ps1"
  if (-not (Test-Path $winutil)) {
    Write-Host "Downloading WinUtil $PinnedVersion..."
    Invoke-WebRequest "https://github.com/ChrisTitusTech/winutil/releases/download/$PinnedVersion/winutil.ps1" -OutFile $winutil -UseBasicParsing
    Unblock-File $winutil
  }
  # WinUtil headless -Config runs the tweak apply before it loads the WPF stack or
  # builds the window (both happen only in GUI mode, after -Config returns), so the
  # tweak path crashes on (a) $sync.form dereferences via Invoke-WPFUIThread and
  # (b) WPF type references like [Windows.Visibility] in the progress helpers - the
  # unresolved recurrence of issue #4376 (WinUtil guards its AppX path this way but
  # never the tweaks path). Patch the downloaded copy: null-guard that one UI-thread
  # call so form derefs are skipped, and load the WPF assemblies inside the -Config
  # branch so the types resolve. Fall back to the GUI if the anchors are gone.
  $guardNeedle = '$sync.form.Dispatcher.Invoke([action]$ScriptBlock)'
  $guardWith   = 'if ($sync.form) { $sync.form.Dispatcher.Invoke([action]$ScriptBlock) }'
  $wpfNeedle   = 'Invoke-WPFImpex -type "import" -Config $Config'
  $wpfLoad     = "`n    [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')`n    [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')`n    [void][System.Reflection.Assembly]::LoadWithPartialName('WindowsBase')"
  $source = [System.IO.File]::ReadAllText($winutil)
  if (-not ($source.Contains($guardNeedle) -and $source.Contains($wpfNeedle))) {
    Write-Warning "WinUtil $PinnedVersion internals changed; cannot patch for headless apply. Launching the GUI - import $configPath, then click Run Tweaks."
    & $winutil
    exit 1
  }
  $source = $source.Replace($guardNeedle, $guardWith).Replace($wpfNeedle, $wpfNeedle + $wpfLoad)
  $patched = Join-Path $env:TEMP "winutil-$PinnedVersion-headless.ps1"
  [System.IO.File]::WriteAllText($patched, $source, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "Applying config.json headless with WinUtil $PinnedVersion (UI-thread guarded, WPF assemblies preloaded)..."
  & $patched -Config $configPath
  Write-Host 'WinUtil apply finished. Some tweaks need a reboot to fully take effect.'
  exit 0
}

# Default: best-effort update check; stays silent when up to date or offline.
try {
  $latest = Get-LatestWinUtilTag
  if ($latest -and $latest -ne $PinnedVersion) {
    Write-Host "WinUtil $latest is available (pinned: $PinnedVersion)." -ForegroundColor Yellow
    Write-Host "  Review it, re-verify config.json, bump `$PinnedVersion in manage.ps1, then run it elevated with -Apply." -ForegroundColor Yellow
  }
} catch {
  # Network/API failure — checking for updates is best-effort, so ignore.
}
