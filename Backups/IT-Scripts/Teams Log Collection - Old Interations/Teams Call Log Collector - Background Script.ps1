# =========================================
# Teams Call Log Collector - Stable Version
# =========================================

# Logged-in user
$UserName = $env:USERNAME

# Destination root
$DestinationRoot = 'C:\Temp\TeamsLogs'

# Call-related source paths
$MediaStackPath = Join-Path $env:APPDATA 'Microsoft\Teams\media-stack'
$SkyLibPath     = Join-Path $env:APPDATA 'Microsoft\Teams\skylib'
$DebugLogPath   = Join-Path $env:APPDATA 'Microsoft\Teams\logs.txt'

# Ensure destination exists
if (!(Test-Path $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

# =========================================
# USER PROMPT
# =========================================

Write-Host ''
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host 'Microsoft Teams Call Log Collection Tool' -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'This tool will collect Microsoft Teams CALL logs only.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'The process will run in the background.' -ForegroundColor Green
Write-Host 'No further action is required once it starts.' -ForegroundColor Green
Write-Host ''
Write-Host 'Logs will be saved to:' -ForegroundColor White
Write-Host 'C:\Temp\TeamsLogs' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Press ENTER to begin logging...' -ForegroundColor Magenta

Read-Host | Out-Null

Write-Host ''
Write-Host 'Call log collection started successfully.' -ForegroundColor Green
Write-Host 'You may close this window. Logging continues in the background.' -ForegroundColor Green

Start-Sleep -Seconds 3
Clear-Host

# =========================================
# Function to copy call-related logs
# =========================================

function Copy-TeamsCallLogs {

    $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $FolderName = $UserName + '-CALLLOGSONLY-' + $Timestamp
    $Destination = Join-Path $DestinationRoot $FolderName

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    # -------- Copy media-stack logs --------
    if (Test-Path $MediaStackPath) {
        Get-ChildItem -Path $MediaStackPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $SafeName = ($_.Name -replace '[^a-zA-Z0-9\.\-_]', '_')
                $NewFileName = $UserName + '_CALLLOG_' + $SafeName
                $DestFile = Join-Path $Destination $NewFileName

                Copy-Item $_.FullName -Destination $DestFile -Force -ErrorAction Stop
            }
            catch {}
        }
    }

    # -------- Copy skylib logs --------
    if (Test-Path $SkyLibPath) {
        Get-ChildItem -Path $SkyLibPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $SafeName = ($_.Name -replace '[^a-zA-Z0-9\.\-_]', '_')
                $NewFileName = $UserName + '_CALLLOG_' + $SafeName
                $DestFile = Join-Path $Destination $NewFileName

                Copy-Item $_.FullName -Destination $DestFile -Force -ErrorAction Stop
            }
            catch {}
        }
    }

    # -------- Copy main debug log (for timestamps / correlation) --------
    if (Test-Path $DebugLogPath) {
        try {
            $SafeName = ('logs.txt' -replace '[^a-zA-Z0-9\.\-_]', '_')
            $NewFileName = $UserName + '_CALLLOG_' + $SafeName
            $DestFile = Join-Path $Destination $NewFileName

            Copy-Item $DebugLogPath -Destination $DestFile -Force -ErrorAction Stop
        }
        catch {}
    }
}

# =========================================
# Background Loop
# =========================================

while ($true) {

    Copy-TeamsCallLogs

    # Run every 5 minutes
    Start-Sleep -Seconds 300
}