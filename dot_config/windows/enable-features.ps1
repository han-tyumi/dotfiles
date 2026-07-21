# Enable the Windows optional features and capabilities captured for this machine:
# .NET Framework 2/3/4 (older games and apps), legacy media (Windows Media Player
# + DirectPlay), a daily registry-backup task, and the OpenSSH server. Run it with
# the `windows-features` shell command. It self-elevates (one UAC prompt) since
# these need admin, and each step is a no-op when already enabled.
#
# Runtime footprint: only the OpenSSH server runs a persistent service (sshd) and
# opens inbound TCP 22; the rest stay dormant until something uses them. To turn
# SSH off later: Stop-Service sshd; Set-Service sshd -StartupType Manual.
$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  # Relaunch elevated (one UAC prompt); -NoExit keeps the window open so the DISM
  # progress and result stay readable. Windows PowerShell 5.1 has the DISM cmdlets
  # natively (no pwsh 7 compatibility shim).
  $self = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
  if (-not $self) { Write-Warning 'Cannot resolve the script path to self-elevate; run from an elevated shell.'; exit 1 }
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self)
  exit 0
}

# --- elevated ---
$failed = @()
Write-Host 'Enabling Windows features (.NET, legacy media, OpenSSH, registry backup)...' -ForegroundColor Cyan

# .NET 2/3/4 and legacy media components (matches WinUtil's dotnet + legacymedia).
foreach ($name in 'NetFx4-AdvSrvs', 'NetFx3', 'WindowsMediaPlayer', 'MediaPlayback', 'DirectPlay', 'LegacyComponents') {
  if ((Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction SilentlyContinue).State -ne 'Enabled') {
    Write-Host "  enabling $name (may download from Windows Update)..."
    try {
      Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction Stop | Out-Null
    } catch {
      $failed += "feature $name"
    }
  }
}

# OpenSSH server capability + service + firewall (the one item with a footprint).
$sshCap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue
if ($sshCap -and $sshCap.State -ne 'Installed') {
  Write-Host '  installing OpenSSH server...'
  try {
    Add-WindowsCapability -Online -Name $sshCap.Name -ErrorAction Stop | Out-Null
  } catch {
    $failed += 'OpenSSH.Server'
  }
}
$sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshd) {
  Set-Service -Name sshd -StartupType Automatic
  if ($sshd.Status -ne 'Running') { Start-Service sshd }
  if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
  }
}

# Daily registry backup (mirrors WinUtil's Registry Backup feature).
$cfgMgr = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager'
New-ItemProperty -Path $cfgMgr -Name 'EnablePeriodicBackup' -Type DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path $cfgMgr -Name 'BackupCount' -Type DWord -Value 2 -Force | Out-Null
# Run as SYSTEM via an explicit principal (the -User 'System' shorthand fails
# silently on some builds). Register with -Force so the task is (re)created to
# match this definition on every run - idempotent and self-healing, without
# depending on a prior-state probe.
try {
  $action = New-ScheduledTaskAction -Execute 'schtasks' -Argument '/run /i /tn "\Microsoft\Windows\Registry\RegIdleBackup"'
  $trigger = New-ScheduledTaskTrigger -Daily -At '00:30'
  $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  Register-ScheduledTask -TaskName 'AutoRegBackup' -Action $action -Trigger $trigger -Principal $principal -Description 'Create System Registry Backups' -Force -ErrorAction Stop | Out-Null
} catch {
  $failed += 'AutoRegBackup task'
}

if ($failed.Count -gt 0) {
  Write-Warning ("Some features did not enable (re-run windows-features to retry): " + ($failed -join ', '))
  exit 1
}
Write-Host 'Windows features applied. Some need a reboot to fully take effect.' -ForegroundColor Green
exit 0
