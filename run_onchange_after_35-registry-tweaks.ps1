# Idempotent Windows registry tweaks generic to any Windows machine: a
# dev-friendly Explorer (show hidden files and extensions, open to This PC,
# expand the folder tree, show the full path in the title bar), the classic
# Windows 11 right-click menu, GameDVR off, long-path support, Developer Mode,
# and a Windows Update policy that stops quality updates from swapping an
# installed driver for a generic one. The HKCU pass runs unelevated; the HKLM
# pass self-elevates with a single UAC prompt, and only when an HKLM value is
# actually out of date so an already-tweaked machine prompts for nothing.
#
# Windows PowerShell 5.1-safe (runs on a first apply before pwsh 7 exists). Only
# writes on drift, and only restarts Explorer when an HKCU shell key changed.
param([switch]$HklmPass)

function Write-RegDword($path, $name, $value) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  $entry = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
  if ($null -eq $entry -or $entry.$name -ne $value) {
    New-ItemProperty -Path $path -Name $name -PropertyType DWord -Value $value -Force | Out-Null
    return $true
  }
  return $false
}

# HKLM keys and their desired values, shared by the drift check and the writer.
$hklmTweaks = @(
  @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem';              Name = 'LongPathsEnabled';                  Value = 1 },
  @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR';              Name = 'AllowGameDVR';                      Value = 0 },
  @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'; Name = 'AllowDevelopmentWithoutDevLicense'; Value = 1 },
  @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'; Name = 'AllowAllTrustedApps';               Value = 1 },
  @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';        Name = 'ExcludeWUDriversInQualityUpdate';   Value = 1 }
)

function Test-HklmDrift {
  foreach ($tweak in $hklmTweaks) {
    $current = (Get-ItemProperty -Path $tweak.Path -Name $tweak.Name -ErrorAction SilentlyContinue).($tweak.Name)
    if ($current -ne $tweak.Value) { return $true }
  }
  return $false
}

function Write-HklmState {
  foreach ($tweak in $hklmTweaks) {
    [void](Write-RegDword $tweak.Path $tweak.Name $tweak.Value)
  }
}

if ($HklmPass) { Write-HklmState; exit 0 }

# HKCU pass (no elevation needed).
$shellChanged = $false
$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$shellChanged = (Write-RegDword $advanced 'Hidden' 1) -or $shellChanged
$shellChanged = (Write-RegDword $advanced 'HideFileExt' 0) -or $shellChanged
$shellChanged = (Write-RegDword $advanced 'LaunchTo' 1) -or $shellChanged
$shellChanged = (Write-RegDword $advanced 'NavPaneShowAllFolders' 1) -or $shellChanged
$shellChanged = (Write-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' 'FullPath' 1) -or $shellChanged
[void](Write-RegDword 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0)

# The classic Windows 11 context menu: an empty InprocServer32 default value
# disables the command bar and restores the full right-click menu.
$classicMenu = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
if (-not (Test-Path $classicMenu)) {
  New-Item -Path $classicMenu -Force | Out-Null
  Set-ItemProperty -Path $classicMenu -Name '(default)' -Value ''
  $shellChanged = $true
}

# HKLM pass: self-elevate only when a system-wide value is actually out of date.
$selfPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
  Write-HklmState
} elseif (Test-HklmDrift) {
  if (-not $selfPath) { Write-Warning 'Cannot resolve script path to self-elevate; re-run apply.'; exit 1 }
  $elevated = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -Wait -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $selfPath, '-HklmPass'
  )
  if ($elevated.ExitCode -ne 0) {
    Write-Warning "HKLM tweak pass exited $($elevated.ExitCode); re-run apply to retry."
    exit 1
  }
}

if ($shellChanged) {
  Write-Output '>> Explorer shell tweaks changed; restarting Explorer.'
  Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
}
exit 0
