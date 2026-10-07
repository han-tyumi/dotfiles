<#
.SYNOPSIS
Logs once a second whether a game's busiest work runs on the Zen 5 or the Zen 5c
cores.

.DESCRIPTION
Waits for the game to start, then writes one CSV row per second until it exits:
the average load on the Zen 5 (logical 0-7) and Zen 5c (8-23) CPUs, the three
busiest logical CPUs as index=percent, whether the busiest one is a Zen 5 CPU,
and the game's two busiest threads as a percentage of one core. A top thread
near 100% while the busiest CPU is 8 or above means the main thread is on a
Zen 5c core. On exit it prints the share of seconds the busiest CPU was Zen 5.
Runs unelevated; start it in the background next to a session capture.

.EXAMPLE
pwsh -NoProfile -File watch-cores.ps1 -Process witcher3.exe -Label session-cores
#>
#Requires -Version 7.2
param(
  [Parameter(Mandatory)] [string] $Process,
  [string] $Label = 'cores',
  [string] $OutputDirectory = (Join-Path $env:LOCALAPPDATA 'tune-game\captures')
)
$ErrorActionPreference = 'Stop'

# Logical CPUs 0-7 are the four Zen 5 cores (efficiency class 1); 8-23 are the eight Zen 5c cores.
$zen5LogicalCount = 8

$processName = [IO.Path]::GetFileNameWithoutExtension($Process)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputPath = Join-Path $OutputDirectory ('{0}-{1}-{2:yyyyMMdd-HHmmss}.csv' -f $processName, $Label, (Get-Date))
"Logging core placement to $outputPath once $processName runs."

while (-not (Get-Process -Name $processName -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 5 }
$gameProcess = Get-Process -Name $processName | Select-Object -First 1
'Time,Zen5Avg,Zen5cAvg,BusiestLogical,BusiestOnZen5,TopThreadPct,SecondThreadPct' | Set-Content -LiteralPath $outputPath

$secondsLogged = 0
$secondsOnZen5 = 0
$previousThreadMs = @{}
$previousStamp = [Diagnostics.Stopwatch]::GetTimestamp()
Get-Counter -Counter '\Processor(*)\% Processor Time' -SampleInterval 1 -Continuous | ForEach-Object {
  if ($gameProcess.HasExited) {
    if ($secondsLogged -gt 0) {
      '{0} s logged; busiest CPU on Zen 5 in {1:N0}% of them.' -f $secondsLogged, (100 * $secondsOnZen5 / $secondsLogged)
    }
    exit
  }
  $gameProcess.Refresh()
  $nowStamp = [Diagnostics.Stopwatch]::GetTimestamp()
  $elapsedMs = ($nowStamp - $previousStamp) * 1000 / [Diagnostics.Stopwatch]::Frequency
  $previousStamp = $nowStamp

  $currentThreadMs = @{}
  $threadPercents = foreach ($thread in $gameProcess.Threads) {
    # A thread that exits between enumeration and this read throws.
    try { $cpuMs = $thread.TotalProcessorTime.TotalMilliseconds } catch { continue }
    $currentThreadMs[$thread.Id] = $cpuMs
    if ($previousThreadMs.ContainsKey($thread.Id)) { 100 * ($cpuMs - $previousThreadMs[$thread.Id]) / $elapsedMs }
  }
  $previousThreadMs = $currentThreadMs
  $topThreads = @($threadPercents | Sort-Object -Descending | Select-Object -First 2) + @(0, 0)

  $busyByLogical = @{}
  foreach ($counterSample in $_.CounterSamples) {
    if ($counterSample.InstanceName -match '^\d+$') { $busyByLogical[[int] $counterSample.InstanceName] = $counterSample.CookedValue }
  }
  $zen5Average = ($busyByLogical.GetEnumerator() | Where-Object Key -LT $zen5LogicalCount | Measure-Object -Property Value -Average).Average
  $zen5cAverage = ($busyByLogical.GetEnumerator() | Where-Object Key -GE $zen5LogicalCount | Measure-Object -Property Value -Average).Average
  $busiestLogical = @($busyByLogical.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3)
  $busiestDescription = ($busiestLogical | ForEach-Object { '{0}={1:N0}' -f $_.Key, $_.Value }) -join ' '
  $busiestOnZen5 = [int] ($busiestLogical[0].Key -lt $zen5LogicalCount)

  $secondsLogged++
  $secondsOnZen5 += $busiestOnZen5
  '{0:yyyy-MM-dd HH:mm:ss},{1:N0},{2:N0},{3},{4},{5:N0},{6:N0}' -f $_.Timestamp, $zen5Average, $zen5cAverage, $busiestDescription, $busiestOnZen5, $topThreads[0], $topThreads[1] |
    Add-Content -LiteralPath $outputPath
}
