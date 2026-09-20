#Requires -Version 7.0

$battleNetPath = 'C:\Program Files\Battle.net\Battle.net.exe'
$gameProcessName = 'WowB'
$productUid = 'wow_classic_beta'
$expectedProduct = 'Forever'
$debuggingPort = 9222
$clientReadyTimeout = [TimeSpan]::FromMinutes(3)
$gameStartTimeout = [TimeSpan]::FromMinutes(5)
$logPath = Join-Path $env:LOCALAPPDATA 'wow-forever.log'

function Write-Log {
    param([string]$Message)

    '{0}  {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message | Add-Content -Path $logPath -Encoding UTF8
}

function Get-ClientHomeTarget {
    try {
        $targets = Invoke-RestMethod "http://127.0.0.1:$debuggingPort/json/list" -TimeoutSec 3 -ErrorAction Stop
    } catch {
        return $null
    }

    # Piping the call straight into a filter streams the decoded list as a single
    # object, so the comparison sees an array of urls and matches everything.
    # Enumerating it explicitly is what makes one target come back.
    foreach ($target in $targets) {
        if ($target.url -like 'resources://home*') { return $target }
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

# Dismissal and the click share one evaluation so each attempt opens a single
# connection, which keeps the target free between retries.
$attemptTemplate = @'
(() => {
  const isVisible = (node) => {
    const style = getComputedStyle(node);
    return node.offsetParent !== null && style.visibility !== "hidden" && style.opacity !== "0";
  };
  const dialogs = Array.from(document.querySelectorAll("[role=dialog], [role=alertdialog], dialog[open]")).filter(isVisible);
  let dismissed = 0;
  for (const dialog of dialogs) {
    const closeButton = dialog.querySelector('button[aria-label*="close" i], button[class*="close" i], [role=button][class*="close" i]');
    if (closeButton) {
      closeButton.click();
      dismissed += 1;
    }
  }
  if (dialogs.length > dismissed) {
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", code: "Escape", keyCode: 27, which: 27, bubbles: true }));
  }

  const selector = document.querySelector(".play-selector-button");
  const playButton = document.querySelector("button.play-btn.play-action");
  if (!playButton) return JSON.stringify({ ok: false, reason: "not-ready", dialogs: dialogs.length });
  const label = (playButton.innerText || "").trim();
  const product = selector ? (selector.innerText || "").trim() : "";
  if (!/^play$/i.test(label)) return JSON.stringify({ ok: false, reason: "not-playable", label, product });
  if (!product.includes("__EXPECTED__")) return JSON.stringify({ ok: false, reason: "wrong-product", label, product });
  playButton.click();
  return JSON.stringify({ ok: true, label, product, dialogs: dialogs.length });
})()
'@

$attemptExpression = $attemptTemplate.Replace('__EXPECTED__', $expectedProduct)

Write-Log '--- wrapper start ---'

# Steam reports the shortcut as running for exactly as long as this script lives,
# so everything below exists to keep it alive until the game itself exits.
$gameProcess = Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $gameProcess) {

    # The client only exposes its DevTools endpoint when started with the port
    # flag, so an instance launched any other way has to be replaced.
    if ((Get-Process -Name 'Battle.net*' -ErrorAction SilentlyContinue) -and -not (Get-ClientHomeTarget)) {
        Write-Log 'client running without the debug port; restarting it'
        Get-Process -Name 'Battle.net*', 'Agent' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
    }

    if (-not (Get-ClientHomeTarget)) {
        Write-Log 'starting client'
        Start-Process $battleNetPath -ArgumentList "--remote-debugging-port=$debuggingPort", "--exec=`"launch_uid $productUid`""
    }

    $deadline = (Get-Date).Add($clientReadyTimeout)
    while ((Get-Date) -lt $deadline) {

        # The client replaces its page target while it moves from login to the
        # game list, so resolve the debugger URL fresh on every attempt.
        $homeTarget = Get-ClientHomeTarget

        if ($homeTarget -and -not $homeTarget.webSocketDebuggerUrl) {
            Write-Log 'target found but busy: another debugger is attached'
        } elseif ($homeTarget) {
            $outcome = Invoke-CdpEvaluate -WebSocketUrl $homeTarget.webSocketDebuggerUrl -Expression $attemptExpression
            Write-Log "attempt: $outcome"
            if ($outcome -and ($outcome | ConvertFrom-Json).ok) { break }
        } else {
            Write-Log 'home target not available yet'
        }

        Start-Sleep -Seconds 3
    }

    $deadline = (Get-Date).Add($gameStartTimeout)
    while (-not $gameProcess -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $gameProcess = Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}

Write-Log "game process: $(if ($gameProcess) { 'pid ' + $gameProcess.Id } else { 'NEVER APPEARED' })"

# Polling rather than Start-Process -Wait: Battle.net spawns the game, not this
# script, so there is no child process to wait on.
if ($gameProcess) {
    $gameProcess.WaitForExit()
}
