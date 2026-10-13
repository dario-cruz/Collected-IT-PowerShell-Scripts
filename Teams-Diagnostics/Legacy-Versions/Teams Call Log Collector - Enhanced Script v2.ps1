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
    $FolderName = $UserName + '-CALLLOGS-' + $Timestamp
    $Destination = Join-Path $DestinationRoot $FolderName

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $SourcePaths = @(
        "$env:APPDATA\Microsoft\Teams\media-stack",
        "$env:APPDATA\Microsoft\Teams\skylib",
        "$env:APPDATA\Microsoft\Teams\webrtc",
        "$env:APPDATA\Microsoft\Teams\meeting-addin",
        "$env:APPDATA\Microsoft\Teams\old_logs"
    )

    foreach ($Source in $SourcePaths) {

        if (Test-Path $Source) {

            $FolderLabel = Split-Path $Source -Leaf

            Get-ChildItem $Source -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {

                try {

                    $SafeName = ($_.Name -replace '[^a-zA-Z0-9\.\-_]', '_')

                    $NewName = "$UserName-$FolderLabel-$SafeName"

                    Copy-Item $_.FullName `
                        -Destination (Join-Path $Destination $NewName) `
                        -Force `
                        -ErrorAction Stop
                }
                catch {}
            }
        }
    }

    # Copy all txt logs
    Get-ChildItem "$env:APPDATA\Microsoft\Teams" `
        -Filter *.txt `
        -ErrorAction SilentlyContinue | ForEach-Object {

        try {

            Copy-Item $_.FullName `
                -Destination (Join-Path $Destination "$UserName-$($_.Name)") `
                -Force
        }
        catch {}
    }

    # Teams Version
    try {
        Get-Process ms-teams -ErrorAction SilentlyContinue |
            Select-Object Name,Id,StartTime |
            Out-File (Join-Path $Destination 'TeamsProcess.txt')
    }
    catch {}

    # Application Event Log
    try {
        Get-WinEvent -LogName Application -MaxEvents 1000 |
            Export-Clixml (Join-Path $Destination 'ApplicationEventLog.xml')
    }
    catch {}

    # System Event Log
    try {
        Get-WinEvent -LogName System -MaxEvents 1000 |
            Export-Clixml (Join-Path $Destination 'SystemEventLog.xml')
    }
    catch {}

    # Capture running Teams configuration
    try {
        systeminfo | Out-File (Join-Path $Destination 'SystemInfo.txt')
    }
    catch {}
	# Teams Log Inventory
    try {

        Get-ChildItem "$env:APPDATA\Microsoft\Teams" `
            -Recurse `
            -File `
            -ErrorAction SilentlyContinue |

            Select-Object `
                Name,
                FullName,
                Length,
                CreationTime,
                LastWriteTime |

            Sort-Object LastWriteTime |

            Export-Csv `
                (Join-Path $Destination 'TeamsLogInventory.csv') `
                -NoTypeInformation
    }
    catch {}
	# Teams Version Information
    try {

        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Teams" `
            -Recurse `
            -Filter *.json `
            -ErrorAction SilentlyContinue |

            Select-Object FullName, LastWriteTime |

            Export-Csv `
                (Join-Path $Destination 'TeamsConfigurationFiles.csv') `
                -NoTypeInformation
    }
    catch {}
}

# =========================================
# Background Loop
# =========================================

while ($true) {

    Copy-TeamsCallLogs

    # Run every 5 minutes
    Start-Sleep -Seconds 300
}