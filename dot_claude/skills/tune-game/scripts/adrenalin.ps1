<#
.SYNOPSIS
Reads and changes AMD Adrenalin settings through its window's accessibility tree.

.DESCRIPTION
Adrenalin's Qt UI runs unelevated and exposes named buttons, checkboxes and
dropdowns to UI Automation, so its settings can be read and set without
clicking. The window must be open (not only the tray icon).

-Game opens that game's profile under Gaming > Games first; -Graphics opens the
global Gaming > Graphics page instead. Then:
- Dump (default) lists named elements with their index, type and state:
  toggle=On/Off for checkboxes, and the label after a dropdown is its value.
  Offscreen elements are included; actions reach them without scrolling.
- SetToggle sets a checkbox (-Name, -Value On or Off) and reads it back.
- Choose opens the dropdown for setting -Name and picks the item -Value.
- Click invokes a button, tab or game tile by -Name.
- SetText sets an edit field such as Search.

When a change opens a confirmation dialog, the script prints the dialog's text
and cancels it, unless -Confirm is passed, in which case it accepts.

-Name is matched with -like, so '*Chill' matches 'Radeon™ Chill'.

.EXAMPLE
pwsh -NoProfile -File adrenalin.ps1 -Game 'Enshrouded'

.EXAMPLE
pwsh -NoProfile -File adrenalin.ps1 -Game 'Enshrouded' -Action SetToggle -Name '*Anti-Lag' -Value On -Confirm

.EXAMPLE
pwsh -NoProfile -File adrenalin.ps1 -Game 'The Witcher 3*' -Action Choose -Name 'Wait for Vertical Refresh' -Value 'Off, unless application specifies'
#>
#Requires -Version 7.2
param(
  [ValidateSet('Dump', 'SetToggle', 'Choose', 'Click', 'SetText')] [string] $Action = 'Dump',
  [string] $Game,
  [switch] $Graphics,
  [string] $Name,
  [string] $Value,
  [switch] $Confirm
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$automationElement = [System.Windows.Automation.AutomationElement]
$controlType = [System.Windows.Automation.ControlType]

$radeon = Get-Process RadeonSoftware -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 | Select-Object -First 1
if (-not $radeon) { throw 'The Adrenalin window is not open. Ask the user to open AMD Software from the tray.' }
$window = $automationElement::FromHandle($radeon.MainWindowHandle)

# FindAll fails with a COM error while a page re-renders, so retry briefly.
function Get-Elements {
  foreach ($attempt in 1..10) {
    try {
      return $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    } catch [System.Runtime.InteropServices.COMException], [System.Management.Automation.MethodInvocationException] {
      Start-Sleep -Milliseconds 300
    }
  }
  throw 'Could not read the Adrenalin window.'
}

function Find-Element([string] $pattern, [System.Windows.Automation.ControlType[]] $types) {
  $matching = @(Get-Elements | Where-Object { $_.Current.Name -like $pattern -and ($types -contains $_.Current.ControlType) })
  if (-not $matching) { throw "No $($types.ProgrammaticName -join '/') named like '$pattern'. Run -Action Dump to see the names." }
  $matching[0]
}

function Wait-ForElement([string] $pattern, [System.Windows.Automation.ControlType[]] $types) {
  foreach ($attempt in 1..20) {
    $found = @(Get-Elements | Where-Object { $_.Current.Name -like $pattern -and ($types -contains $_.Current.ControlType) })
    if ($found) { return $found[0] }
    Start-Sleep -Milliseconds 250
  }
  throw "Timed out waiting for '$pattern'."
}

function Invoke-Element($element) {
  $element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
}

function Get-ToggleState($element) {
  [string] $element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Current.ToggleState
}

# A confirmation dialog is a Window element inside the main window. Prints its
# text, then accepts it with -Confirm or cancels it. Returns whether it accepted.
function Resolve-Dialog {
  Start-Sleep -Milliseconds 500
  $dialog = @(Get-Elements | Where-Object { $_.Current.ControlType -eq $controlType::Window }) | Select-Object -First 1
  if (-not $dialog) { return $true }
  $dialogElements = @($dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition))
  $dialogText = ($dialogElements | Where-Object { $_.Current.ControlType -eq $controlType::Text } | ForEach-Object { $_.Current.Name }) -join ' | '
  $buttons = @($dialogElements | Where-Object { $_.Current.ControlType -eq $controlType::Button -and $_.Current.Name -ne 'close' })
  $cancelButton = $buttons | Where-Object { $_.Current.Name -eq 'Cancel' } | Select-Object -First 1
  $acceptButton = $buttons | Where-Object { $_.Current.Name -ne 'Cancel' } | Select-Object -First 1
  Write-Host "Dialog: $dialogText"
  if ($Confirm -and $acceptButton) {
    Invoke-Element $acceptButton
    Write-Host "Accepted with '$($acceptButton.Current.Name)'."
    Start-Sleep -Milliseconds 500
    return $true
  }
  if ($cancelButton) { Invoke-Element $cancelButton }
  Write-Host 'Cancelled; rerun with -Confirm to accept.'
  return $false
}

function Open-GamingTab([string] $tabName) {
  # A game's page replaces the Games/Graphics tabs, so back out of it first.
  foreach ($attempt in 1..3) {
    $goBack = @(Get-Elements | Where-Object { $_.Current.Name -eq 'Go Back' })
    if (-not $goBack) { break }
    Invoke-Element $goBack[0]
    Start-Sleep -Milliseconds 500
  }
  Invoke-Element (Find-Element 'Gaming' @($controlType::Button))
  Invoke-Element (Wait-ForElement $tabName @($controlType::Button))
  Start-Sleep -Milliseconds 500
}

if ($Game) {
  Open-GamingTab 'Games'
  [void](Wait-ForElement 'Library*' @($controlType::Text))
  $search = Find-Element 'Search' @($controlType::Edit)
  $search.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($Game)
  Invoke-Element (Wait-ForElement $Game @($controlType::Button))
  [void](Wait-ForElement 'Launch Game' @($controlType::Button))
} elseif ($Graphics) {
  Open-GamingTab 'Graphics'
}

switch ($Action) {
  'Dump' {
    $elementIndex = 0
    foreach ($element in Get-Elements) {
      $elementIndex++
      $current = $element.Current
      if (-not $current.Name -or $current.Name.Length -gt 100) { continue }
      $state = ''
      $toggle = $null
      if ($element.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref] $toggle)) { $state = " toggle=$($toggle.Current.ToggleState)" }
      '{0,4} {1} | {2}{3}' -f $elementIndex, $current.ControlType.ProgrammaticName.Replace('ControlType.', ''), $current.Name, $state
    }
  }
  'SetToggle' {
    if ($Value -notin 'On', 'Off') { throw 'SetToggle needs -Value On or Off.' }
    $checkbox = Find-Element $Name @($controlType::CheckBox)
    if ((Get-ToggleState $checkbox) -ne $Value) {
      $checkbox.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle()
      if (-not (Resolve-Dialog)) { exit 1 }
    }
    $checkbox = Find-Element $Name @($controlType::CheckBox)
    "$($checkbox.Current.Name): $(Get-ToggleState $checkbox)"
    if ((Get-ToggleState $checkbox) -ne $Value) { throw "'$Name' did not change to $Value." }
  }
  'Choose' {
    Invoke-Element (Find-Element "$Name dropdown" @($controlType::Button))
    Invoke-Element (Wait-ForElement $Value @($controlType::MenuItem, $controlType::ListItem, $controlType::Button, $controlType::RadioButton))
    if (-not (Resolve-Dialog)) { exit 1 }
    "Chose '$Value' for '$Name'."
  }
  'Click' {
    Invoke-Element (Find-Element $Name @($controlType::Button, $controlType::MenuItem, $controlType::TabItem))
    "Clicked '$Name'."
  }
  'SetText' {
    (Find-Element $Name @($controlType::Edit)).GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($Value)
    "Set '$Name'."
  }
}
