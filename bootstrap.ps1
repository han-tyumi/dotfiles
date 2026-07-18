# Bootstrap a fresh Windows machine from this repo.
#
# From a flash drive or a checkout:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
# Or straight from GitHub:
#   irm https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.ps1 | iex
#
# Installs Git + chezmoi via winget, then runs `chezmoi init --apply`, which
# fires the run_once/run_onchange PowerShell scripts (winget import, mise
# install, Emdash). The macOS-only Nix/Homebrew tree is skipped on Windows via
# .chezmoiignore, so only the shell/editor/Claude config applies here.
#
# Extra args pass through to `chezmoi init`, e.g. layer selection:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 --promptString "layers=personal"
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $ChezmoiArgs)

$ErrorActionPreference = 'Stop'
$repo = 'han-tyumi'

function Test-HasCommand($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

if (-not (Test-HasCommand winget)) {
  throw 'winget (App Installer) is required. Install "App Installer" from the Microsoft Store, then re-run.'
}

# Git backs chezmoi's clone; chezmoi installs and manages everything else. winget
# returns non-zero when a package is already present, which is not an error here.
foreach ($pkg in @('Git.Git', 'twpayne.chezmoi')) {
  Write-Host ">> Ensuring $pkg is installed..."
  winget install --id $pkg --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
}

# winget updates PATH in the registry but not this session, so locate the binary
# directly from winget's link directory if it isn't resolvable yet.
$chezmoi = (Get-Command chezmoi -ErrorAction SilentlyContinue).Source
if (-not $chezmoi) { $chezmoi = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\chezmoi.exe' }
if (-not (Test-Path $chezmoi)) {
  throw 'chezmoi not found after install. Open a new terminal and run: chezmoi init --apply han-tyumi'
}

Write-Host ">> Initializing dotfiles from $repo ..."
& $chezmoi init --apply @ChezmoiArgs $repo

Write-Host ">> Bootstrap complete. Open a new terminal, then use 'apploi' to sync."
