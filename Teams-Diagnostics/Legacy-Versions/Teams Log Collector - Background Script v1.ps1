# =========================================
# Teams Log Collector - Stable Version
# =========================================

# Logged-in user
$UserName = $env:USERNAME

# Source paths
$TeamsPaths = @(
    "$env:APPDATA\Microsoft\Teams",
    "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"
)

# Destination root
$DestinationRoot = 'C:\Temp\TeamsLogs'

# Ensure destination exists
if (!(Test-Path $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

# =========================================
# USER PROMPT (SAFE QUOTING)
# =========================================

Write-Host ''
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host 'Microsoft Teams Log Collection Tool' -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'This tool will begin collecting Microsoft Teams logs from your computer.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'The process will run in the background.' -ForegroundColor Green
Write-Host 'No further action is required once it starts.' -ForegroundColor Green
Write-Host ''
Write-Host 'Logs will be saved to:' -ForegroundColor White
Write-Host 'C:\Temp\TeamsLogs' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Press ENTER to begin logging...' -ForegroundColor Magenta

Read-Host

Write-Host ''
Write-Host 'Logging has started successfully.' -ForegroundColor Green
Write-Host 'You may close this window. Logging will continue in the background.' -ForegroundColor Green

Start-Sleep -Seconds 3
Clear-Host

# =========================================
# Function to copy logs
# =========================================

function Copy-TeamsLogs {

    foreach ($Path in $TeamsPaths) {

        if (Test-Path $Path) {

            # Timestamp folder
            $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
            $FolderName = $UserName + '-' + $Timestamp
            $Destination = Join-Path $DestinationRoot $FolderName

            New-Item -ItemType Directory -Path $Destination -Force | Out-Null

            # File types to collect
            $FilesToCopy = @(
                '*.txt',
                '*.log',
                '*.etl',
                '*.json'
            )

            foreach ($Pattern in $FilesToCopy) {

                Get-ChildItem -Path $Path -Recurse -Filter $Pattern -ErrorAction SilentlyContinue | ForEach-Object {

                    try {
                        # Sanitize filename (prevents edge-case failures)
                        $SafeName = ($_.Name -replace '[^a-zA-Z0-9\.\-_]', '_')

                        # Append username safely
                        $NewFileName = $UserName + '_' + $SafeName
                        $DestFile = Join-Path $Destination $NewFileName

                        Copy-Item $_.FullName -Destination $DestFile -Force -ErrorAction Stop
                    }
                    catch {
                        # Skip locked or in-use files
                    }
                }
            }
        }
    }
}

# =========================================
# Background Loop
# =========================================

while ($true) {

    Copy-TeamsLogs

    # Run every 5 minutes
    Start-Sleep -Seconds 300
}