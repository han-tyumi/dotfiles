# Install the Clone Hero Launcher, which installs and updates the game itself and
# then updates itself in place. It isn't in winget, and its download URL is a
# moving tag whose asset is replaced on each release, so a winget manifest would
# fail its hash check after every update. The Inno Setup installer has no per-user
# mode: it needs one elevation prompt and registers machine-wide. It goes under
# %LOCALAPPDATA%\Programs anyway, so the launcher's in-place self-updates can
# write to its own folder without elevating. The download is checked against the
# SHA-256 that clonehero.net publishes beside its link. run_once; on failure it
# exits non-zero so chezmoi re-fires it on the next apply. Kept PowerShell
# 5.1-safe, like the other provisioners.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{91BABC4C-53D3-4791-BFEA-175A28E2E870}_is1'
if (Test-Path $uninstallKey) { exit 0 }

$downloadUrl = 'https://github.com/clonehero-game/releases/releases/download/CloneHeroLauncher/chlauncher-setup.exe'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Clone Hero Launcher'
$setupPath = Join-Path $env:TEMP 'chlauncher-setup.exe'

Write-Host '>> Installing the Clone Hero Launcher (approve the elevation prompt)...'
try {
  $launcherPage = (Invoke-WebRequest -Uri 'https://clonehero.net/launcher/' -UseBasicParsing).Content
  $hashMatch = [regex]::Match($launcherPage, 'release__download--win64[\s\S]*?SHA-256:\s*([0-9a-fA-F]{64})')
  if (-not $hashMatch.Success) { throw 'clonehero.net no longer lists a SHA-256 for the Windows launcher.' }

  Invoke-WebRequest -Uri $downloadUrl -OutFile $setupPath -UseBasicParsing
  $actualHash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash
  if ($actualHash -ne $hashMatch.Groups[1].Value.ToUpperInvariant()) {
    throw "chlauncher-setup.exe hashes to $actualHash, not the SHA-256 clonehero.net lists."
  }

  $installer = Start-Process -FilePath $setupPath -Verb RunAs -Wait -PassThru -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installDir`""
  )
  if ($installer.ExitCode -ne 0) { throw "the installer exited with code $($installer.ExitCode)." }
  Write-Host ">> Installed the Clone Hero Launcher to $installDir."
} catch {
  Write-Warning "Clone Hero Launcher install failed: $($_.Exception.Message) Retrying on the next apply."
  exit 1
} finally {
  Remove-Item -LiteralPath $setupPath -ErrorAction SilentlyContinue
}
