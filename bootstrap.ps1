# Bootstrap a fresh Windows machine from this repo.
#
# From a flash drive or a checkout:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
# Or straight from GitHub:
#   irm https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.ps1 | iex
#
# Installs Git + chezmoi via winget, then runs `chezmoi init` + `chezmoi apply`,
# which fires the run_once/run_onchange PowerShell scripts (winget import, mise
# install, Emdash). The macOS-only Nix/Homebrew tree is skipped on Windows via
# .chezmoiignore, so only the shell/editor/Claude config applies here.
#
# Extra args pass through to `chezmoi init`, e.g. layer selection:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 --promptString "layers=personal"
#
# The `irm | iex` form cannot forward args, so for unattended installs preset the
# layer selection via an environment variable instead:
#   $env:DOTFILES_LAYERS = "personal"; irm .../bootstrap.ps1 | iex
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $ChezmoiArgs)

$ErrorActionPreference = 'Stop'
# winget returns non-zero for benign cases (package already installed). Under
# pwsh 7.4+ that would throw with native-command error propagation on, aborting a
# re-run, so keep it off and check $LASTEXITCODE explicitly where it matters.
$PSNativeCommandUseErrorActionPreference = $false
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

# Layer selection: an explicit --promptString wins; otherwise fall back to
# $env:DOTFILES_LAYERS (the only way to pick layers via the `irm | iex` form,
# which cannot forward args). With neither, .chezmoi.toml.tmpl prompts — which
# hangs on a non-interactive host, so fail fast there instead of stalling.
$initArgs = @($ChezmoiArgs)
$hasLayerArg = $initArgs -contains '--promptString'
if (-not $hasLayerArg -and $env:DOTFILES_LAYERS) {
  $initArgs += @('--promptString', "layers=$env:DOTFILES_LAYERS")
  $hasLayerArg = $true
}
if (-not $hasLayerArg -and -not [Environment]::UserInteractive) {
  throw 'No layers selected and no interactive console. Pass --promptString "layers=..." or set $env:DOTFILES_LAYERS.'
}

Write-Host ">> Initializing dotfiles from $repo ..."
& $chezmoi init @initArgs $repo

# init leaves an already-cloned source untouched; pull so a re-run on an existing
# machine applies the latest dotfiles instead of whatever the first clone had.
# chezmoi git runs in the source dir, reusing the git chezmoi already found for
# the clone (git may not be on this session's PATH yet after a fresh install).
& $chezmoi git -- pull --ff-only 2>$null

Write-Host ">> Applying dotfiles..."
& $chezmoi apply

Write-Host ">> Bootstrap complete. Open a new terminal (pwsh or nushell), then use 'apploi' to sync."
