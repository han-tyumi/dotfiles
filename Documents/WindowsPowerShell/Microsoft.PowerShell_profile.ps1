# Windows PowerShell 5.1 profile: hand interactive sessions off to PowerShell 7.
# Surfaces that hard-code powershell.exe (e.g. the Claude Desktop terminal) land
# here and immediately get pwsh instead. Guards keep automation unaffected:
#   - launches with -Command/-File/-EncodedCommand/-NonInteractive/-WindowStyle
#     (scripts, scheduled tasks, tool-spawned shells) never hop
#   - redirected stdin never hops
#   - set NO_PWSH_HOP=1 to stay in 5.1 deliberately
$commandLineArgs = [Environment]::GetCommandLineArgs()
$isAutomation = ($commandLineArgs |
    Where-Object { $_ -match '^-{1,2}(command|file|encodedcommand|noninteractive|windowstyle)' }).Count -gt 0
if (-not $isAutomation -and
    [Environment]::UserInteractive -and
    -not [Console]::IsInputRedirected -and
    -not $env:NO_PWSH_HOP -and
    (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    pwsh
    exit $LASTEXITCODE
}
