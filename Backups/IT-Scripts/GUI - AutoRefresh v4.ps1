#requires -version 5.1
<#
    GUI - AutoRefresh v4.ps1

    Purpose:
    - Launches a dedicated Microsoft Edge window for a specific URL.
    - Refreshes the page using Edge DevTools Protocol instead of SendKeys/F5.
    - Does not steal focus during refresh.
    - Includes GUI countdown, interval control, tray support, config persistence, and status feedback.

    Notes:
    - First launch may require you to sign into the website once because this uses a dedicated Edge profile.
    - The dedicated profile is stored under:
      $env:LOCALAPPDATA\AutoRefreshEdgeProfile
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# ------------------------------------------------------------
# Default Settings
# ------------------------------------------------------------

$DefaultUrl = "https://your-instance.service-now.com/now/nav/ui/classic/params/target/incident_list.do?sysparm_query=active=true"

$ConfigPath = Join-Path $env:APPDATA "AutoRefreshGuiV4Config.json"
$ProfileDir = Join-Path $env:LOCALAPPDATA "AutoRefreshEdgeProfile"

$script:Config = [ordered]@{
    Url             = $DefaultUrl
    IntervalSeconds = 30
    DebugPort       = 9223
    ProfileDir      = $ProfileDir
    StartMinimized  = $false
}

if (Test-Path $ConfigPath) {
    try {
        $loaded = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

        if ($loaded.Url) { $script:Config.Url = [string]$loaded.Url }
        if ($loaded.IntervalSeconds) { $script:Config.IntervalSeconds = [int]$loaded.IntervalSeconds }
        if ($loaded.DebugPort) { $script:Config.DebugPort = [int]$loaded.DebugPort }
        if ($loaded.ProfileDir) { $script:Config.ProfileDir = [string]$loaded.ProfileDir }
        if ($null -ne $loaded.StartMinimized) { $script:Config.StartMinimized = [bool]$loaded.StartMinimized }
    }
    catch {
        # Continue with defaults if config is unreadable.
    }
}

# ------------------------------------------------------------
# Script State
# ------------------------------------------------------------

$script:Running = $false
$script:Remaining = [int]$script:Config.IntervalSeconds
$script:EdgeProcess = $null
$script:WebSocketDebuggerUrl = $null
$script:CdpMessageId = 0
$script:OriginalBackColor = $null
$script:LastRefreshSucceeded = $false

# ------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------

function Save-Config {
    try {
        $save = [ordered]@{
            Url             = [string]$txtUrl.Text
            IntervalSeconds = [int]$numInterval.Value
            DebugPort       = [int]$numPort.Value
            ProfileDir      = [string]$txtProfile.Text
            StartMinimized  = [bool]$chkStartMinimized.Checked
        }

        $save | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
    }
    catch {
        # Silently continue if config cannot be saved.
    }
}

function Get-EdgePath {
    $candidatePaths = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($path in $candidatePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    $cmd = Get-Command "msedge.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Test-DebugEndpoint {
    param(
        [int]$Port
    )

    try {
        $uri = "http://127.0.0.1:$Port/json/version"
        $null = Invoke-RestMethod -Uri $uri -TimeoutSec 2 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-CdpPageTarget {
    param(
        [int]$Port,
        [string]$TargetUrl
    )

    try {
        $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 3 -ErrorAction Stop

        $pages = @($targets | Where-Object {
            $_.type -eq "page" -and
            $_.webSocketDebuggerUrl
        })

        if (-not $pages -or $pages.Count -eq 0) {
            return $null
        }

        # Prefer exact URL match.
        $exact = $pages | Where-Object { $_.url -eq $TargetUrl } | Select-Object -First 1
        if ($exact) {
            return $exact
        }

        # Prefer non-new-tab / non-devtools pages.
        $usable = $pages | Where-Object {
            $_.url -notlike "edge://*" -and
            $_.url -notlike "chrome://*" -and
            $_.url -notlike "devtools://*"
        } | Select-Object -First 1

        if ($usable) {
            return $usable
        }

        return ($pages | Select-Object -First 1)
    }
    catch {
        return $null
    }
}

function Connect-CdpTarget {
    param(
        [int]$Port,
        [string]$TargetUrl
    )

    $target = Get-CdpPageTarget -Port $Port -TargetUrl $TargetUrl

    if (-not $target) {
        $script:WebSocketDebuggerUrl = $null
        return $false
    }

    $script:WebSocketDebuggerUrl = [string]$target.webSocketDebuggerUrl
    return $true
}

function Invoke-CdpCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [hashtable]$Params = @{}
    )

    if ([string]::IsNullOrWhiteSpace($script:WebSocketDebuggerUrl)) {
        throw "No DevTools WebSocket target is connected."
    }

    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $ct = [System.Threading.CancellationToken]::None

    try {
        $connectTask = $ws.ConnectAsync([Uri]$script:WebSocketDebuggerUrl, $ct)
        $connectTask.Wait()

        $script:CdpMessageId++

        $payloadObject = @{
            id     = $script:CdpMessageId
            method = $Method
            params = $Params
        }

        $payload = $payloadObject | ConvertTo-Json -Depth 10 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $sendSegment = New-Object "System.ArraySegment[byte]" -ArgumentList @(,$bytes)

        $sendTask = $ws.SendAsync(
            $sendSegment,
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $ct
        )
        $sendTask.Wait()

        # Read response once. We do not need to fully parse it for Page.reload.
        $buffer = New-Object byte[] 8192
        $receiveSegment = New-Object "System.ArraySegment[byte]" -ArgumentList @(,$buffer)
        $receiveTask = $ws.ReceiveAsync($receiveSegment, $ct)
        $receiveTask.Wait()

        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $closeTask = $ws.CloseAsync(
                [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                "Done",
                $ct
            )
            $closeTask.Wait()
        }
    }
    finally {
        $ws.Dispose()
    }
}

function Start-DedicatedEdge {
    $edgePath = Get-EdgePath

    if (-not $edgePath) {
        throw "Microsoft Edge was not found on this device."
    }

    $url = [string]$txtUrl.Text
    $port = [int]$numPort.Value
    $profile = [string]$txtProfile.Text

    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "URL cannot be empty."
    }

    if ([string]::IsNullOrWhiteSpace($profile)) {
        throw "Profile directory cannot be empty."
    }

    if (-not (Test-Path $profile)) {
        New-Item -Path $profile -ItemType Directory -Force | Out-Null
    }

    # If the debug endpoint is already available, reuse it.
    if (Test-DebugEndpoint -Port $port) {
        if (Connect-CdpTarget -Port $port -TargetUrl $url) {
            return $true
        }
    }

    $arguments = @(
        "--remote-debugging-port=$port",
        "--user-data-dir=""$profile""",
        "--new-window",
        "$url"
    )

    if ($chkStartMinimized.Checked) {
        $arguments += "--start-minimized"
    }

    $script:EdgeProcess = Start-Process -FilePath $edgePath -ArgumentList $arguments -PassThru

    # Give Edge a moment to expose the debugging endpoint.
    $connected = $false

    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500

        if (Test-DebugEndpoint -Port $port) {
            if (Connect-CdpTarget -Port $port -TargetUrl $url) {
                $connected = $true
                break
            }
        }
    }

    if (-not $connected) {
        throw "Edge launched, but the DevTools refresh endpoint was not available."
    }

    return $true
}

function Refresh-PageNoFocus {
    $url = [string]$txtUrl.Text
    $port = [int]$numPort.Value

    if (-not (Test-DebugEndpoint -Port $port)) {
        throw "Edge DevTools endpoint is not available. Launch the dedicated Edge window first."
    }

    if ([string]::IsNullOrWhiteSpace($script:WebSocketDebuggerUrl)) {
        if (-not (Connect-CdpTarget -Port $port -TargetUrl $url)) {
            throw "Could not connect to the Edge page target."
        }
    }

    try {
        Invoke-CdpCommand -Method "Page.reload" -Params @{ ignoreCache = $false }
    }
    catch {
        # Target may have changed after reload; reconnect and retry once.
        $script:WebSocketDebuggerUrl = $null

        if (Connect-CdpTarget -Port $port -TargetUrl $url) {
            Invoke-CdpCommand -Method "Page.reload" -Params @{ ignoreCache = $false }
        }
        else {
            throw
        }
    }
}

function Flash-RefreshSuccess {
    $script:OriginalBackColor = $form.BackColor
    $form.BackColor = [System.Drawing.Color]::FromArgb(210, 255, 210)
    $lblCountdown.Text = "Refreshing..."
    $lblStatus.Text = "Status: Refresh sent without stealing focus"
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    $flashTimer.Start()
}

function Stop-AutoRefresh {
    $script:Running = $false
    $timer.Stop()

    $btnStart.Enabled = $true
    $btnStop.Enabled = $false

    $lblCountdown.Text = "Stopped"
    $lblStatus.Text = "Status: Stopped"
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkOrange

    $notifyIcon.Text = "Auto Refresh v4 - Stopped"

    Save-Config
}

# ------------------------------------------------------------
# Main Form
# ------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Auto Refresh Dashboard v4 - No Focus Stealing"
$form.Size = New-Object System.Drawing.Size(760, 420)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# URL Label
$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Location = New-Object System.Drawing.Point(15, 18)
$lblUrl.Size = New-Object System.Drawing.Size(90, 22)
$lblUrl.Text = "Target URL:"
$form.Controls.Add($lblUrl)

# URL TextBox
$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(110, 15)
$txtUrl.Size = New-Object System.Drawing.Size(615, 25)
$txtUrl.Text = [string]$script:Config.Url
$form.Controls.Add($txtUrl)

# Interval Label
$lblInterval = New-Object System.Windows.Forms.Label
$lblInterval.Location = New-Object System.Drawing.Point(15, 58)
$lblInterval.Size = New-Object System.Drawing.Size(120, 22)
$lblInterval.Text = "Interval seconds:"
$form.Controls.Add($lblInterval)

# Interval Numeric
$numInterval = New-Object System.Windows.Forms.NumericUpDown
$numInterval.Location = New-Object System.Drawing.Point(140, 55)
$numInterval.Size = New-Object System.Drawing.Size(80, 25)
$numInterval.Minimum = 5
$numInterval.Maximum = 3600
$numInterval.Value = [decimal]$script:Config.IntervalSeconds
$form.Controls.Add($numInterval)

# Port Label
$lblPort = New-Object System.Windows.Forms.Label
$lblPort.Location = New-Object System.Drawing.Point(245, 58)
$lblPort.Size = New-Object System.Drawing.Size(110, 22)
$lblPort.Text = "Debug port:"
$form.Controls.Add($lblPort)

# Port Numeric
$numPort = New-Object System.Windows.Forms.NumericUpDown
$numPort.Location = New-Object System.Drawing.Point(330, 55)
$numPort.Size = New-Object System.Drawing.Size(90, 25)
$numPort.Minimum = 9000
$numPort.Maximum = 9999
$numPort.Value = [decimal]$script:Config.DebugPort
$form.Controls.Add($numPort)

# Start minimized checkbox
$chkStartMinimized = New-Object System.Windows.Forms.CheckBox
$chkStartMinimized.Location = New-Object System.Drawing.Point(445, 56)
$chkStartMinimized.Size = New-Object System.Drawing.Size(180, 22)
$chkStartMinimized.Text = "Launch Edge minimized"
$chkStartMinimized.Checked = [bool]$script:Config.StartMinimized
$form.Controls.Add($chkStartMinimized)

# Profile Label
$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Location = New-Object System.Drawing.Point(15, 98)
$lblProfile.Size = New-Object System.Drawing.Size(90, 22)
$lblProfile.Text = "Edge profile:"
$form.Controls.Add($lblProfile)

# Profile TextBox
$txtProfile = New-Object System.Windows.Forms.TextBox
$txtProfile.Location = New-Object System.Drawing.Point(110, 95)
$txtProfile.Size = New-Object System.Drawing.Size(615, 25)
$txtProfile.Text = [string]$script:Config.ProfileDir
$form.Controls.Add($txtProfile)

# Launch Button
$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Location = New-Object System.Drawing.Point(15, 140)
$btnLaunch.Size = New-Object System.Drawing.Size(160, 35)
$btnLaunch.Text = "Launch Dedicated Edge"
$form.Controls.Add($btnLaunch)

# Start Button
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(185, 140)
$btnStart.Size = New-Object System.Drawing.Size(110, 35)
$btnStart.Text = "Start"
$form.Controls.Add($btnStart)

# Stop Button
$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(305, 140)
$btnStop.Size = New-Object System.Drawing.Size(110, 35)
$btnStop.Text = "Stop"
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

# Manual Refresh Button
$btnManualRefresh = New-Object System.Windows.Forms.Button
$btnManualRefresh.Location = New-Object System.Drawing.Point(425, 140)
$btnManualRefresh.Size = New-Object System.Drawing.Size(130, 35)
$btnManualRefresh.Text = "Refresh Now"
$form.Controls.Add($btnManualRefresh)

# Minimize Button
$btnMinimize = New-Object System.Windows.Forms.Button
$btnMinimize.Location = New-Object System.Drawing.Point(565, 140)
$btnMinimize.Size = New-Object System.Drawing.Size(160, 35)
$btnMinimize.Text = "Minimize to Tray"
$form.Controls.Add($btnMinimize)

# Countdown Label
$lblCountdown = New-Object System.Windows.Forms.Label
$lblCountdown.Location = New-Object System.Drawing.Point(15, 200)
$lblCountdown.Size = New-Object System.Drawing.Size(710, 42)
$lblCountdown.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$lblCountdown.Text = "Refresh in: $($script:Config.IntervalSeconds)s"
$form.Controls.Add($lblCountdown)

# Last Refresh Label
$lblLastRefresh = New-Object System.Windows.Forms.Label
$lblLastRefresh.Location = New-Object System.Drawing.Point(15, 250)
$lblLastRefresh.Size = New-Object System.Drawing.Size(710, 22)
$lblLastRefresh.Text = "Last Refresh: Never"
$form.Controls.Add($lblLastRefresh)

# Connection Label
$lblConnection = New-Object System.Windows.Forms.Label
$lblConnection.Location = New-Object System.Drawing.Point(15, 278)
$lblConnection.Size = New-Object System.Drawing.Size(710, 22)
$lblConnection.Text = "Connection: Not connected"
$lblConnection.ForeColor = [System.Drawing.Color]::DarkOrange
$form.Controls.Add($lblConnection)

# Status Label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 306)
$lblStatus.Size = New-Object System.Drawing.Size(710, 45)
$lblStatus.Text = "Status: Ready. Launch the dedicated Edge window first, then start the timer."
$lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($lblStatus)

# ------------------------------------------------------------
# Tray Icon
# ------------------------------------------------------------

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Visible = $true
$notifyIcon.Text = "Auto Refresh v4"

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$restoreItem = New-Object System.Windows.Forms.ToolStripMenuItem
$restoreItem.Text = "Restore"

$startStopItem = New-Object System.Windows.Forms.ToolStripMenuItem
$startStopItem.Text = "Start/Stop"

$refreshNowItem = New-Object System.Windows.Forms.ToolStripMenuItem
$refreshNowItem.Text = "Refresh Now"

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"

[void]$trayMenu.Items.Add($restoreItem)
[void]$trayMenu.Items.Add($startStopItem)
[void]$trayMenu.Items.Add($refreshNowItem)
[void]$trayMenu.Items.Add($exitItem)

$notifyIcon.ContextMenuStrip = $trayMenu

$restoreItem.Add_Click({
    $form.Show()
    $form.WindowState = "Normal"
    $form.Activate()
})

$startStopItem.Add_Click({
    if ($script:Running) {
        Stop-AutoRefresh
    }
    else {
        $btnStart.PerformClick()
    }
})

$refreshNowItem.Add_Click({
    $btnManualRefresh.PerformClick()
})

$exitItem.Add_Click({
    Save-Config
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $form.Close()
})

$notifyIcon.Add_DoubleClick({
    $form.Show()
    $form.WindowState = "Normal"
    $form.Activate()
})

# ------------------------------------------------------------
# Timers
# ------------------------------------------------------------

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000

$timer.Add_Tick({
    if (-not $script:Running) {
        return
    }

    $script:Remaining--

    $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
    $notifyIcon.Text = "Refresh in: $($script:Remaining)s"

    if ($script:Remaining -le 0) {
        try {
            Refresh-PageNoFocus

            $script:LastRefreshSucceeded = $true
            $lblLastRefresh.Text = "Last Refresh: $(Get-Date -Format 'hh:mm:ss tt')"
            Flash-RefreshSuccess
        }
        catch {
            $script:LastRefreshSucceeded = $false
            $lblStatus.Text = "Status: Refresh failed. $($_.Exception.Message)"
            $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
            $lblConnection.Text = "Connection: Problem detected"
            $lblConnection.ForeColor = [System.Drawing.Color]::DarkRed
        }

        $script:Remaining = [int]$numInterval.Value
    }
})

$flashTimer = New-Object System.Windows.Forms.Timer
$flashTimer.Interval = 700

$flashTimer.Add_Tick({
    $flashTimer.Stop()

    if ($script:OriginalBackColor) {
        $form.BackColor = $script:OriginalBackColor
    }

    if ($script:Running) {
        $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
        $lblStatus.Text = "Status: Running. Refreshes are being sent through Edge DevTools without SendKeys."
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    }
})

# ------------------------------------------------------------
# Button Events
# ------------------------------------------------------------

$btnLaunch.Add_Click({
    try {
        Save-Config

        $lblStatus.Text = "Status: Launching dedicated Edge window..."
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue
        $form.Refresh()

        $null = Start-DedicatedEdge

        $lblConnection.Text = "Connection: Connected to Edge on port $([int]$numPort.Value)"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkGreen

        $lblStatus.Text = "Status: Dedicated Edge window is ready. You can sign in if prompted, then select Start."
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    }
    catch {
        $lblStatus.Text = "Status: Failed to launch/connect. $($_.Exception.Message)"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed

        $lblConnection.Text = "Connection: Not connected"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkRed
    }
})

$btnStart.Add_Click({
    try {
        Save-Config

        if (-not (Test-DebugEndpoint -Port ([int]$numPort.Value))) {
            $null = Start-DedicatedEdge
        }
        else {
            $connected = Connect-CdpTarget -Port ([int]$numPort.Value) -TargetUrl ([string]$txtUrl.Text)
            if (-not $connected) {
                throw "Could not connect to a page in the dedicated Edge instance."
            }
        }

        $script:Remaining = [int]$numInterval.Value
        $script:Running = $true

        $timer.Start()

        $btnStart.Enabled = $false
        $btnStop.Enabled = $true

        $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
        $lblConnection.Text = "Connection: Connected to Edge on port $([int]$numPort.Value)"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkGreen

        $lblStatus.Text = "Status: Running. Refreshes will not steal focus."
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen

        $notifyIcon.Text = "Auto Refresh v4 - Running"
    }
    catch {
        $lblStatus.Text = "Status: Could not start. $($_.Exception.Message)"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed

        $lblConnection.Text = "Connection: Not connected"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkRed
    }
})

$btnStop.Add_Click({
    Stop-AutoRefresh
})

$btnManualRefresh.Add_Click({
    try {
        if (-not (Test-DebugEndpoint -Port ([int]$numPort.Value))) {
            $null = Start-DedicatedEdge
        }
        else {
            if ([string]::IsNullOrWhiteSpace($script:WebSocketDebuggerUrl)) {
                $null = Connect-CdpTarget -Port ([int]$numPort.Value) -TargetUrl ([string]$txtUrl.Text)
            }
        }

        Refresh-PageNoFocus

        $lblLastRefresh.Text = "Last Refresh: $(Get-Date -Format 'hh:mm:ss tt')"
        $lblConnection.Text = "Connection: Connected to Edge on port $([int]$numPort.Value)"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkGreen

        Flash-RefreshSuccess
    }
    catch {
        $lblStatus.Text = "Status: Manual refresh failed. $($_.Exception.Message)"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed

        $lblConnection.Text = "Connection: Problem detected"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkRed
    }
})

$btnMinimize.Add_Click({
    $form.Hide()
    $notifyIcon.ShowBalloonTip(
        1500,
        "Auto Refresh v4",
        "Still running in the system tray.",
        [System.Windows.Forms.ToolTipIcon]::Info
    )
})

$numInterval.Add_ValueChanged({
    if (-not $script:Running) {
        $script:Remaining = [int]$numInterval.Value
        $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
    }

    Save-Config
})

$numPort.Add_ValueChanged({
    Save-Config
})

$txtUrl.Add_TextChanged({
    Save-Config
})

$txtProfile.Add_TextChanged({
    Save-Config
})

$chkStartMinimized.Add_CheckedChanged({
    Save-Config
})

$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
        $form.Hide()
    }
})

$form.Add_FormClosing({
    Save-Config

    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
})

# ------------------------------------------------------------
# Initial State
# ------------------------------------------------------------

if (Test-DebugEndpoint -Port ([int]$numPort.Value)) {
    if (Connect-CdpTarget -Port ([int]$numPort.Value) -TargetUrl ([string]$txtUrl.Text)) {
        $lblConnection.Text = "Connection: Existing Edge debug session detected on port $([int]$numPort.Value)"
        $lblConnection.ForeColor = [System.Drawing.Color]::DarkGreen
        $lblStatus.Text = "Status: Ready. Existing dedicated Edge session detected."
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    }
}

[void]$form.ShowDialog()
