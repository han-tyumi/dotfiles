<#
.SYNOPSIS
Reads the open GPU-Z window's fields for the card it shows.

.DESCRIPTION
GPU-Z runs elevated, so only the user can start it, but its window text reads
unelevated. Prints the card selected in GPU-Z's dropdown with its Bus Interface
(max @ current link), Resizable BAR state and driver version, plus the Sensors
tab's load, board power, clocks, voltage, hot spot and VRAM use. With -Samples,
reads that many times two seconds apart, for catching the link under load.

.EXAMPLE
pwsh -NoProfile -File read-gpuz.ps1

.EXAMPLE
pwsh -NoProfile -File read-gpuz.ps1 -Samples 15
#>
#Requires -Version 7.2
param(
  [ValidateRange(1, 300)] [int] $Samples = 1
)
$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class GpuzWindowText {
  delegate bool EnumProc(IntPtr handle, IntPtr state);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr state);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr state);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr handle, out uint processId);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr handle, uint message, IntPtr wParam, StringBuilder lParam, uint flags, uint timeoutMs, out IntPtr result);
  const uint WM_GETTEXT = 0x000D;
  const uint SMTO_ABORTIFHUNG = 0x0002;
  static string Text(IntPtr handle) {
    var text = new StringBuilder(512);
    IntPtr result;
    SendMessageTimeout(handle, WM_GETTEXT, (IntPtr)text.Capacity, text, SMTO_ABORTIFHUNG, 500, out result);
    return text.ToString().Trim();
  }
  // Child texts of the process's main GPU-Z window, in label-then-value order.
  public static List<string> Read(uint processId) {
    var texts = new List<string>();
    EnumWindows((topLevel, state) => {
      uint ownerId;
      GetWindowThreadProcessId(topLevel, out ownerId);
      if (ownerId != processId || !Text(topLevel).StartsWith("TechPowerUp GPU-Z")) return true;
      EnumChildWindows(topLevel, (child, childState) => { texts.Add(Text(child)); return true; }, IntPtr.Zero);
      return false;
    }, IntPtr.Zero);
    return texts;
  }
}
'@

# GPU Clock appears on both tabs: the Graphics Card tab's is the spec clock, so
# -Last picks the Sensors tab's live reading.
function Get-FieldValue([string[]] $texts, [string] $label, [switch] $Last) {
  $labelIndex = if ($Last) { [array]::LastIndexOf($texts, $label) } else { [array]::IndexOf($texts, $label) }
  if ($labelIndex -ge 0 -and $labelIndex + 1 -lt $texts.Count) { $texts[$labelIndex + 1] }
}

$gpuz = Get-Process -Name 'GPU-Z*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $gpuz) { throw 'GPU-Z is not running. Ask the user to open it; it needs admin.' }

foreach ($sampleNumber in 1..$Samples) {
  if ($sampleNumber -gt 1) { Start-Sleep -Seconds 2 }
  $texts = [string[]] [GpuzWindowText]::Read([uint32] $gpuz.Id)
  if (-not $texts) { throw 'GPU-Z main window not found.' }
  [pscustomobject] @{
    Time = Get-Date -Format 'HH:mm:ss'
    Card = Get-FieldValue $texts 'Name'
    BusInterface = Get-FieldValue $texts 'Bus Interface'
    ResizableBar = Get-FieldValue $texts 'Resizable BAR'
    DriverVersion = Get-FieldValue $texts 'Driver Version'
    GpuLoad = Get-FieldValue $texts 'GPU Load'
    BoardPowerDraw = Get-FieldValue $texts 'Board Power Draw'
    GpuClock = Get-FieldValue $texts 'GPU Clock' -Last
    MemoryClock = Get-FieldValue $texts 'Memory Clock'
    GpuVoltage = Get-FieldValue $texts 'GPU Voltage'
    HotSpot = Get-FieldValue $texts 'GPU Temperature (Hot Spot)'
    MemoryControllerLoad = Get-FieldValue $texts 'Memory Controller Load'
    VramDedicated = Get-FieldValue $texts 'Memory Used (Dedicated)'
    VramDynamic = Get-FieldValue $texts 'Memory Used (Dynamic)'
  }
}
