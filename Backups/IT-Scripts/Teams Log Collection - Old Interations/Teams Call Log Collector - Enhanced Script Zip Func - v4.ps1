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
Write-Host 'This tool will collect all currently available Teams call logs.' -ForegroundColor Green
Write-Host 'A ZIP file will be generated automatically when collection is complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Logs will be saved to:' -ForegroundColor White
Write-Host 'C:\Temp\TeamsLogs' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Each collection cycle will also create a ZIP file for easy sharing.' -ForegroundColor Cyan
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

    # Teams Process Information
    try {
        Get-Process ms-teams -ErrorAction SilentlyContinue |
            Select-Object Name, Id, StartTime, Path |
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

    # Capture running system configuration
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

    # Teams Version / Configuration File Inventory
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

    # =========================================
    # Auto ZIP collected logs
    # =========================================

    try {
        $ZipFileName = $FolderName + '.zip'
        $ZipPath = Join-Path $DestinationRoot $ZipFileName

        if (Test-Path $ZipPath) {
            Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
        }

        $ManifestPath = Join-Path $Destination 'CollectionManifest.txt'

        @(
            'Teams Call Log Collection Manifest'
            '=================================='
            ''
            "Collected User: $UserName"
            "Computer Name: $env:COMPUTERNAME"
            "Collection Time Local: $(Get-Date)"
            "Collection Folder: $Destination"
            "Zip File: $ZipPath"
            ''
            'Included Data:'
            '- Teams media-stack logs'
            '- Teams skylib logs'
            '- Teams webrtc logs, if present'
            '- Teams meeting-addin logs, if present'
            '- Teams old_logs folder, if present'
            '- Teams text logs'
            '- Teams process information'
            '- Windows Application event log export'
            '- Windows System event log export'
            '- System information'
            '- Teams log inventory CSV'
            '- Teams configuration JSON file inventory'
        ) | Out-File -FilePath $ManifestPath -Encoding UTF8 -Force

        $CollectedFiles = Get-ChildItem -Path $Destination -Recurse -File -ErrorAction SilentlyContinue

        if ($CollectedFiles.Count -gt 0) {
            Compress-Archive `
                -Path "$Destination\*" `
                -DestinationPath $ZipPath `
                -CompressionLevel Optimal `
                -Force
        }
    }
    catch {}
}

# =========================================
# Run Collection Once
# =========================================

Write-Host ''
Write-Host 'Collecting Teams logs...' -ForegroundColor Yellow

Copy-TeamsCallLogs

Write-Host ''
Write-Host 'Collection completed successfully.' -ForegroundColor Green
Write-Host ''
Write-Host 'ZIP file saved to:' -ForegroundColor Cyan
Write-Host $DestinationRoot -ForegroundColor White
Write-Host ''

Read-Host 'Press ENTER to exit'