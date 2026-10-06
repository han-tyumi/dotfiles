<#
.SYNOPSIS
Sets the Windows per-app GPU preference for a game executable, the same value
Settings > System > Display > Graphics writes.

.DESCRIPTION
Preference 2 (high performance) selects the RX 9070 XT, 1 (power saving) the
Radeon 890M, 0 lets Windows decide. Other tokens in the value, such as
AppStatus, are kept. Prints the value before and after.

.EXAMPLE
pwsh -NoProfile -File set-gpu-preference.ps1 -ExePath 'D:\SteamLibrary\steamapps\common\The Witcher 3\bin\x64_dx12\witcher3.exe'
#>
#Requires -Version 7.2
param(
  [Parameter(Mandatory)] [string] $ExePath,
  [ValidateSet(0, 1, 2)] [int] $Preference = 2
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) { throw "Executable not found: $ExePath" }
$resolvedExePath = (Resolve-Path -LiteralPath $ExePath).ProviderPath
$preferencesKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
if (-not (Test-Path $preferencesKey)) { New-Item -Path $preferencesKey -Force | Out-Null }


# Value names are full paths, and Get-ItemProperty -Name would read brackets in
# them as wildcards.
$previousValue = (Get-Item -LiteralPath $preferencesKey).GetValue($resolvedExePath)
$tokens = [ordered]@{}
foreach ($token in "$previousValue" -split ';' | Where-Object { $_ -match '=' }) {
  $tokenName, $tokenValue = $token -split '=', 2
  $tokens[$tokenName] = $tokenValue
}
$tokens['GpuPreference'] = "$Preference"
$newValue = ($tokens.Keys | ForEach-Object { "$_=$($tokens[$_]);" }) -join ''

Set-ItemProperty -Path $preferencesKey -Name $resolvedExePath -Value $newValue -Type String
[pscustomobject] @{
  ExePath = $resolvedExePath
  Before  = if ($null -ne $previousValue) { $previousValue } else { '(unset)' }
  After   = (Get-Item -LiteralPath $preferencesKey).GetValue($resolvedExePath)
} | Format-List
