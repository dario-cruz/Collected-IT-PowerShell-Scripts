Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------

$configPath = Join-Path $env:APPDATA "AutoRefreshGuiConfig.json"

$config = [ordered]@{
    IntervalSeconds = 30
    EdgeOnly        = $true
    LastTitle       = ""
    LastProcessName = ""
    LastHwnd        = ""
}

if (Test-Path $configPath) {
    try {
        $loadedConfig = Get-Content $configPath -Raw | ConvertFrom-Json

        if ($loadedConfig.IntervalSeconds) { $config.IntervalSeconds = [int]$loadedConfig.IntervalSeconds }
        if ($null -ne $loadedConfig.EdgeOnly) { $config.EdgeOnly = [bool]$loadedConfig.EdgeOnly }
        if ($loadedConfig.LastTitle) { $config.LastTitle = [string]$loadedConfig.LastTitle }
        if ($loadedConfig.LastProcessName) { $config.LastProcessName = [string]$loadedConfig.LastProcessName }
        if ($loadedConfig.LastHwnd) { $config.LastHwnd = [string]$loadedConfig.LastHwnd }
    }
    catch {
        # If config is damaged, continue with defaults.
    }
}

function Save-Config {
    try {
        $saveObject = [ordered]@{
            IntervalSeconds = [int]$numInterval.Value
            EdgeOnly        = [bool]$chkEdgeOnly.Checked
            LastTitle       = [string]$script:TargetTitle
            LastProcessName = [string]$script:TargetProcessName
            LastHwnd        = if ($script:TargetHwnd -ne [IntPtr]::Zero) { $script:TargetHwnd.ToInt64().ToString() } else { "" }
        }

        $saveObject | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
    }
    catch {
        # Silently continue if config cannot be saved.
    }
}

# ------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------

function Get-WindowTitleFromHandle {
    param(
        [IntPtr]$Handle
    )

    if ($Handle -eq [IntPtr]::Zero) {
        return ""
    }

    $length = [Win32]::GetWindowTextLength($Handle)

    if ($length -le 0) {
        return ""
    }

    $builder = New-Object System.Text.StringBuilder ($length + 1)
    [void][Win32]::GetWindowText($Handle, $builder, $builder.Capacity)

    return $builder.ToString()
}

function Get-WindowList {
    param(
        [bool]$EdgeOnly
    )

    $windows = @()

    $processes = Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and
            -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle)
        }

    if ($EdgeOnly) {
        $processes = $processes | Where-Object { $_.ProcessName -eq "msedge" }
    }

    foreach ($process in ($processes | Sort-Object ProcessName, MainWindowTitle)) {
        $display = "{0} | PID {1} | {2}" -f $process.ProcessName, $process.Id, $process.MainWindowTitle

        $windows += [PSCustomObject]@{
            Display     = $display
            Title       = $process.MainWindowTitle
            ProcessName = $process.ProcessName
            ProcessId   = $process.Id
            Hwnd        = $process.MainWindowHandle
        }
    }

    return $windows
}

function Load-Windows {
    $cmbWindows.Items.Clear()

    $windows = Get-WindowList -EdgeOnly:$chkEdgeOnly.Checked

    foreach ($window in $windows) {
        [void]$cmbWindows.Items.Add($window)
    }

    # Try to reselect by remembered HWND first.
    if ($config.LastHwnd) {
        foreach ($item in $cmbWindows.Items) {
            if ($item.Hwnd.ToInt64().ToString() -eq $config.LastHwnd) {
                $cmbWindows.SelectedItem = $item
                return
            }
        }
    }

    # Fallback to remembered title.
    if ($config.LastTitle) {
        foreach ($item in $cmbWindows.Items) {
            if ($item.Title -eq $config.LastTitle) {
                $cmbWindows.SelectedItem = $item
                return
            }
        }
    }

    if ($cmbWindows.Items.Count -gt 0) {
        $cmbWindows.SelectedIndex = 0
    }
}

function Set-TargetWindow {
    param(
        [IntPtr]$Hwnd,
        [string]$Title,
        [string]$ProcessName
    )

    $script:TargetHwnd = $Hwnd
    $script:TargetTitle = $Title
    $script:TargetProcessName = $ProcessName

    if ($script:TargetHwnd -ne [IntPtr]::Zero) {
        $lblTarget.Text = "Target: $ProcessName - $Title"
        $lblStatus.Text = "Status: Target selected"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    }
    else {
        $lblTarget.Text = "Target: None"
        $lblStatus.Text = "Status: No target selected"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
    }

    Save-Config
}

function Validate-TargetWindow {
    if ($script:TargetHwnd -eq [IntPtr]::Zero) {
        return $false
    }

    if (-not [Win32]::IsWindow($script:TargetHwnd)) {
        return $false
    }

    return $true
}

function Flash-Refresh {
    $script:OriginalBackColor = $form.BackColor
    $form.BackColor = [System.Drawing.Color]::FromArgb(210, 255, 210)
    $lblCountdown.Text = "Refreshing..."
    $lblStatus.Text = "Status: Refresh sent"
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

    $notifyIcon.Text = "Auto Refresh Dashboard - Stopped"

    Save-Config
}

# ------------------------------------------------------------
# Script State
# ------------------------------------------------------------

$script:Running = $false
$script:Remaining = [int]$config.IntervalSeconds
$script:TargetHwnd = [IntPtr]::Zero
$script:TargetTitle = ""
$script:TargetProcessName = ""
$script:OriginalBackColor = $null

# ------------------------------------------------------------
# Main Form
# ------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Auto Refresh Dashboard"
$form.Size = New-Object System.Drawing.Size(560, 335)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Target label
$lblWindow = New-Object System.Windows.Forms.Label
$lblWindow.Location = New-Object System.Drawing.Point(15, 18)
$lblWindow.Size = New-Object System.Drawing.Size(110, 20)
$lblWindow.Text = "Target Window:"
$form.Controls.Add($lblWindow)

# Window dropdown
$cmbWindows = New-Object System.Windows.Forms.ComboBox
$cmbWindows.Location = New-Object System.Drawing.Point(130, 15)
$cmbWindows.Size = New-Object System.Drawing.Size(395, 25)
$cmbWindows.DropDownStyle = "DropDownList"
$cmbWindows.DisplayMember = "Display"
$form.Controls.Add($cmbWindows)

# Edge only checkbox
$chkEdgeOnly = New-Object System.Windows.Forms.CheckBox
$chkEdgeOnly.Location = New-Object System.Drawing.Point(130, 48)
$chkEdgeOnly.Size = New-Object System.Drawing.Size(140, 22)
$chkEdgeOnly.Text = "Show Edge only"
$chkEdgeOnly.Checked = [bool]$config.EdgeOnly
$form.Controls.Add($chkEdgeOnly)

# Refresh list button
$btnRefreshList = New-Object System.Windows.Forms.Button
$btnRefreshList.Location = New-Object System.Drawing.Point(15, 78)
$btnRefreshList.Size = New-Object System.Drawing.Size(110, 30)
$btnRefreshList.Text = "Refresh List"
$form.Controls.Add($btnRefreshList)

# Capture active window button
$btnCaptureActive = New-Object System.Windows.Forms.Button
$btnCaptureActive.Location = New-Object System.Drawing.Point(130, 78)
$btnCaptureActive.Size = New-Object System.Drawing.Size(150, 30)
$btnCaptureActive.Text = "Capture Active Window"
$form.Controls.Add($btnCaptureActive)

# Interval label
$lblInterval = New-Object System.Windows.Forms.Label
$lblInterval.Location = New-Object System.Drawing.Point(300, 84)
$lblInterval.Size = New-Object System.Drawing.Size(105, 20)
$lblInterval.Text = "Interval seconds:"
$form.Controls.Add($lblInterval)

# Interval numeric input
$numInterval = New-Object System.Windows.Forms.NumericUpDown
$numInterval.Location = New-Object System.Drawing.Point(410, 80)
$numInterval.Size = New-Object System.Drawing.Size(70, 25)
$numInterval.Minimum = 5
$numInterval.Maximum = 3600
$numInterval.Value = [decimal]$config.IntervalSeconds
$form.Controls.Add($numInterval)

# Start button
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(15, 125)
$btnStart.Size = New-Object System.Drawing.Size(110, 35)
$btnStart.Text = "Start"
$form.Controls.Add($btnStart)

# Stop button
$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(130, 125)
$btnStop.Size = New-Object System.Drawing.Size(110, 35)
$btnStop.Text = "Stop"
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

# Minimize button
$btnMinimize = New-Object System.Windows.Forms.Button
$btnMinimize.Location = New-Object System.Drawing.Point(245, 125)
$btnMinimize.Size = New-Object System.Drawing.Size(140, 35)
$btnMinimize.Text = "Minimize to Tray"
$form.Controls.Add($btnMinimize)

# Countdown label
$lblCountdown = New-Object System.Windows.Forms.Label
$lblCountdown.Location = New-Object System.Drawing.Point(15, 180)
$lblCountdown.Size = New-Object System.Drawing.Size(510, 35)
$lblCountdown.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblCountdown.Text = "Refresh in: $($config.IntervalSeconds)s"
$form.Controls.Add($lblCountdown)

# Last refresh label
$lblLastRefresh = New-Object System.Windows.Forms.Label
$lblLastRefresh.Location = New-Object System.Drawing.Point(15, 220)
$lblLastRefresh.Size = New-Object System.Drawing.Size(510, 22)
$lblLastRefresh.Text = "Last Refresh: Never"
$form.Controls.Add($lblLastRefresh)

# Target info label
$lblTarget = New-Object System.Windows.Forms.Label
$lblTarget.Location = New-Object System.Drawing.Point(15, 245)
$lblTarget.Size = New-Object System.Drawing.Size(510, 22)
$lblTarget.Text = "Target: None"
$form.Controls.Add($lblTarget)

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 268)
$lblStatus.Size = New-Object System.Drawing.Size(510, 22)
$lblStatus.Text = "Status: Ready"
$lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($lblStatus)

# ------------------------------------------------------------
# Tray Icon
# ------------------------------------------------------------

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Visible = $true
$notifyIcon.Text = "Auto Refresh Dashboard"

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$restoreItem = New-Object System.Windows.Forms.ToolStripMenuItem
$restoreItem.Text = "Restore"

$startStopItem = New-Object System.Windows.Forms.ToolStripMenuItem
$startStopItem.Text = "Start/Stop"

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"

[void]$trayMenu.Items.Add($restoreItem)
[void]$trayMenu.Items.Add($startStopItem)
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

    if (-not (Validate-TargetWindow)) {
        $lblStatus.Text = "Status: Target window not found. Refresh stopped."
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
        $lblCountdown.Text = "Target window not found"
        Stop-AutoRefresh
        return
    }

    $script:Remaining--

    $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
    $notifyIcon.Text = "Refresh in: $($script:Remaining)s"

    if ($script:Remaining -le 0) {
        try {
            [void][Win32]::ShowWindow($script:TargetHwnd, 5) # SW_SHOW
            [void][Win32]::SetForegroundWindow($script:TargetHwnd)

            Start-Sleep -Milliseconds 250

            [System.Windows.Forms.SendKeys]::SendWait("{F5}")

            $lblLastRefresh.Text = "Last Refresh: $(Get-Date -Format 'hh:mm:ss tt')"

            Flash-Refresh
        }
        catch {
            $lblStatus.Text = "Status: Failed to send refresh: $($_.Exception.Message)"
            $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
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
        $lblStatus.Text = "Status: Running"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    }
})

$captureTimer = New-Object System.Windows.Forms.Timer
$captureTimer.Interval = 3000

$captureTimer.Add_Tick({
    $captureTimer.Stop()

    $hwnd = [Win32]::GetForegroundWindow()
    $title = Get-WindowTitleFromHandle -Handle $hwnd

    $matchingProcess = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -eq $hwnd } |
        Select-Object -First 1

    $processName = if ($matchingProcess) { $matchingProcess.ProcessName } else { "Unknown" }

    $form.Show()
    $form.WindowState = "Normal"
    $form.TopMost = $true
    $form.Activate()

    if ($hwnd -ne [IntPtr]::Zero -and -not [string]::IsNullOrWhiteSpace($title)) {
        Set-TargetWindow -Hwnd $hwnd -Title $title -ProcessName $processName
    }
    else {
        $lblStatus.Text = "Status: Could not capture active window"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
    }
})

# ------------------------------------------------------------
# Events
# ------------------------------------------------------------

$btnRefreshList.Add_Click({
    Load-Windows
    $lblStatus.Text = "Status: Window list refreshed"
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue
})

$chkEdgeOnly.Add_CheckedChanged({
    Load-Windows
    Save-Config
})

$cmbWindows.Add_SelectedIndexChanged({
    if ($cmbWindows.SelectedItem) {
        $item = $cmbWindows.SelectedItem
        Set-TargetWindow -Hwnd $item.Hwnd -Title $item.Title -ProcessName $item.ProcessName
    }
})

$numInterval.Add_ValueChanged({
    if (-not $script:Running) {
        $script:Remaining = [int]$numInterval.Value
        $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
    }

    Save-Config
})

$btnCaptureActive.Add_Click({
    $lblStatus.Text = "Status: Bring the target window to the front. Capturing in 3 seconds..."
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue

    $form.TopMost = $false
    $form.WindowState = "Minimized"

    $captureTimer.Start()
})

$btnStart.Add_Click({
    if (-not $cmbWindows.SelectedItem -and $script:TargetHwnd -eq [IntPtr]::Zero) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select a target window or use Capture Active Window first.",
            "No Target Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        return
    }

    if ($cmbWindows.SelectedItem -and $script:TargetHwnd -eq [IntPtr]::Zero) {
        $item = $cmbWindows.SelectedItem
        Set-TargetWindow -Hwnd $item.Hwnd -Title $item.Title -ProcessName $item.ProcessName
    }

    if (-not (Validate-TargetWindow)) {
        [System.Windows.Forms.MessageBox]::Show(
            "The selected target window is no longer available. Refresh the list or capture the active window again.",
            "Target Window Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        return
    }

    $script:Remaining = [int]$numInterval.Value
    $script:Running = $true

    $timer.Start()

    $btnStart.Enabled = $false
    $btnStop.Enabled = $true

    $lblCountdown.Text = "Refresh in: $($script:Remaining)s"
    $lblStatus.Text = "Status: Running"
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen

    Save-Config
})

$btnStop.Add_Click({
    Stop-AutoRefresh
})

$btnMinimize.Add_Click({
    $form.Hide()
    $notifyIcon.ShowBalloonTip(
        1500,
        "Auto Refresh Dashboard",
        "Still running in the system tray.",
        [System.Windows.Forms.ToolTipIcon]::Info
    )
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
# Initial Load
# ------------------------------------------------------------

Load-Windows

# If the remembered selected item was loaded, sync target state.
if ($cmbWindows.SelectedItem) {
    $item = $cmbWindows.SelectedItem
    Set-TargetWindow -Hwnd $item.Hwnd -Title $item.Title -ProcessName $item.ProcessName
}

[void]$form.ShowDialog()