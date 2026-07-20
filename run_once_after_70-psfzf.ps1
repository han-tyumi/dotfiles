# Install PSFzf, the PowerShell fzf integration (Ctrl+T files, Ctrl+R history).
# fzf itself comes from the winget manifest. PSFzf is imported by the PowerShell 7
# profile, so it must land in pwsh 7's module path, not Windows PowerShell 5.1's —
# and chezmoi runs this script under 5.1. So shell out to pwsh for the install.
# pwsh comes from the winget manifest; if it is not present yet (a first apply,
# before the winget import), fail loud so this re-fires once pwsh exists.
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
if (-not (Test-Path $pwsh)) {
  Write-Warning 'pwsh (PowerShell 7) not found yet; will retry after it is installed.'
  exit 1
}

$install = @'
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if (-not (Get-Module -ListAvailable -Name PSFzf)) {
  if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
  }
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
  Install-Module -Name PSFzf -Scope CurrentUser -Force -AllowClobber
}
'@

# Pass the script as an encoded command; Windows PowerShell 5.1 mangles a
# multi-line string handed to another exe via -Command. Capture the child's
# streams (pwsh serializes them as CLIXML when redirected) and surface them only
# if the install fails, so a normal run stays quiet.
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($install))
$childOutput = & $pwsh -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
$modulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\PSFzf'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $modulePath)) {
  Write-Warning "PSFzf install via pwsh did not complete (exit $LASTEXITCODE); will retry on the next apply."
  if ($childOutput) { Write-Warning ($childOutput | Out-String) }
  exit 1
}
Write-Host 'PSFzf ready.'
exit 0
