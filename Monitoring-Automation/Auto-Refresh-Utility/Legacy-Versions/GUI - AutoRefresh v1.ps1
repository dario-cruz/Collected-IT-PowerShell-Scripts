Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Auto Refresh Dashboard"
$form.Size = New-Object System.Drawing.Size(400,220)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Window Selection
$lblWindow = New-Object System.Windows.Forms.Label
$lblWindow.Location = New-Object System.Drawing.Point(10,20)
$lblWindow.Size = New-Object System.Drawing.Size(100,20)
$lblWindow.Text = "Target Window:"
$form.Controls.Add($lblWindow)

$cmbWindows = New-Object System.Windows.Forms.ComboBox
$cmbWindows.Location = New-Object System.Drawing.Point(120,18)
$cmbWindows.Size = New-Object System.Drawing.Size(250,20)
$form.Controls.Add($cmbWindows)

# Refresh Window List Button
$btnRefreshList = New-Object System.Windows.Forms.Button
$btnRefreshList.Location = New-Object System.Drawing.Point(10,50)
$btnRefreshList.Size = New-Object System.Drawing.Size(100,25)
$btnRefreshList.Text = "Refresh List"
$form.Controls.Add($btnRefreshList)

# Start Button
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(120,50)
$btnStart.Size = New-Object System.Drawing.Size(100,25)
$btnStart.Text = "Start"
$form.Controls.Add($btnStart)

# Stop Button
$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(230,50)
$btnStop.Size = New-Object System.Drawing.Size(100,25)
$btnStop.Text = "Stop"
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

# Countdown Label
$lblCountdown = New-Object System.Windows.Forms.Label
$lblCountdown.Location = New-Object System.Drawing.Point(10,100)
$lblCountdown.Size = New-Object System.Drawing.Size(360,30)
$lblCountdown.Font = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$lblCountdown.Text = "Refresh in: 30s"
$form.Controls.Add($lblCountdown)

# Last Refresh Label
$lblLastRefresh = New-Object System.Windows.Forms.Label
$lblLastRefresh.Location = New-Object System.Drawing.Point(10,140)
$lblLastRefresh.Size = New-Object System.Drawing.Size(360,20)
$lblLastRefresh.Text = "Last Refresh: Never"
$form.Controls.Add($lblLastRefresh)

# Populate Window List
function Load-Windows {
    $cmbWindows.Items.Clear()

    Get-Process |
        Where-Object { $_.MainWindowTitle -ne "" } |
        Sort-Object MainWindowTitle |
        ForEach-Object {
            $cmbWindows.Items.Add($_.MainWindowTitle) | Out-Null
        }
}

Load-Windows

$btnRefreshList.Add_Click({
    Load-Windows
})

# Win32 API for window activation
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

# Timer
$script:Remaining = 30
$script:Running = $false

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000

$timer.Add_Tick({

    if (-not $script:Running) { return }

    $script:Remaining--

    $lblCountdown.Text = "Refresh in: $($script:Remaining)s"

    if ($script:Remaining -le 0) {

        $windowTitle = $cmbWindows.SelectedItem

        if ($windowTitle) {

            $target = Get-Process |
                      Where-Object {$_.MainWindowTitle -eq $windowTitle} |
                      Select-Object -First 1

            if ($target) {

                [WinAPI]::SetForegroundWindow($target.MainWindowHandle) | Out-Null
                Start-Sleep -Milliseconds 500

                [System.Windows.Forms.SendKeys]::SendWait("{F5}")

                $lblLastRefresh.Text = "Last Refresh: $(Get-Date -Format 'hh:mm:ss tt')"
            }
        }

        $script:Remaining = 30
    }
})

# Start Button Logic
$btnStart.Add_Click({

    if (-not $cmbWindows.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select a browser window first."
        )
        return
    }

    $script:Remaining = 30
    $script:Running = $true

    $timer.Start()

    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
})

# Stop Button Logic
$btnStop.Add_Click({

    $script:Running = $false

    $btnStart.Enabled = $true
    $btnStop.Enabled = $false

    $lblCountdown.Text = "Stopped"
})

[void]$form.ShowDialog()