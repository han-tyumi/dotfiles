# Install the Symbols Nerd Font per-user (no admin) for the glyph fallback that
# Zed's buffer_font_fallbacks, Windows Terminal, and starship expect. Mirrors the
# Mac's nerd-fonts.symbols-only. run_once; on failure it exits non-zero so chezmoi
# re-fires it on the next apply instead of recording it done with nothing done.
$ErrorActionPreference = 'Stop'

$url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip'
$zip = Join-Path $env:TEMP 'NerdFontsSymbolsOnly.zip'
$extract = Join-Path $env:TEMP 'NerdFontsSymbolsOnly'
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Write-Host ">> Downloading Symbols Nerd Font..."
try {
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
  Expand-Archive -Path $zip -DestinationPath $extract -Force
  if (-not (Test-Path $fontDir)) { New-Item -ItemType Directory -Path $fontDir | Out-Null }
  if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

  $installed = 0
  Get-ChildItem -Path $extract -Filter *.ttf -Recurse | ForEach-Object {
    $dest = Join-Path $fontDir $_.Name
    Copy-Item -Path $_.FullName -Destination $dest -Force
    $faceName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)

    # Per-user font registration; Windows enumerates the real family name from the
    # font file, so the registry value name only has to be unique.
    New-ItemProperty -Path $regKey -Name "$faceName (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
    $installed++
  }
  if ($installed -eq 0) { throw "No .ttf files found in the Nerd Font archive." }
  Write-Host ">> Installed $installed Nerd Font face(s)."
} catch {
  Write-Warning "Nerd Font install failed: $($_.Exception.Message). Retrying on the next apply."
  exit 1
} finally {
  Remove-Item $zip -ErrorAction SilentlyContinue
  Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
}
