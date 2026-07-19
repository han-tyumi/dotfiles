# Install Iosevka Nerd Font (base + Mono) per-user (no admin) as the fallback face for
# surfaces where PragmataPro isn't installed — a narrow, condensed coding font
# close to PragmataPro that carries letters + ligatures + icon glyphs in one
# family. Mirrors the Mac's nerd-fonts.iosevka. run_once; on failure it exits
# non-zero so chezmoi re-fires it on the next apply instead of recording it done
# with nothing done.
$ErrorActionPreference = 'Stop'
# Progress rendering makes 5.1's Invoke-WebRequest an order of magnitude slower and
# buffers the whole (large) body in memory; off, the download doesn't look hung.
$ProgressPreference = 'SilentlyContinue'

$url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip'
$zip = Join-Path $env:TEMP 'Iosevka.zip'
$extract = Join-Path $env:TEMP 'IosevkaNerdFont'
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Write-Host ">> Downloading Iosevka Nerd Font..."
try {
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
  Expand-Archive -Path $zip -DestinationPath $extract -Force
  if (-not (Test-Path $fontDir)) { New-Item -ItemType Directory -Path $fontDir | Out-Null }
  if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

  # Install the base + Mono variants (skip the proportional Propo): the UI fallback
  # uses "Iosevka Nerd Font" and the buffer/terminal fallbacks use "Iosevka Nerd Font Mono".
  $installed = 0
  Get-ChildItem -Path $extract -Filter *.ttf -Recurse |
    Where-Object { $_.Name -notlike '*Propo*' } |
    ForEach-Object {
      $dest = Join-Path $fontDir $_.Name
      Copy-Item -Path $_.FullName -Destination $dest -Force
      $faceName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)

      # Per-user font registration; Windows enumerates the real family name from
      # the font file, so the registry value name only has to be unique.
      New-ItemProperty -Path $regKey -Name "$faceName (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
      $installed++
    }
  if ($installed -eq 0) { throw "No .ttf files found in the Iosevka Nerd Font archive." }
  Write-Host ">> Installed $installed Iosevka Nerd Font face(s)."
} catch {
  Write-Warning "Iosevka Nerd Font install failed: $($_.Exception.Message). Retrying on the next apply."
  exit 1
} finally {
  Remove-Item $zip -ErrorAction SilentlyContinue
  Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
}
