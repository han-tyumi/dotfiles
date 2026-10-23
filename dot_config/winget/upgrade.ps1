# Upgrade winget packages for `apploi`, without anyone closing apps first.
#
# - Packages that update themselves are pinned (pins.json, converged by
#   10-winget-packages), so `upgrade --all` leaves them alone. Unknown-version
#   packages are skipped too: those are launchers and runtimes that report no
#   version and would otherwise be reinstalled on every run.
# - A portable package whose exe or DLL is running (mise behind a long-lived MCP
#   server, a tray app) cannot be replaced in place, but Windows does allow a
#   running image to be moved. Locked files of packages with an upgrade pending
#   are moved into a stash first, then moved back if the upgrade failed to
#   replace them; the stash is emptied on a later run once nothing holds them.
# - Git for Windows refuses to upgrade while any Git Bash runs, and an agent
#   session almost always has one. /SKIPIFINUSE turns that refusal into a clean
#   skip, so the upgrade lands on the first run with no Git Bash open.
# - WSL needs elevation that a silent winget upgrade lacks; `wsl --update`
#   prompts for it.
# - Some winget builds report a portable's command alias as added without
#   creating the link, which takes the command off PATH; missing links are
#   recreated at the end.
# - Installers that append to the User PATH through .NET rewrite it as REG_SZ,
#   which leaves its %VAR% entries (winget's WindowsApps alias dir, mise's shims)
#   unexpanded and so off PATH in every new process. The value kind is restored
#   first, and winget is called by its full alias path so a broken PATH cannot
#   stop this run.
$environmentKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$userPath = [string]$environmentKey.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
if ($userPath.Contains('%') -and $environmentKey.GetValueKind('Path') -ne [Microsoft.Win32.RegistryValueKind]::ExpandString) {
  $environmentKey.SetValue('Path', $userPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)
  Write-Host 'apploi: restored the User PATH to REG_EXPAND_SZ so its %VAR% entries expand again (new shells pick it up)' -ForegroundColor Yellow
}
$environmentKey.Close()

$winget = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
$commonArgs = @('--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
$packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
$linkDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
$stashDir = Join-Path $env:TEMP 'winget-inuse'
$sourceSuffix = '_Microsoft.Winget.Source_8wekyb3d8bbwe'

function Test-FileLocked {
  param([string] $Path)
  try {
    [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None').Close()
    return $false
  } catch {
    return $true
  }
}

function Test-UpgradeListed {
  param([string] $UpgradeList, [string] $PackageId)
  return $UpgradeList -match ('(?m)\s' + [regex]::Escape($PackageId) + '\s')
}

if (Test-Path $stashDir) {
  Get-ChildItem $stashDir -File | Remove-Item -ErrorAction SilentlyContinue
} else {
  New-Item -ItemType Directory -Path $stashDir | Out-Null
}

$upgradeList = & $winget upgrade --include-pinned --accept-source-agreements --disable-interactivity | Out-String

$stashedFiles = @()
Get-ChildItem $packageRoot -Directory -Filter "*$sourceSuffix" | ForEach-Object {
  $packageId = $_.Name.Substring(0, $_.Name.Length - $sourceSuffix.Length)
  if (-not (Test-UpgradeListed $upgradeList $packageId)) { return }
  Get-ChildItem $_.FullName -Recurse -File -Include *.exe, *.dll |
    Where-Object { Test-FileLocked $_.FullName } |
    ForEach-Object {
      $stashedPath = Join-Path $stashDir ([guid]::NewGuid().ToString() + '-' + $_.Name)
      Move-Item -LiteralPath $_.FullName -Destination $stashedPath -ErrorAction SilentlyContinue
      if ($?) {
        Write-Host "apploi: $packageId is running; moved $($_.Name) aside for the upgrade" -ForegroundColor DarkGray
        $stashedFiles += [pscustomobject]@{ Original = $_.FullName; Stashed = $stashedPath }
      }
    }
}

& $winget upgrade --all --silent @commonArgs

if (Test-UpgradeListed $upgradeList 'Git.Git') {
  $gitBefore = git --version
  & $winget upgrade --id Git.Git --exact --silent --custom '/SKIPIFINUSE' @commonArgs | Out-Null
  if ((git --version) -eq $gitBefore) {
    Write-Host 'apploi: Git upgrade deferred: a Git Bash is running, so it lands on the next run with none open' -ForegroundColor Yellow
  } else {
    Write-Host "apploi: upgraded $(git --version)" -ForegroundColor Cyan
  }
}

if (Test-UpgradeListed $upgradeList 'Microsoft.WSL') {
  Write-Host 'apploi: updating WSL (prompts for elevation)...' -ForegroundColor Cyan
  wsl --update
}

foreach ($stashedFile in $stashedFiles) {
  if (-not (Test-Path -LiteralPath $stashedFile.Original)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $stashedFile.Original) | Out-Null
    Move-Item -LiteralPath $stashedFile.Stashed -Destination $stashedFile.Original
    Write-Warning "Upgrade did not replace $($stashedFile.Original); restored the previous file."
  }
}

$portableCommands = [ordered]@{
  'chezmoi.exe'   = "twpayne.chezmoi$sourceSuffix\chezmoi.exe"
  'claude.exe'    = "Anthropic.ClaudeCode$sourceSuffix\claude.exe"
  'mise.exe'      = "jdx.mise$sourceSuffix\mise\bin\mise.exe"
  'mise-shim.exe' = "jdx.mise$sourceSuffix\mise\bin\mise-shim.exe"
}
foreach ($linkName in $portableCommands.Keys) {
  $linkPath = Join-Path $linkDir $linkName
  $targetPath = Join-Path $packageRoot $portableCommands[$linkName]
  if ((Test-Path -LiteralPath $targetPath) -and -not (Test-Path -LiteralPath $linkPath)) {
    try {
      New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -Force -ErrorAction Stop | Out-Null
      Write-Host "apploi: restored the $linkName link winget dropped" -ForegroundColor DarkGray
    } catch {
      Write-Warning "Could not restore $linkPath (symlinks need Developer Mode or elevation): $($_.Exception.Message)"
    }
  }
}
