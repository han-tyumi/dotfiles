<#
.SYNOPSIS
Summarizes a PresentMon CSV: frame rate, frame-time percentiles, refreshes the
display had to repeat, and whether the CPU or the GPU held each late frame.

.DESCRIPTION
Reads any of PresentMon's CSV schemas (the 2.x default, --v2_metrics, or
--v1_metrics) for -Process, or for the process with the most frames when
-Process is omitted. The swap chain with the most frames is analyzed together
with every chain that presented before or after it, such as one the game
recreated after a display mode change. Chains presenting at the same time (a
second window) are listed in SwapChains but left out of the totals.

-RefreshHz must match the panel's refresh rate during the capture: a 40 fps run
at the default 60 counts every frame as held.

.EXAMPLE
pwsh -NoProfile -File analyze-frames.ps1 -Path capture.csv -Process witcher3.exe

.EXAMPLE
pwsh -NoProfile -File analyze-frames.ps1 -Path capture.csv -Process witcher3.exe -RefreshHz 40
#>
#Requires -Version 7.2
param(
  [Parameter(Mandatory)] [string] $Path,
  [string] $Process,
  [double] $RefreshHz = 60,
  [double] $MaxHeldPercent = 0.25,
  [int] $WindowSeconds = 10,
  [switch] $AsJson
)
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'

$rows = @(Import-Csv -LiteralPath $Path)
if ($rows.Count -eq 0) { throw "No frames in $Path." }

$columnAliases = [ordered]@{
  FrameTime      = 'MsBetweenPresents', 'FrameTime'
  DisplayedTime  = 'MsBetweenDisplayChange', 'DisplayedTime'
  CpuBusy        = 'MsCPUBusy', 'CPUBusy'
  GpuBusy        = 'MsGPUBusy', 'GPUBusy', 'msGPUActive'
  AnimationError = 'MsAnimationError', 'AnimationError'
  HybridPresent  = 'HybridPresent'
  StartMs        = 'CPUStartTime', 'TimeInMs'
  StartSeconds   = 'TimeInSeconds'
}
$header = $rows[0].PSObject.Properties.Name
$columns = @{}
foreach ($metric in $columnAliases.Keys) {
  $columns[$metric] = $columnAliases[$metric] | Where-Object { $_ -in $header } | Select-Object -First 1
}
if (-not $columns.FrameTime) { throw "Unrecognized PresentMon CSV header: $($header -join ',')" }

# --v2_metrics reports how long each frame stayed on screen, so the frame that
# arrived late is the one after a long DisplayedTime. The other schemas report
# the interval since the previous display change on the late frame itself.
$displayedTimeIsOnScreenTime = $columns.DisplayedTime -eq 'DisplayedTime'

if ($Process) {
  $processName = if ($Process -like '*.exe') { $Process } else { "$Process.exe" }
  $rows = @($rows | Where-Object Application -EQ $processName)
  if ($rows.Count -eq 0) { throw "No frames for $processName in $Path." }
}

$refreshMs = 1000 / $RefreshHz
$heldThresholdMs = $refreshMs * 1.5
$emptyColumn = '(none)'
$frameTimeColumn = $columns.FrameTime
$displayedTimeColumn = $columns.DisplayedTime ?? $emptyColumn
$gpuBusyColumn = $columns.GpuBusy ?? $emptyColumn
$cpuBusyColumn = $columns.CpuBusy ?? $emptyColumn
$animationErrorColumn = $columns.AnimationError ?? $emptyColumn
$hybridPresentColumn = $columns.HybridPresent ?? $emptyColumn
$startMsColumn = $columns.StartMs ?? $emptyColumn
$startSecondsColumn = $columns.StartSeconds ?? $emptyColumn

$chains = foreach ($chainRows in $rows | Group-Object Application, ProcessID, SwapChainAddress) {
  $nextStartMs = 0.0
  $heldFrames = 0
  $chainFrames = @(foreach ($row in $chainRows.Group) {
      # Cells convert with -as [double], which is culture-invariant and yields $null
      # for text such as NA; empty cells are skipped first because they'd convert to 0.
      $cellText = $row.$frameTimeColumn
      $frameTime = if ($cellText) { $cellText -as [double] }
      if ($null -eq $frameTime) { continue }

      # Absolute timestamps are milliseconds since the capture started; without one,
      # the chain's own frame times are summed instead.
      $cellText = $row.$startMsColumn
      $startMs = if ($cellText) { $cellText -as [double] }
      if ($null -eq $startMs) {
        $cellText = $row.$startSecondsColumn
        $startSeconds = if ($cellText) { $cellText -as [double] }
        $startMs = if ($null -ne $startSeconds) { $startSeconds * 1000 } else { $nextStartMs }
      }
      $nextStartMs = $startMs + $frameTime

      $cellText = $row.$displayedTimeColumn
      $displayedTime = if ($cellText) { $cellText -as [double] }
      if ($displayedTime -gt $heldThresholdMs) { $heldFrames++ }
      $cellText = $row.$gpuBusyColumn
      $gpuBusy = if ($cellText) { $cellText -as [double] }
      $cellText = $row.$cpuBusyColumn
      $cpuBusy = if ($cellText) { $cellText -as [double] }
      $cellText = $row.$animationErrorColumn
      $animationError = if ($cellText) { $cellText -as [double] }
      [pscustomobject] @{
        StartMs          = $startMs
        FrameMs          = $frameTime
        DisplayedMs      = $displayedTime
        GpuBusyMs        = $gpuBusy
        CpuBusyMs        = $cpuBusy
        AnimationErrorMs = $animationError
        PresentMode      = "$($row.PresentMode)"
        HybridPresent    = $row.$hybridPresentColumn -eq '1'
      }
    })
  if ($chainFrames.Count -eq 0) { continue }
  [pscustomobject] @{
    Application = $chainRows.Group[0].Application
    SwapChain   = $chainRows.Group[0].SwapChainAddress
    Frames      = $chainFrames
    StartMs     = $chainFrames[0].StartMs
    EndMs       = $nextStartMs
    HeldFrames  = $heldFrames
    Analyzed    = $false
  }
}
$chains = @($chains | Sort-Object { $_.Frames.Count } -Descending)
if ($chains.Count -eq 0) { throw "No frame times in $Path." }
$application = $chains[0].Application

# Chains that hand over within a second of each other are one session, not two
# windows presenting at once.
$overlapToleranceMs = 1000
$analyzedChains = [System.Collections.Generic.List[object]]::new()
foreach ($chain in $chains | Where-Object Application -EQ $application) {
  $overlappingChains = $analyzedChains.Where({
      [math]::Min($chain.EndMs, $_.EndMs) - [math]::Max($chain.StartMs, $_.StartMs) -gt $overlapToleranceMs
    })
  if ($overlappingChains.Count -gt 0) { continue }
  $chain.Analyzed = $true
  $analyzedChains.Add($chain)
}

function Get-Percentile([double[]] $sortedValues, [double] $percentile) {
  if ($sortedValues.Count -eq 0) { return $null }
  $rank = [math]::Ceiling($percentile / 100 * $sortedValues.Count) - 1
  return $sortedValues[[math]::Max(0, [math]::Min($rank, $sortedValues.Count - 1))]
}

function ConvertTo-SortedArray([double[]] $values) {
  [array]::Sort($values)
  return , $values
}

function Format-Elapsed([double] $elapsedMs) {
  $elapsed = [timespan]::FromMilliseconds($elapsedMs)
  '{0}:{1:00}' -f [int][math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
}

$windowMs = $WindowSeconds * 1000
$windows = @{}
$heldIntervals = [System.Collections.Generic.List[double]]::new()
$heldBy = @{ Cpu = 0; Gpu = 0 }
$frameTimeSpikes = 0
$hybridPresents = 0
$presentModes = @{}

foreach ($chain in $analyzedChains) {
  $chainFrames = $chain.Frames
  for ($frameIndex = 0; $frameIndex -lt $chainFrames.Count; $frameIndex++) {
    $frame = $chainFrames[$frameIndex]
    $presentModes[$frame.PresentMode] = 1 + [int] $presentModes[$frame.PresentMode]
    if ($frame.HybridPresent) { $hybridPresents++ }

    $windowIndex = [int] [math]::Floor($frame.StartMs / $windowMs)
    $window = $windows[$windowIndex]
    if (-not $window) {
      $window = [pscustomobject] @{ StartMs = $windowIndex * $windowMs; Frames = 0; FrameMs = 0.0; HeldFrames = 0; WorstFrameMs = 0.0 }
      $windows[$windowIndex] = $window
    }
    $window.Frames++
    $window.FrameMs += $frame.FrameMs
    $window.WorstFrameMs = [math]::Max($window.WorstFrameMs, $frame.FrameMs)

    # A long present interval displayed on time still shows as uneven motion
    # (PresentMon's animation error), but it isn't a repeated refresh.
    if ($frame.FrameMs -gt $heldThresholdMs) { $frameTimeSpikes++ }

    if ($frame.DisplayedMs -gt $heldThresholdMs) {
      $window.HeldFrames++
      $heldIntervals.Add($frame.DisplayedMs)

      # The refresh was repeated because the next frame arrived late: GPU-limited
      # when its GPU work alone nearly filled a refresh, otherwise its CPU work
      # (game thread, driver, limiter) started too late.
      $lateFrame = if (-not $displayedTimeIsOnScreenTime) { $frame } elseif ($frameIndex + 1 -lt $chainFrames.Count) { $chainFrames[$frameIndex + 1] }
      if ($null -ne $lateFrame -and $null -ne $lateFrame.GpuBusyMs) {
        if ($lateFrame.GpuBusyMs -ge $refreshMs * 0.9) { $heldBy.Gpu++ } else { $heldBy.Cpu++ }
      }
    }
  }
}

$analyzedFrames = @(foreach ($chain in $analyzedChains) { $chain.Frames })
$sortedFrameTimes = ConvertTo-SortedArray @($analyzedFrames.FrameMs)
$sortedDisplayedTimes = ConvertTo-SortedArray @($analyzedFrames.Where({ $_.DisplayedMs -gt 0 }).DisplayedMs)
$sortedGpuBusy = ConvertTo-SortedArray @($analyzedFrames.Where({ $null -ne $_.GpuBusyMs }).GpuBusyMs)
$sortedCpuBusy = ConvertTo-SortedArray @($analyzedFrames.Where({ $null -ne $_.CpuBusyMs }).CpuBusyMs)
$sortedAnimationErrors = ConvertTo-SortedArray @(foreach ($frame in $analyzedFrames) {
    if ($null -ne $frame.AnimationErrorMs) { [math]::Abs($frame.AnimationErrorMs) }
  })
$captureMs = [System.Linq.Enumerable]::Sum($sortedFrameTimes)
$droppedFrames = $sortedFrameTimes.Count - $sortedDisplayedTimes.Count

# At a fixed refresh rate a displayed interval of N refreshes means the previous
# frame was shown N times, so every interval beyond one refresh is a visible hitch.
$repeatedRefreshes = ($heldIntervals | ForEach-Object { [math]::Round($_ / $refreshMs) - 1 } | Measure-Object -Sum).Sum
$heldPercent = if ($sortedDisplayedTimes.Count) { 100 * $heldIntervals.Count / $sortedDisplayedTimes.Count } else { $null }
$p99FrameTime = Get-Percentile $sortedFrameTimes 99
$p999FrameTime = Get-Percentile $sortedFrameTimes 99.9
$medianFrameTime = Get-Percentile $sortedFrameTimes 50
$medianDisplayedTime = Get-Percentile $sortedDisplayedTimes 50

if ($null -ne $medianDisplayedTime -and [math]::Abs($medianDisplayedTime - $refreshMs) -gt $refreshMs * 0.1) {
  Write-Warning ('Frames stayed on screen {0:N1} ms at the median, but -RefreshHz {1} expects {2:N1} ms. Held-frame counts are only right when -RefreshHz matches the panel.' -f $medianDisplayedTime, $RefreshHz, $refreshMs)
}

$summary = [ordered]@{
  Application           = $application
  SwapChains            = @($chains | Where-Object Application -EQ $application | ForEach-Object {
      '{0}: {1} frames, {2} held, {3}-{4}{5}' -f $_.SwapChain, $_.Frames.Count, $_.HeldFrames, (Format-Elapsed $_.StartMs), (Format-Elapsed $_.EndMs), $(if (-not $_.Analyzed) { ', concurrent, excluded' })
    })
  PresentMode           = ($presentModes.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
  Frames                = $sortedFrameTimes.Count
  CaptureSeconds        = [math]::Round($captureMs / 1000, 1)
  AverageFps            = [math]::Round($sortedFrameTimes.Count * 1000 / $captureMs, 1)
  MedianFrameMs         = [math]::Round($medianFrameTime, 2)
  P99FrameMs            = [math]::Round($p99FrameTime, 2)
  P999FrameMs           = [math]::Round($p999FrameTime, 2)
  OnePercentLowFps      = [math]::Round(1000 / $p99FrameTime, 1)
  PointOnePercentLowFps = [math]::Round(1000 / $p999FrameTime, 1)
  DroppedFrames         = $droppedFrames
  HeldFrames            = $heldIntervals.Count
  HeldPercent           = if ($null -ne $heldPercent) { [math]::Round($heldPercent, 2) }
  RepeatedRefreshes     = [int] $repeatedRefreshes
  HeldGpuLimited        = $heldBy.Gpu
  HeldCpuLimited        = $heldBy.Cpu
  FrameTimeSpikes       = $frameTimeSpikes
  P99AnimationErrorMs   = if ($sortedAnimationErrors.Count) { [math]::Round((Get-Percentile $sortedAnimationErrors 99), 2) }
  P99DisplayedMs        = if ($sortedDisplayedTimes.Count) { [math]::Round((Get-Percentile $sortedDisplayedTimes 99), 2) }
  MedianGpuBusyMs       = if ($sortedGpuBusy.Count) { [math]::Round((Get-Percentile $sortedGpuBusy 50), 2) }
  P95GpuBusyMs          = if ($sortedGpuBusy.Count) { [math]::Round((Get-Percentile $sortedGpuBusy 95), 2) }
  MedianCpuBusyMs       = if ($sortedCpuBusy.Count) { [math]::Round((Get-Percentile $sortedCpuBusy 50), 2) }
  P95CpuBusyMs          = if ($sortedCpuBusy.Count) { [math]::Round((Get-Percentile $sortedCpuBusy 95), 2) }
  HybridPresentFrames   = if ($columns.HybridPresent) { $hybridPresents }
  RefreshHz             = $RefreshHz

  # Capped at the refresh rate: CPU busy then includes the game's limiter sleep,
  # so only GPU headroom is meaningful; diagnose bottlenecks from an uncapped run.
  LooksCapped           = [math]::Abs($medianFrameTime - $refreshMs) -lt $refreshMs * 0.05
  Steady                = $null -ne $heldPercent -and $heldPercent -le $MaxHeldPercent -and $droppedFrames -le $sortedFrameTimes.Count * 0.01

  # The worst stretches by time since the capture started, to match against what
  # was on screen then.
  WorstWindows          = @($windows.Values | Where-Object HeldFrames -GT 0 |
      Sort-Object @{ Expression = 'HeldFrames'; Descending = $true }, @{ Expression = 'WorstFrameMs'; Descending = $true } |
      Select-Object -First 5 | ForEach-Object {
        '{0}-{1}: {2} held, {3:N1} fps, worst {4:N1} ms' -f (Format-Elapsed $_.StartMs), (Format-Elapsed ($_.StartMs + $windowMs)), $_.HeldFrames, ($_.Frames * 1000 / $_.FrameMs), $_.WorstFrameMs
      })
}

if ($AsJson) {
  $summary | ConvertTo-Json -Compress
} else {
  $summary.SwapChains = $summary.SwapChains -join "`n"
  $summary.WorstWindows = $summary.WorstWindows -join "`n"
  [pscustomobject] $summary | Format-List
}
