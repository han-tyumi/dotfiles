# Install Orca's global skills (orca-cli, computer-use, orchestration), mirroring
# the Mac's orcaSkills activation. `npx skills add` places them under
# ~/.agents/skills with a junction per agent and records provenance in
# ~/.agents/.skill-lock.json, which Orca's in-app updater rewrites, so chezmoi
# never tracks the copies and this only guarantees the first install: the
# existence guard never rewrites a copy the app has since updated. On failure it
# exits non-zero so chezmoi re-fires it on the next apply. Kept PowerShell
# 5.1-safe, like the other provisioners.
if (Test-Path (Join-Path $env:USERPROFILE '.claude\skills\orchestration')) { exit 0 }

# npx resolves through the mise shims (node comes from 20-mise-install), and a
# shim needs mise itself on PATH, which a first apply's session may not have yet.
$env:PATH = (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') + ';' + (Join-Path $env:LOCALAPPDATA 'mise\shims') + ';' + $env:PATH
$npx = (Get-Command npx -ErrorAction SilentlyContinue).Source
if (-not $npx) {
  Write-Warning 'npx not found; Orca skills not installed. Retrying on the next apply.'
  exit 1
}

$null | & $npx --yes skills add https://github.com/stablyai/orca --skill orca-cli --skill computer-use --skill orchestration --global -y
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Orca skills install failed; re-run it by hand or install from Orca's Skills page. Retrying on the next apply."
  exit 1
}
exit 0
