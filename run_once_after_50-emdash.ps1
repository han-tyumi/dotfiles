# Install Emdash (parallel Claude Code orchestrator). It is not in winget, so
# pull the x64 MSI from the latest GitHub release. run_once: Emdash self-updates
# in-app afterward, so this only needs to install it the first time. On failure
# it exits non-zero so chezmoi re-fires it on the next apply instead of recording
# the run_once as done with nothing installed.
$ErrorActionPreference = 'Stop'
# Progress rendering makes 5.1's Invoke-WebRequest an order of magnitude slower and
# buffers the body in memory; off, the download doesn't look hung.
$ProgressPreference = 'SilentlyContinue'

$url = 'https://github.com/generalaction/emdash/releases/latest/download/emdash-x64.msi'
$msi = Join-Path $env:TEMP 'emdash-x64.msi'
Write-Host ">> Downloading Emdash..."
try {
  Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
  Write-Host ">> Installing Emdash..."
  $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -PassThru
  # 3010/1641 = success, reboot required/initiated (common when Emdash is running);
  # treat them as success so a re-run doesn't fail every apply until reboot.
  if (@(0, 3010, 1641) -notcontains $proc.ExitCode) {
    throw "Emdash MSI exited $($proc.ExitCode)."
  }
  Write-Host ">> Emdash installed."
} catch {
  Write-Warning "Emdash install failed: $($_.Exception.Message). Retrying on the next apply; or install manually from https://emdash.ai/docs/installation"
  exit 1
} finally {
  Remove-Item $msi -ErrorAction SilentlyContinue
}
