#Requires -Version 7.0

<#
.SYNOPSIS
    Starts a game through its launcher and blocks until the game exits.

.DESCRIPTION
    Steam reports a non-Steam shortcut as running for exactly as long as the
    process it spawned stays alive. Launchers hand the game off to a process
    Steam never sees, so this script stands in for it: start the game, find it,
    then wait on it.

    Games and launchers are described in games.json beside this script. Each
    launcher names a strategy for getting past its Play button:

      uri     a launch URI the launcher handles itself.
      cdp     click the button in the launcher's embedded browser, for clients
              whose URI only navigates rather than launching. Battle.net needs
              this, and it requires the launcher to be started with a remote
              debugging port.
      direct  run the game executable, for launcher-less installs.
#>

param(
    [Parameter(Mandatory)]
    [string]$Game
)

$registryPath = Join-Path $PSScriptRoot 'games.json'
$logPath = Join-Path $env:LOCALAPPDATA 'game-launch.log'
$clientReadyTimeout = [TimeSpan]::FromMinutes(3)
$gameStartTimeout = [TimeSpan]::FromMinutes(5)

function Write-Log {
    param([string]$Message)

    '{0}  [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Game, $Message |
        Add-Content -Path $logPath -Encoding UTF8
}

function Expand-Placeholder {
    param([string]$Text, [hashtable]$Values)

    foreach ($key in $Values.Keys) {
        $Text = $Text.Replace("{$key}", [string]$Values[$key])
    }
    return $Text
}

function Get-GameProcess {
    param([string]$Name)

    Get-Process -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Get-CdpTarget {
    param([int]$Port, [string]$UrlPattern)

    try {
        $targets = Invoke-RestMethod "http://127.0.0.1:$Port/json/list" -TimeoutSec 3 -ErrorAction Stop
    } catch {
        return $null
    }

    # Piping the call straight into a filter streams the decoded list as a single
    # object, so the comparison sees an array of urls and matches everything.
    # Enumerating it explicitly is what makes one target come back.
    foreach ($target in $targets) {
        if ($target.url -like $UrlPattern) { return $target }
    }
    return $null
}

function Invoke-CdpEvaluate {
    param([string]$WebSocketUrl, [string]$Expression)

    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    try {
        $socket.ConnectAsync([Uri]$WebSocketUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

        $request = @{
            id     = 1
            method = 'Runtime.evaluate'
            params = @{ expression = $Expression; returnByValue = $true; awaitPromise = $true }
        } | ConvertTo-Json -Depth 10 -Compress

        $payload = [System.Text.Encoding]::UTF8.GetBytes($request)
        $socket.SendAsync([ArraySegment[byte]]::new($payload), 'Text', $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

        $buffer = New-Object byte[] 262144
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Date) -lt $deadline) {
            $builder = New-Object System.Text.StringBuilder
            do {
                $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
                [void]$builder.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $received.Count))
            } while (-not $received.EndOfMessage)

            $message = $builder.ToString() | ConvertFrom-Json
            if ($message.id -eq 1) { return $message.result.result.value }
        }
        return $null
    } catch {
        Write-Log "cdp error: $($_.Exception.GetBaseException().Message)"
        return $null
    } finally {

        # Disposing without closing aborts the connection, and the client goes on
        # treating the target as attached — every later connect is then refused.
        if ($socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try {
                $closeSource = New-Object System.Threading.CancellationTokenSource 5000
                $socket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', $closeSource.Token).GetAwaiter().GetResult() | Out-Null
            } catch {

                # The target usually vanishes as the game launches, so the close
                # handshake fails harmlessly and is not worth reporting.
            }
        }
        $socket.Dispose()
    }
}

function Build-ClickExpression {
    param([object]$Launcher, [string]$ProductMatch)

    $template = @'
(() => {
  // A dispatched click lands on the button even while a promo takeover paints
  // over it, so the launcher's modals need no handling of their own.
  const selector = document.querySelector("__PRODUCT_SELECTOR__");
  const playButton = document.querySelector("__PLAY_SELECTOR__");
  if (!playButton) return JSON.stringify({ ok: false, reason: "not-ready" });
  const label = (playButton.innerText || "").trim();
  const product = selector ? (selector.innerText || "").trim() : "";
  if (!/__PLAY_LABEL__/i.test(label)) return JSON.stringify({ ok: false, reason: "not-playable", label, product });
  if ("__PRODUCT_MATCH__".length && !product.includes("__PRODUCT_MATCH__")) return JSON.stringify({ ok: false, reason: "wrong-product", label, product });
  playButton.click();
  return JSON.stringify({ ok: true, label, product });
})()
'@

    return $template.
        Replace('__PRODUCT_SELECTOR__', $Launcher.productSelector).
        Replace('__PLAY_SELECTOR__', $Launcher.playSelector).
        Replace('__PLAY_LABEL__', $Launcher.playLabelPattern).
        Replace('__PRODUCT_MATCH__', $ProductMatch)
}

if (-not (Test-Path $registryPath)) {
    Write-Log "registry missing: $registryPath"
    exit 1
}

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

$entry = $registry.games.$Game
if (-not $entry) {
    Write-Log "unknown game; known: $($registry.games.PSObject.Properties.Name -join ', ')"
    exit 1
}

$launcher = $registry.launchers.($entry.launcher)
if (-not $launcher) {
    Write-Log "unknown launcher: $($entry.launcher)"
    exit 1
}

$placeholders = @{ id = $entry.id; port = $launcher.debuggingPort }

Write-Log "--- start (launcher $($entry.launcher), strategy $($launcher.strategy)) ---"

# Steam reports the shortcut as running for exactly as long as this script lives,
# so everything below exists to keep it alive until the game itself exits.
$gameProcess = Get-GameProcess -Name $entry.process

if (-not $gameProcess) {
    switch ($launcher.strategy) {

        'uri' {
            $uri = Expand-Placeholder -Text $launcher.uri -Values $placeholders
            Write-Log "opening $uri"
            Start-Process $uri
        }

        'direct' {
            $executable = Expand-Placeholder -Text $entry.exe -Values $placeholders
            Write-Log "running $executable"
            Start-Process $executable -WorkingDirectory (Split-Path $executable)
        }

        'cdp' {
            $port = $launcher.debuggingPort
            $pattern = $launcher.targetUrlPattern

            # The launcher only exposes its DevTools endpoint when started with
            # the port flag, so an instance started any other way is replaced.
            $running = Get-Process -Name $launcher.processPattern -ErrorAction SilentlyContinue
            if ($running -and -not (Get-CdpTarget -Port $port -UrlPattern $pattern)) {
                Write-Log 'launcher running without the debug port; restarting it'
                $running | Stop-Process -Force -ErrorAction SilentlyContinue
                foreach ($companion in $launcher.alsoStop) {
                    Get-Process -Name $companion -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                }
                Start-Sleep -Seconds 4
            }

            if (-not (Get-CdpTarget -Port $port -UrlPattern $pattern)) {
                $arguments = @($launcher.startArgs | ForEach-Object { Expand-Placeholder -Text $_ -Values $placeholders })
                Write-Log "starting launcher: $($arguments -join ' ')"
                Start-Process $launcher.path -ArgumentList $arguments
            }

            $clickExpression = Build-ClickExpression -Launcher $launcher -ProductMatch $entry.productMatch
            $deadline = (Get-Date).Add($clientReadyTimeout)
            while ((Get-Date) -lt $deadline) {

                # The client replaces its page target while it loads, so resolve
                # the debugger URL fresh on every attempt.
                $target = Get-CdpTarget -Port $port -UrlPattern $pattern

                if ($target -and -not $target.webSocketDebuggerUrl) {
                    Write-Log 'target found but busy: another debugger is attached'
                } elseif ($target) {
                    $outcome = Invoke-CdpEvaluate -WebSocketUrl $target.webSocketDebuggerUrl -Expression $clickExpression
                    Write-Log "attempt: $outcome"
                    if ($outcome -and ($outcome | ConvertFrom-Json).ok) { break }
                } else {
                    Write-Log 'target not available yet'
                }

                Start-Sleep -Seconds 3
            }
        }

        default {
            Write-Log "unsupported strategy: $($launcher.strategy)"
            exit 1
        }
    }

    $deadline = (Get-Date).Add($gameStartTimeout)
    while (-not $gameProcess -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $gameProcess = Get-GameProcess -Name $entry.process
    }
}

Write-Log "game process: $(if ($gameProcess) { 'pid ' + $gameProcess.Id } else { 'NEVER APPEARED' })"

# Polling rather than Start-Process -Wait: the launcher spawns the game, not this
# script, so there is no child process to wait on.
if ($gameProcess) {
    $gameProcess.WaitForExit()
}
