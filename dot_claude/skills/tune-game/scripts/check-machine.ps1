<#
.SYNOPSIS
Compares this machine's game-relevant settings with machine-state.json and, with
-Apply, fixes the drift it can fix unelevated.

.DESCRIPTION
Checks the Adrenalin global Graphics settings for each GPU and its Preferences,
per-game GPU preferences, HKCU registry values, startup entries that should be
absent, power-plan values, the Motion Assistant default profile, the processes
and logon tasks that must exist, and the AMD driver version.

Rows that aren't ok print one per line; a fixed row shows the value it had.
Each row's Status is:
- ok: matches.
- drift: differs, and -Apply can fix it (Adrenalin, GPU preferences, HKCU
  values, startup entries).
- fixed: differed and -Apply fixed it.
- manual: differs and needs the user, usually because it needs admin (power
  plan, Motion Assistant, RTSS, drivers). The Note says what to do.
- skipped: couldn't be checked, such as Adrenalin with its window closed or a
  game that isn't installed.

Exits 1 when any row is drift or manual.

.EXAMPLE
pwsh -NoProfile -File check-machine.ps1

.EXAMPLE
pwsh -NoProfile -File check-machine.ps1 -Apply
#>
#Requires -Version 7.2
param(
  [switch] $Apply,
  [string] $StatePath = (Join-Path $PSScriptRoot '..\machine-state.json')
)
$ErrorActionPreference = 'Stop'

$desiredState = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
$adrenalinScript = Join-Path $PSScriptRoot 'adrenalin.ps1'
$gpuPreferenceScript = Join-Path $PSScriptRoot 'set-gpu-preference.ps1'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
  param([string] $Area, [string] $Item, $Expected, $Actual, [string] $Status, [string] $Note = '')
  $results.Add([pscustomobject] @{ Area = $Area; Item = $Item; Expected = "$Expected"; Actual = "$Actual"; Status = $Status; Note = $Note })
}

function Get-StatusFor([bool] $isMatch, [string] $fixableStatus) {
  if ($isMatch) { 'ok' } else { $fixableStatus }
}

# Adrenalin labels carry a trademark sign, and the child process's output encoding can mangle
# it, so names compare as printable ASCII and match by -like with wildcards.
function ConvertTo-PlainName([string] $label) {
  (($label -replace '[^\x20-\x7E]', '') -replace '\s+', ' ').Trim()
}

function ConvertTo-NamePattern([string] $plainName) {
  $plainName -replace ' ', '*'
}

function Invoke-Adrenalin([string[]] $arguments) {
  $output = & pwsh -NoProfile -File $adrenalinScript @arguments 2>&1
  [pscustomobject] @{ Succeeded = $LASTEXITCODE -eq 0; Output = @($output | ForEach-Object { "$_" }) }
}

# Parses a Dump into toggle and dropdown values keyed by plain name. A
# dropdown's value is the Text element printed right after its button.
function Read-AdrenalinPage([string[]] $navigation) {
  $dump = Invoke-Adrenalin ($navigation + @('-Action', 'Dump'))
  if (-not $dump.Succeeded) { throw ($dump.Output -join "`n") }
  $toggles = @{}
  $choices = @{}
  for ($lineIndex = 0; $lineIndex -lt $dump.Output.Count; $lineIndex++) {
    $line = $dump.Output[$lineIndex]
    if ($line -match '^\s*\d+ CheckBox \| (?<name>.+) toggle=(?<state>On|Off)$') {
      $toggles[(ConvertTo-PlainName $Matches.name)] = $Matches.state
    } elseif ($line -match '^\s*\d+ Button \| (?<name>.+) dropdown$' -and $lineIndex + 1 -lt $dump.Output.Count) {
      $dropdownName = ConvertTo-PlainName $Matches.name
      if ($dump.Output[$lineIndex + 1] -match '^\s*\d+ Text \| (?<value>.+)$') {
        $choices[$dropdownName] = $Matches.value
      }
    }
  }
  [pscustomobject] @{ Toggles = $toggles; Choices = $choices }
}

function Test-AdrenalinPage {
  param([string] $Area, [string[]] $Navigation, $Desired)
  $page = Read-AdrenalinPage $Navigation
  foreach ($toggle in $Desired.toggles.PSObject.Properties) {
    $actual = $page.Toggles[$toggle.Name]
    if ($null -eq $actual) { Add-Result $Area $toggle.Name $toggle.Value '(not found)' 'manual' 'The driver renamed or removed it; update machine-state.json.'; continue }
    if ($actual -eq $toggle.Value) { Add-Result $Area $toggle.Name $toggle.Value $actual 'ok'; continue }
    if (-not $Apply) { Add-Result $Area $toggle.Name $toggle.Value $actual 'drift'; continue }
    $change = Invoke-Adrenalin ($Navigation + @('-Action', 'SetToggle', '-Name', (ConvertTo-NamePattern $toggle.Name), '-Value', $toggle.Value))
    if ($change.Succeeded) { Add-Result $Area $toggle.Name $toggle.Value $actual 'fixed' }
    else { Add-Result $Area $toggle.Name $toggle.Value $actual 'drift' ($change.Output -join ' ') }
  }
  foreach ($choice in $Desired.choices.PSObject.Properties) {
    $actual = $page.Choices[$choice.Name]
    if ($null -eq $actual) { Add-Result $Area $choice.Name $choice.Value '(not found)' 'manual' 'The driver renamed or removed it; update machine-state.json.'; continue }
    if ($actual -eq $choice.Value) { Add-Result $Area $choice.Name $choice.Value $actual 'ok'; continue }
    if (-not $Apply) { Add-Result $Area $choice.Name $choice.Value $actual 'drift'; continue }
    $change = Invoke-Adrenalin ($Navigation + @('-Action', 'Choose', '-Name', $choice.Name, '-Value', $choice.Value))
    if ($change.Succeeded) { Add-Result $Area $choice.Name $choice.Value $actual 'fixed' }
    else { Add-Result $Area $choice.Name $choice.Value $actual 'drift' ($change.Output -join ' ') }
  }
}

$adrenalinWindowOpen = [bool] (Get-Process RadeonSoftware -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0)
if ($adrenalinWindowOpen) {
  foreach ($gpu in $desiredState.adrenalin.graphics.PSObject.Properties) {
    Test-AdrenalinPage -Area "Adrenalin GPU $($gpu.Name)" -Navigation @('-Graphics', '-Gpu', $gpu.Name) -Desired $gpu.Value
  }

  # Preferences has no navigation switch; opening it leaves the window there
  # for the reads and changes that follow.
  foreach ($button in 'Settings', 'Preferences') {
    [void] (Invoke-Adrenalin @('-Action', 'Click', '-Name', $button))
    Start-Sleep -Milliseconds 500
  }
  Test-AdrenalinPage -Area 'Adrenalin Preferences' -Navigation @() -Desired $desiredState.adrenalin.preferences
} else {
  Add-Result 'Adrenalin' '(all)' '' '' 'skipped' 'Open AMD Software from the tray and rerun.'
}

$preferencesKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$preferencesRegistryKey = Get-Item -LiteralPath $preferencesKey -ErrorAction SilentlyContinue
foreach ($gamePreference in $desiredState.gpuPreferences.PSObject.Properties) {
  $exePath = $gamePreference.Name
  $exeName = Split-Path $exePath -Leaf
  if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { Add-Result 'GPU preference' $exeName $gamePreference.Value '(not installed)' 'skipped'; continue }
  $storedValue = if ($preferencesRegistryKey) { "$($preferencesRegistryKey.GetValue($exePath))" } else { '' }
  $actual = if ($storedValue -match 'GpuPreference=(\d)') { [int] $Matches[1] } else { '(unset)' }
  if ($actual -eq $gamePreference.Value) { Add-Result 'GPU preference' $exeName $gamePreference.Value $actual 'ok'; continue }
  if (-not $Apply) { Add-Result 'GPU preference' $exeName $gamePreference.Value $actual 'drift'; continue }
  & pwsh -NoProfile -File $gpuPreferenceScript -ExePath $exePath -Preference $gamePreference.Value | Out-Null
  Add-Result 'GPU preference' $exeName $gamePreference.Value $actual 'fixed'
}

foreach ($registryValue in $desiredState.registry) {
  $item = "$($registryValue.path)\$($registryValue.name)"
  $actual = (Get-ItemProperty -LiteralPath $registryValue.path -Name $registryValue.name -ErrorAction SilentlyContinue).($registryValue.name)
  $displayedActual = if ($null -eq $actual) { '(unset)' } else { $actual }
  $isUserHive = $registryValue.path -like 'HKCU:*'
  if ($actual -eq $registryValue.value) { Add-Result 'Registry' $item $registryValue.value $actual 'ok'; continue }
  if (-not $isUserHive) { Add-Result 'Registry' $item $registryValue.value $displayedActual 'manual' 'Needs admin.'; continue }
  if (-not $Apply) { Add-Result 'Registry' $item $registryValue.value $displayedActual 'drift'; continue }
  if (-not (Test-Path -LiteralPath $registryValue.path)) { New-Item -Path $registryValue.path -Force | Out-Null }
  Set-ItemProperty -LiteralPath $registryValue.path -Name $registryValue.name -Value $registryValue.value -Type DWord
  Add-Result 'Registry' $item $registryValue.value $displayedActual 'fixed'
}

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$startupNames = @((Get-Item -LiteralPath $runKey).GetValueNames())
foreach ($entryName in $desiredState.absentStartupEntries) {
  if ($entryName -notin $startupNames) { Add-Result 'Startup' $entryName '(absent)' '(absent)' 'ok'; continue }
  if (-not $Apply) { Add-Result 'Startup' $entryName '(absent)' (Get-Item -LiteralPath $runKey).GetValue($entryName) 'drift'; continue }
  $startupCommand = (Get-Item -LiteralPath $runKey).GetValue($entryName)
  Remove-ItemProperty -LiteralPath $runKey -Name $entryName
  Add-Result 'Startup' $entryName '(absent)' $startupCommand 'fixed'
}

# Hidden power settings print nothing under /query, so read them with /qh.
foreach ($powerSetting in $desiredState.powerSettings) {
  $query = powercfg /qh SCHEME_CURRENT $powerSetting.subgroup $powerSetting.setting
  $acIndex = ($query | Select-String 'Current AC Power Setting Index: 0x([0-9a-f]+)').Matches.Groups[1].Value
  $dcIndex = ($query | Select-String 'Current DC Power Setting Index: 0x([0-9a-f]+)').Matches.Groups[1].Value
  $actual = '{0}/{1}' -f [Convert]::ToInt32($acIndex, 16), [Convert]::ToInt32($dcIndex, 16)
  $expected = '{0}/{1}' -f $powerSetting.ac, $powerSetting.dc
  $note = switch ($powerSetting.subgroup) {
    'SUB_PROCESSOR' { "Motion Assistant's core dropdown writes it: set Prefer P-Cores and click Apply." }
    'SUB_SLEEP' { "powercfg /change standby-timeout-ac $($powerSetting.ac / 60) (and -dc); the Claude app keeps the machine awake while a session works." }
    default { 'Needs admin: powercfg /setacvalueindex and /setdcvalueindex.' }
  }
  Add-Result 'Power (AC/DC)' $powerSetting.setting $expected $actual (Get-StatusFor ($actual -eq $expected) 'manual') ($actual -eq $expected ? '' : $note)
}

$motionAssistant = $desiredState.motionAssistant
if (Test-Path -LiteralPath $motionAssistant.profile) {
  $profileValues = @{}
  foreach ($profileLine in Get-Content -LiteralPath $motionAssistant.profile) {
    if ($profileLine -match '^(?<key>[^=\[]+)=(?<value>.*)$') { $profileValues[$Matches.key] = $Matches.value }
  }
  foreach ($profileKey in $motionAssistant.keys.PSObject.Properties) {
    $actual = $profileValues[$profileKey.Name] ?? '(unset)'
    Add-Result 'Motion Assistant' $profileKey.Name $profileKey.Value $actual (Get-StatusFor ($actual -eq $profileKey.Value) 'manual') ($actual -eq $profileKey.Value ? '' : 'Set it in Motion Assistant (admin).')
  }
  $minimumTdp, $maximumTdp = $motionAssistant.acTdpRange
  $acTdp = $profileValues['ACTDP']
  $tdpInRange = $acTdp -match '^\d+$' -and [int] $acTdp -ge $minimumTdp -and [int] $acTdp -le $maximumTdp
  Add-Result 'Motion Assistant' 'ACTDP' "$minimumTdp-$maximumTdp" ($acTdp ?? '(unset)') (Get-StatusFor $tdpInRange 'manual') ($tdpInRange ? '' : 'Set the AC TDP in Motion Assistant (admin).')
} else {
  Add-Result 'Motion Assistant' 'profile' $motionAssistant.profile '(missing)' 'manual' 'Motion Assistant is not installed where expected.'
}

foreach ($processName in $desiredState.runningProcesses) {
  $isRunning = [bool] (Get-Process -Name $processName -ErrorAction SilentlyContinue)
  Add-Result 'Process' $processName 'running' ($isRunning ? 'running' : 'stopped') (Get-StatusFor $isRunning 'manual') ($isRunning ? '' : 'The user starts it (admin), or it starts at the next logon.')
}

foreach ($taskName in $desiredState.scheduledTasks) {
  $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  $taskState = if ($task) { "$($task.State)" } else { '(missing)' }
  $taskHealthy = $task -and $task.State -ne 'Disabled'
  Add-Result 'Logon task' $taskName 'Ready' $taskState (Get-StatusFor $taskHealthy 'manual') ($taskHealthy ? '' : 'See machine.md for how the task is created.')
}

foreach ($adapter in Get-CimInstance Win32_VideoController | Where-Object Name -like 'AMD*') {
  $driverMatches = $adapter.DriverVersion -eq $desiredState.amdDriverVersion
  Add-Result 'Driver' $adapter.Name $desiredState.amdDriverVersion $adapter.DriverVersion (Get-StatusFor $driverMatches 'manual') ($driverMatches ? '' : 'Windows Update may have replaced it; reinstall Adrenalin, or update machine-state.json after an intended upgrade.')
}

# The table would wrap at a terminal's width, so print one line per row that
# needs attention.
foreach ($result in $results | Where-Object Status -ne 'ok') {
  $actualLabel = if ($result.Status -eq 'fixed') { 'was' } else { 'actual' }
  $line = '{0,-7} {1} > {2}: expected {3}, {4} {5}' -f $result.Status, $result.Area, $result.Item, $result.Expected, $actualLabel, $result.Actual
  if ($result.Note) { $line += ". $($result.Note)" }
  $line
}
$remaining = @($results | Where-Object Status -in 'drift', 'manual')
$fixedCount = @($results | Where-Object Status -eq 'fixed').Count
"{0} checked: {1} ok, {2} fixed, {3} drift, {4} manual, {5} skipped." -f $results.Count,
  @($results | Where-Object Status -eq 'ok').Count, $fixedCount,
  @($remaining | Where-Object Status -eq 'drift').Count, @($remaining | Where-Object Status -eq 'manual').Count,
  @($results | Where-Object Status -eq 'skipped').Count
if ($remaining) { exit 1 }
