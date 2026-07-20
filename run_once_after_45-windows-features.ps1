# Enable the Windows optional features and capabilities captured for this machine:
# .NET Framework 2/3/4 (older games and apps), legacy media (Windows Media Player
# + DirectPlay), a daily registry-backup task, and the OpenSSH server. These need
# admin, so the script self-elevates once (one UAC prompt), and each step is a
# no-op when already applied. Fail loud so a declined or partial run re-fires.
#
# Runtime footprint: only the OpenSSH server runs a persistent service (sshd) and
# opens inbound TCP 22; the rest stay dormant until something uses them. To turn
# SSH off later: Stop-Service sshd; Set-Service sshd -StartupType Manual.
$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $self = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
  if (-not $self) { Write-Warning 'Cannot resolve the script path to self-elevate; re-run apply.'; exit 1 }
  $proc = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -Wait -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self
  )
  if ($proc.ExitCode -ne 0) {
    Write-Warning "Windows features pass exited $($proc.ExitCode); re-run apply to retry."
    exit 1
  }
  exit 0
}

# --- elevated ---
$failed = @()

# .NET 2/3/4 and legacy media components (matches WinUtil's dotnet + legacymedia).
foreach ($name in 'NetFx4-AdvSrvs', 'NetFx3', 'WindowsMediaPlayer', 'MediaPlayback', 'DirectPlay', 'LegacyComponents') {
  if ((Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction SilentlyContinue).State -ne 'Enabled') {
    try {
      Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction Stop | Out-Null
      Write-Host "Enabled feature: $name"
    } catch {
      $failed += "feature $name"
    }
  }
}

# OpenSSH server capability + service + firewall (the one item with a footprint).
$sshCap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue
if ($sshCap -and $sshCap.State -ne 'Installed') {
  try {
    Add-WindowsCapability -Online -Name $sshCap.Name -ErrorAction Stop | Out-Null
    Write-Host "Installed capability: $($sshCap.Name)"
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
if (-not (Get-ScheduledTask -TaskName 'AutoRegBackup' -ErrorAction SilentlyContinue)) {
  $action = New-ScheduledTaskAction -Execute 'schtasks' -Argument '/run /i /tn "\Microsoft\Windows\Registry\RegIdleBackup"'
  $trigger = New-ScheduledTaskTrigger -Daily -At '00:30'
  Register-ScheduledTask -Action $action -Trigger $trigger -TaskName 'AutoRegBackup' -Description 'Create System Registry Backups' -User 'System' | Out-Null
  Write-Host 'Registered AutoRegBackup daily task.'
}

if ($failed.Count -gt 0) {
  Write-Warning ("Some features did not enable (re-run apply to retry): " + ($failed -join ', '))
  exit 1
}
Write-Host 'Windows features applied.'
exit 0
