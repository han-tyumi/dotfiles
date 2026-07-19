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
$joinedArgs = $initArgs -join ' '
$hasLayers = $joinedArgs -match 'layers='
if (-not $hasLayers -and $env:DOTFILES_LAYERS) {
  $initArgs += @('--promptString', "layers=$env:DOTFILES_LAYERS")
  $hasLayers = $true
  $joinedArgs = $initArgs -join ' '
}
# .chezmoi.toml.tmpl prompts for both layers AND overlays; Windows has no overlays,
# so preset that prompt too or a non-interactive init stalls on it.
if ($joinedArgs -notmatch 'overlays=') {
  $initArgs += @('--promptString', "overlays=$env:DOTFILES_OVERLAYS")
}
if (-not $hasLayers -and -not [Environment]::UserInteractive) {
  throw 'No layers selected and no interactive console. Pass --promptString "layers=..." or set $env:DOTFILES_LAYERS.'
}

Write-Host ">> Initializing dotfiles from $repo ..."
& $chezmoi init @initArgs $repo

# init leaves an already-cloned source untouched; pull so a re-run on an existing
# machine applies the latest dotfiles instead of whatever the first clone had.
# chezmoi git runs in the source dir, reusing the git chezmoi already found for the
# clone. git writes its fetch summary to stderr, which under 5.1 + $ErrorActionPreference
# 'Stop' surfaces as a terminating error, so swallow it for this best-effort pull.
try { & $chezmoi git -- pull --ff-only 2>&1 | Out-Null } catch { }

# Generate a per-machine SSH key for commit signing (and SSH remotes), mirroring
# bootstrap.sh. Done before apply so the gitconfig signing block (gated on the key
# existing) turns on this first apply. Set $env:DOTFILES_SSH_KEY="none" to skip
# (PowerShell deletes an env var assigned "", so "" can't signal skip). No private
# key material ever leaves the machine.
$keyName = if ($env:DOTFILES_SSH_KEY) { $env:DOTFILES_SSH_KEY } else { 'git_han-tyumi' }
$generateKey = $keyName -ne 'none'
$keyPath = Join-Path $HOME ".ssh\$keyName"
if ($generateKey) {
  $sshDir = Join-Path $HOME '.ssh'
  if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
  if (-not (Test-Path $keyPath)) {
    $sshKeygen = (Get-Command ssh-keygen -ErrorAction SilentlyContinue).Source
    if (-not $sshKeygen) { $sshKeygen = Join-Path $env:ProgramFiles 'Git\usr\bin\ssh-keygen.exe' }
    Write-Host ">> Generating SSH key $keyName ..."
    # Pass the empty passphrase as a literal "" in one argument string: PowerShell
    # 5.1 drops an empty-string array element, so `-N ''` would vanish and ssh-keygen
    # would misparse the rest ("Too many arguments"). Start-Process passes the string
    # verbatim, and CommandLineToArgvW turns "" into an empty arg in any PS version.
    $kgArgs = "-t ed25519 -N `"`" -C `"$keyName@$env:COMPUTERNAME`" -f `"$keyPath`""
    $proc = Start-Process -FilePath $sshKeygen -ArgumentList $kgArgs -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0) { Write-Warning "ssh-keygen exited $($proc.ExitCode); no signing key generated." }
  } else {
    Write-Host ">> SSH key $keyName already exists; skipping."
  }
}

Write-Host ">> Applying dotfiles..."
& $chezmoi apply

# Record the signing key in allowed_signers so `git log --show-signature` verifies
# locally (GitHub's Verified badge needs only the key registered there). Runs after
# apply so the committer email from the applied gitconfig is available.
if ($generateKey -and (Test-Path "$keyPath.pub")) {
  $git = (Get-Command git -ErrorAction SilentlyContinue).Source
  if (-not $git) { $git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe' }
  if (Test-Path $git) {
    $signerEmail = (& $git config --global user.email)
    if ($signerEmail) {
      $gitCfgDir = Join-Path $HOME '.config\git'
      if (-not (Test-Path $gitCfgDir)) { New-Item -ItemType Directory -Path $gitCfgDir | Out-Null }
      $pub = (Get-Content "$keyPath.pub" -Raw).Trim()
      "$signerEmail $pub" | Set-Content -Path (Join-Path $gitCfgDir 'allowed_signers') -Encoding ascii
    }
  }
}

Write-Host ">> Bootstrap complete. Open a new terminal (pwsh or nushell), then use 'apploi' to sync."
if ($generateKey -and (Test-Path "$keyPath.pub")) {
  Write-Host ">> Register this key on GitHub as BOTH an Authentication and a Signing key (https://github.com/settings/keys):"
  Get-Content "$keyPath.pub"
}
Write-Host ">> Then authenticate the GitHub CLI: gh auth login"
