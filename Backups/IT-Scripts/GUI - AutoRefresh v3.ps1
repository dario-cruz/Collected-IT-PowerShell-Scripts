# Save current foreground window
$currentWindow = [Win32]::GetForegroundWindow()

# Refresh target window
[Win32]::SetForegroundWindow($script:TargetHwnd)
Start-Sleep -Milliseconds 100
[System.Windows.Forms.SendKeys]::SendWait("{F5}")

# Restore user's original window
if ($currentWindow -ne [IntPtr]::Zero) {
    [Win32]::SetForegroundWindow($currentWindow)
}