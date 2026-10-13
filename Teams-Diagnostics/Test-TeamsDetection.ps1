# Test-TeamsDetection.ps1
# Diagnostic script to capture file system changes during a Microsoft Teams call

$ErrorActionPreference = "Continue"
$isWinOS = $IsWindows
if ($null -eq $isWinOS) {
    $isWinOS = $PSVersionTable.Platform -eq "Win32NT" -or $env:OS -like "*Windows*"
}

if (-not $isWinOS) {
    Write-Host "This diagnostic script is intended for Windows enterprise machines." -ForegroundColor Red
    exit
}

$username = $env:USERNAME
$desktopPath = [Environment]::GetFolderPath("Desktop")
$outLogPath = Join-Path $desktopPath "teams_detection_debug.txt"

function Write-Out {
    param([string]$Message, [ConsoleColor]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $outLogPath -Value $Message
}

# Clear previous log
if (Test-Path $outLogPath) { Remove-Item $outLogPath -Force }

Write-Out "==================================================" "Cyan"
Write-Out " Teams Log Detection Diagnostic Tool " "Cyan"
Write-Out "==================================================" "Cyan"

# 1. Environment Dump
Write-Out "`n[1] Environment Information" "Yellow"
Write-Out "--------------------------------------------------"
Write-Out "OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Out "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Out "Language Mode: $($ExecutionContext.SessionState.LanguageMode)"

# 2. FileSystemWatcher Test
Write-Out "`n[2] FileSystemWatcher Availability Test" "Yellow"
Write-Out "--------------------------------------------------"
try {
    $watcher = New-Object System.IO.FileSystemWatcher
    Write-Out "SUCCESS: System.IO.FileSystemWatcher can be instantiated." "Green"
    $watcher.Dispose()
} catch {
    Write-Out "FAILED: System.IO.FileSystemWatcher cannot be instantiated (likely blocked by Constrained Language Mode or execution policy)." "Red"
    Write-Out "Error Details: $_" "Red"
}

# 3. Path Verification
Write-Out "`n[3] Teams Path Verification" "Yellow"
Write-Out "--------------------------------------------------"
$searchPaths = @(
    "$env:LocalAppData\Microsoft\MSTeams", # Expanded broad search
    "$env:LocalAppData\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams",
    "$env:AppData\Microsoft\Teams"
)

$validPaths = @()
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        Write-Out "FOUND: $path" "Green"
        $validPaths += $path
    } else {
        Write-Out "NOT FOUND: $path" "Gray"
    }
}

if ($validPaths.Count -eq 0) {
    Write-Out "CRITICAL: No known Teams directories found." "Red"
    exit
}

# 4. Snapshot 1
Write-Out "`n[4] Capturing Initial File State..." "Yellow"
Write-Out "--------------------------------------------------"
$snapshot1 = @{}
foreach ($dir in $validPaths) {
    Write-Out "Scanning $dir ..." "Gray"
    $files = Get-ChildItem -Path $dir -File -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $snapshot1[$file.FullName] = @{
            "Length" = $file.Length
            "LastWriteTime" = $file.LastWriteTime
        }
    }
}
Write-Out "Captured $($snapshot1.Count) total files in baseline." "White"

# 5. The Test
Write-Out "`n[5] Action Required!" "Yellow"
Write-Out "--------------------------------------------------"
Write-Out "1. Please initiate or receive a test call in Microsoft Teams." "Cyan"
Write-Out "2. Let the call ring or pick it up." "Cyan"
Write-Out "3. After the call is established/missed, return here and press ENTER." "Cyan"
Write-Host "Press [Enter] when ready to take the post-call snapshot..." -ForegroundColor White
$null = Read-Host

# 6. Snapshot 2 and Comparison
Write-Out "`n[6] Capturing Post-Call State & Comparing..." "Yellow"
Write-Out "--------------------------------------------------"
$snapshot2 = @{}
foreach ($dir in $validPaths) {
    $files = Get-ChildItem -Path $dir -File -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $snapshot2[$file.FullName] = @{
            "Length" = $file.Length
            "LastWriteTime" = $file.LastWriteTime
        }
    }
}

$changesFound = 0
Write-Out "`n--- Changes Detected ---" "Cyan"

# Check for additions and modifications
foreach ($key in $snapshot2.Keys) {
    if (-not $snapshot1.ContainsKey($key)) {
        Write-Out "[NEW] $key" "Green"
        $changesFound++
    } else {
        $file1 = $snapshot1[$key]
        $file2 = $snapshot2[$key]
        if ($file1.Length -ne $file2.Length -or $file1.LastWriteTime -ne $file2.LastWriteTime) {
            Write-Out "[MODIFIED] $key" "Yellow"
            Write-Out "    Size: $($file1.Length) -> $($file2.Length) bytes" "Gray"
            Write-Out "    Time: $($file1.LastWriteTime) -> $($file2.LastWriteTime)" "Gray"
            $changesFound++
        }
    }
}

# Check for deletions
foreach ($key in $snapshot1.Keys) {
    if (-not $snapshot2.ContainsKey($key)) {
        Write-Out "[DELETED] $key" "Red"
        $changesFound++
    }
}

if ($changesFound -eq 0) {
    Write-Out "NO CHANGES DETECTED in the monitored directories during the test window." "Red"
} else {
    Write-Out "Total changes observed: $changesFound" "Green"
}

Write-Out "`n==================================================" "Cyan"
Write-Out "Diagnostic complete. Please share the file located at:" "White"
Write-Out $outLogPath "Green"
Write-Out "==================================================" "Cyan"