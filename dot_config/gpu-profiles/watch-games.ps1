<#
.SYNOPSIS
Holds the internal panel at the refresh rate of the game running, and returns
it to the default when no game in gpu-profiles.json is running.

.DESCRIPTION
The manifest's top-level panelHz is the default; a game's profile for the GPU
present can set its own panelHz. With several such games running, the lowest
rate wins. The display is the one on panelAdapter; the mode is saved for
the current user, which needs no admin.

A logon task keeps this running. -Once converges the panel and exits.

.EXAMPLE
pwsh -NoProfile -File watch-games.ps1

.EXAMPLE
pwsh -NoProfile -File watch-games.ps1 -Once
#>
#Requires -Version 7.2
param(
  [switch] $Once,
  [int] $PollSeconds = 3,
  [string] $ManifestPath = (Join-Path $PSScriptRoot 'gpu-profiles.json'),
  [string] $StoreDirectory = (Join-Path $env:LOCALAPPDATA 'gpu-profiles')
)
$ErrorActionPreference = 'Stop'

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json -AsHashtable
New-Item -ItemType Directory -Force -Path $StoreDirectory | Out-Null
$logPath = Join-Path $StoreDirectory 'watch.log'

function Write-WatchLog([string] $message) {
  Add-Content -LiteralPath $logPath -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $message) -Encoding utf8
  Write-Host $message
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class DisplayModes {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DisplayDevice {
    public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
    public int StateFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
  }

  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DevMode {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion;
    public short dmDriverVersion;
    public short dmSize;
    public short dmDriverExtra;
    public int dmFields;
    public int dmPositionX;
    public int dmPositionY;
    public int dmDisplayOrientation;
    public int dmDisplayFixedOutput;
    public short dmColor;
    public short dmDuplex;
    public short dmYResolution;
    public short dmTTOption;
    public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel;
    public int dmPelsWidth;
    public int dmPelsHeight;
    public int dmDisplayFlags;
    public int dmDisplayFrequency;
    public int dmICMMethod;
    public int dmICMIntent;
    public int dmMediaType;
    public int dmDitherType;
    public int dmReserved1;
    public int dmReserved2;
    public int dmPanningWidth;
    public int dmPanningHeight;
  }

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern bool EnumDisplayDevices(string device, int index, ref DisplayDevice displayDevice, int flags);

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern bool EnumDisplaySettings(string device, int modeIndex, ref DevMode mode);

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int ChangeDisplaySettingsEx(string device, ref DevMode mode, IntPtr window, int flags, IntPtr parameter);
}
'@

# Sets the refresh rate of each desktop display on the adapter matching
# $adapterMatch, keeping its resolution. Without CDS_GLOBAL the mode is saved
# for the current user only, which needs no admin.
function Set-PanelRefreshRate([string] $adapterMatch, [int] $refreshHz) {
  $attachedToDesktop = 0x1
  $currentSettings = -1
  $displayFrequencyField = 0x400000
  $updateRegistry = 0x1

  $displayDevice = [DisplayModes+DisplayDevice]::new()
  $displayDevice.cb = [Runtime.InteropServices.Marshal]::SizeOf($displayDevice)
  for ($deviceIndex = 0; [DisplayModes]::EnumDisplayDevices([NullString]::Value, $deviceIndex, [ref] $displayDevice, 0); $deviceIndex++) {
    if (-not ($displayDevice.StateFlags -band $attachedToDesktop) -or $displayDevice.DeviceString -notlike $adapterMatch) { continue }

    $mode = [DisplayModes+DevMode]::new()
    $mode.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($mode)
    if (-not [DisplayModes]::EnumDisplaySettings($displayDevice.DeviceName, $currentSettings, [ref] $mode)) { continue }
    $previousHz = $mode.dmDisplayFrequency
    if ($previousHz -eq $refreshHz) { continue }

    $mode.dmDisplayFrequency = $refreshHz
    $mode.dmFields = $displayFrequencyField
    $result = [DisplayModes]::ChangeDisplaySettingsEx($displayDevice.DeviceName, [ref] $mode, [IntPtr]::Zero, $updateRegistry, [IntPtr]::Zero)
    $outcome = if ($result -eq 0) { 'set' } else { "not set (ChangeDisplaySettingsEx returned $result)" }
    Write-WatchLog "Panel $($displayDevice.DeviceName): $previousHz Hz -> $refreshHz Hz $outcome."
  }
}

function Get-RunningGames {
  foreach ($gameKey in $manifest.games.Keys) {
    $processName = [IO.Path]::GetFileNameWithoutExtension($manifest.games[$gameKey].exe)
    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) { $gameKey }
  }
}

function Get-PresentGpuProfile {
  $workingAdapters = @(Get-CimInstance Win32_VideoController | Where-Object ConfigManagerErrorCode -EQ 0 | ForEach-Object Name)
  foreach ($gpu in $manifest.gpus) {
    if ($workingAdapters | Where-Object { $_ -like $gpu.match }) { return $gpu.name }
  }
}

function Get-WantedPanelHz([string[]] $runningGames) {
  $gameRates = foreach ($gameKey in $runningGames) {
    $gameProfile = $manifest.games[$gameKey].profiles[$presentGpu]
    if ($gameProfile) { $gameProfile.panelHz }
  }
  $lowestGameRate = $gameRates | Where-Object { $_ } | Sort-Object | Select-Object -First 1
  if ($lowestGameRate) { $lowestGameRate } else { $manifest.panelHz }
}

if (-not $manifest.panelAdapter -or -not $manifest.panelHz) {
  Write-WatchLog 'The manifest sets no panelAdapter or default panelHz; nothing to watch.'
  exit 1
}

# The eGPU can only change while the machine is off, so the present GPU holds
# for the whole session.
$presentGpu = Get-PresentGpuProfile
$previousRunning = $null
while ($true) {
  $runningGames = @(Get-RunningGames)
  $runningKey = $runningGames -join ','
  if ($runningKey -ne $previousRunning) {
    if ($null -ne $previousRunning) {
      $runningLabel = if ($runningKey) { $runningKey } else { 'no game' }
      Write-WatchLog "Running: $runningLabel."
    }
    Set-PanelRefreshRate $manifest.panelAdapter (Get-WantedPanelHz $runningGames)
    $previousRunning = $runningKey
  }
  if ($Once) { break }
  Start-Sleep -Seconds $PollSeconds
}
