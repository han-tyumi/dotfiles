# Install Emdash (parallel Claude Code orchestrator). It is not in winget, so
# pull the x64 MSI from the latest GitHub release. run_once: Emdash self-updates
# in-app afterward, so this only needs to install it the first time.
$ErrorActionPreference = 'Stop'

$url = 'https://github.com/generalaction/emdash/releases/latest/download/emdash-x64.msi'
$msi = Join-Path $env:TEMP 'emdash-x64.msi'
Write-Host ">> Downloading Emdash..."
try {
  Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
  Write-Host ">> Installing Emdash..."
  $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -PassThru
  if ($proc.ExitCode -eq 0) {
    Write-Host ">> Emdash installed."
  } else {
    Write-Warning "Emdash MSI exited $($proc.ExitCode); install manually from https://emdash.ai/docs/installation"
  }
} catch {
  Write-Warning "Emdash install failed: $($_.Exception.Message). Install manually from https://emdash.ai/docs/installation"
} finally {
  Remove-Item $msi -ErrorAction SilentlyContinue
}
