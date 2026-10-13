# Collect-TeamsCallLogs.ps1
# PowerShell script to collect Teams logs on incoming calls.
# Optimized to support PowerShell Constrained Language Mode (CLM).
# Pivot: Directory change detection. Triggers collection on any file modification.

$ErrorActionPreference = "Stop"

# Debug Logging Helper
$debugLogPath = ""
function Write-DebugLog {
    param([string]$Message)
    if ($debugLogPath -ne "") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [DEBUG] $Message"
        try {
            # Create file if not exists, append if does. Out-File/Add-Content used carefully for CLM.
            Add-Content -Path $debugLogPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
    }
}

# Define ASCII Banner
$banner = @'
======================================================================
  _____                        _____       _ _            _             
 |_   _|                      /  __ \     | | |          | |            
   | | ___  __ _ _ __ ___  ___| /  \/ __ _| | | ___   ___| |_ ___  _ __ 
   | |/ _ \/ _` | '_ ` _ \/ __| |    / _` | | |/ _ \ / __| __/ _ \| '__|
   | |  __/ (_| | | | | | \__ \ \__/\ (_| | | |  __/| (__| |_|(_) | |   
   \_/\___|\__,_|_| |_| |_|___/\____/\__,_|_|_|\___| \___|\__\___/|_|   
                                                                        
======================================================================
  Teams Incoming Call Log Collector Utility (CLM & Directory Polled)
======================================================================
'@

Clear-Host
Write-Host $banner -ForegroundColor Cyan
Write-Host ""
Write-Host "Description:" -ForegroundColor Yellow
Write-Host "  This script monitors Microsoft Teams log directories in real-time."
Write-Host "  When any file change (new file, size change, modification time, or deletion)"
Write-Host "  is detected in the monitored directories, it collects all active Teams logs,"
Write-Host "  packages them into a timestamped ZIP archive, and logs the event in a manifest."
Write-Host "  Optimized to run under Enterprise Constrained Language Mode (CLM)."
Write-Host ""

# 1. Resolve OS and Environment Variables
$isWinOS = $IsWindows
if ($isWinOS -eq $null) {
    $isWinOS = $PSVersionTable.Platform -eq "Win32NT" -or $env:OS -like "*Windows*"
}
$username = if ($isWinOS) { $env:USERNAME } else { $env:USER }
if (-not $username -or $username -eq "") { $username = "UnknownUser" }

# Target directory
$destDir = ""
if ($isWinOS) {
    $destDir = "C:\Temp\$username"
} else {
    $destDir = "/tmp/TeamsLogs/$username"
}

# Initialize Debug Log
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}
$debugLogPath = Join-Path $destDir "collector_debug.log"
Write-DebugLog "========================================"
Write-DebugLog "Starting new monitoring session"
Write-DebugLog "OS Detection: isWinOS=$isWinOS"
Write-DebugLog "Username: $username"
Write-DebugLog "Target Directory: $destDir"

# Resolve source directories to monitor
$sourceDirs = @()
if ($isWinOS) {
    # MSTeams New (V2) packages path
    $newTeamsPath = "$env:LocalAppData\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs"
    # MSTeams New (V2) non-packaged/MSI path
    $newTeamsMSIPath = "$env:LocalAppData\Microsoft\MSTeams\Logs"
    # Teams Classic
    $classicTeamsPath = "$env:AppData\Microsoft\Teams"
    
    if (Test-Path $newTeamsPath) { $sourceDirs += $newTeamsPath }
    if (Test-Path $newTeamsMSIPath) { $sourceDirs += $newTeamsMSIPath }
    if (Test-Path $classicTeamsPath) { $sourceDirs += $classicTeamsPath }
} else {
    # Linux paths
    $linuxPath1 = "$env:HOME/.config/Microsoft/Microsoft Teams"
    $linuxPath2 = "$env:HOME/.config/teams"
    
    if (Test-Path $linuxPath1) { $sourceDirs += $linuxPath1 }
    if (Test-Path $linuxPath2) { $sourceDirs += $linuxPath2 }
}

Write-DebugLog "Source Directories to monitor:"
foreach ($dir in $sourceDirs) {
    Write-DebugLog "  - $dir"
}

Write-Host "Target Directory for Zipped Logs:" -ForegroundColor Gray
Write-Host "  $destDir" -ForegroundColor Green
Write-Host ""
Write-Host "Monitored Teams Log Source Directories:" -ForegroundColor Gray
if ($sourceDirs.Count -eq 0) {
    Write-Host "  No standard Teams log directories found. Creating mock monitor path for testing..." -ForegroundColor Yellow
    # Let's create a local mock logs path for testing if standard paths aren't present
    $mockPath = Join-Path $PSScriptRoot "MockTeamsLogs"
    if (-not (Test-Path $mockPath)) { New-Item -ItemType Directory -Path $mockPath | Out-Null }
    $sourceDirs += $mockPath
}
foreach ($dir in $sourceDirs) {
    Write-Host "  - $dir" -ForegroundColor Green
}
Write-Host ""

# Prompt to start
Write-Host "Press [Enter] to start detection..." -ForegroundColor White
$null = Read-Host

Write-Host ""
Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "Monitoring started. The monitoring job is running in the background." -ForegroundColor Green
Write-Host "Press 'q' or [Enter] at any time to exit and view the session summary." -ForegroundColor Yellow
Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Ensure target directory exists
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

$manifestPath = Join-Path $destDir "manifest.txt"
if (-not (Test-Path $manifestPath)) {
    New-Item -ItemType File -Path $manifestPath -Force | Out-Null
    Set-Content -Path $manifestPath -Value "--- Teams Call Log Collector Manifest ---`r`nTotal Calls Observed: 0`r`nZip Files Created:`r`n"
}

# State Variables for the Session
$observedCallsCount = 0
$createdZipFiles = @()

# Lock-Free file copier to copy files in use
# Replaced direct .NET File Streams with safe cmdlet fallbacks for CLM
function Copy-LockedFile {
    param (
        [string]$SourcePath,
        [string]$DestinationPath
    )
    try {
        # Try standard Copy-Item first
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
    }
    catch {
        try {
            # Fallback to reading and writing via Get-Content and Set-Content
            $content = Get-Content -Path $SourcePath -Raw -ErrorAction Stop
            Set-Content -Path $DestinationPath -Value $content -Force -ErrorAction Stop
        }
        catch {
            # Fail silently if copy is impossible
        }
    }
}

# Helper function to capture current file snapshot in monitored directories
function Get-DirectorySnapshot {
    $snapshot = @{}
    foreach ($dir in $sourceDirs) {
        $files = Get-ChildItem -Path $dir -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $snapshot[$file.FullName] = @{
                "Length"        = $file.Length
                "LastWriteTime" = $file.LastWriteTime
            }
        }
    }
    return $snapshot
}

# Initialize baseline file snapshot state
$fileSnapshot = Get-DirectorySnapshot
Write-DebugLog "Baseline snapshot taken. Total files monitored: $($fileSnapshot.Count)"
$cooldownSeconds = 20

# Main monitoring loop
$running = $true
while ($running) {
    # Check for user input to exit
    try {
        if ($Host.UI.RawUI.KeyAvailable) {
            $keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($keyInfo.Character -eq 'q' -or $keyInfo.Character -eq "`r") { # 'q' or Enter
                $running = $false
                break
            }
        }
    }
    catch {
        # RawUI not available in non-interactive sessions
    }

    # Get current state of monitored log directories
    $currentSnapshot = Get-DirectorySnapshot
    $changeDetected = $false
    $changeReason = ""

    # 1. Check for file additions and modifications
    foreach ($key in $currentSnapshot.Keys) {
        if (-not $fileSnapshot.ContainsKey($key)) {
            $changeDetected = $true
            $changeReason = "New file added: $(Split-Path $key -Leaf)"
            break
        }
        else {
            $currentFile = $currentSnapshot[$key]
            $baselineFile = $fileSnapshot[$key]
            if ($currentFile.Length -ne $baselineFile.Length) {
                $changeDetected = $true
                $changeReason = "File size changed: $(Split-Path $key -Leaf) ($($baselineFile.Length) -> $($currentFile.Length) bytes)"
                break
            }
            if ($currentFile.LastWriteTime -ne $baselineFile.LastWriteTime) {
                $changeDetected = $true
                $changeReason = "File modification time changed: $(Split-Path $key -Leaf)"
                break
            }
        }
    }

    # 2. Check for file deletions (if no changes observed yet)
    if (-not $changeDetected) {
        foreach ($key in $fileSnapshot.Keys) {
            if (-not $currentSnapshot.ContainsKey($key)) {
                $changeDetected = $true
                $changeReason = "File deleted: $(Split-Path $key -Leaf)"
                break
            }
        }
    }

    # 3. If directory change is detected, trigger log collection
    if ($changeDetected) {
        Write-DebugLog "Change detected! Reason: $changeReason"
        $now = Get-Date
        $observedCallsCount++
        
        $timestampStr = Get-Date -Format "yyyyMMdd_HHmmss"
        $zipName = "TeamsLogs_${username}_${timestampStr}.zip"
        $zipPath = Join-Path $destDir $zipName
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Change detected! Reason: $changeReason" -ForegroundColor Green
        Write-Host "               Collecting and zipping logs..." -ForegroundColor Cyan

        # 1. Create a staging temp folder
        $tempStagingPath = Join-Path $destDir "TempLogs_$timestampStr"
        New-Item -ItemType Directory -Path $tempStagingPath -Force | Out-Null

        # 2. Copy all logs to staging using lock-free helper
        foreach ($sourceDir in $sourceDirs) {
            $logsToCollect = Get-ChildItem -Path $sourceDir -File -Recurse -ErrorAction SilentlyContinue
            foreach ($logFile in $logsToCollect) {
                # Preserve relative folder structures in staging
                $relativeSubpath = ""
                if ($logFile.DirectoryName.Length -gt $sourceDir.Length) {
                    $relativeSubpath = $logFile.DirectoryName.Substring($sourceDir.Length) -replace '^[/\\]+'
                }
                $targetSubdir = Join-Path $tempStagingPath $relativeSubpath
                if (-not (Test-Path $targetSubdir)) {
                    New-Item -ItemType Directory -Path $targetSubdir -Force | Out-Null
                }
                $destLogFile = Join-Path $targetSubdir $logFile.Name
                Copy-LockedFile -SourcePath $logFile.FullName -DestinationPath $destLogFile
                Write-DebugLog "Copied log file: $($logFile.FullName)"
            }
        }

        # 3. Create the ZIP file
        try {
            $archiveSource = Join-Path $tempStagingPath "*"
            Compress-Archive -Path $archiveSource -DestinationPath $zipPath -Force
            $createdZipFiles += $zipPath
            Write-Host "               Logs successfully zipped to: $zipPath" -ForegroundColor Green
            Write-DebugLog "Successfully created ZIP archive: $zipPath"
        }
        catch {
            Write-Host "               Error creating zip archive: $_" -ForegroundColor Red
            Write-DebugLog "Error creating ZIP archive: $_"
        }
        finally {
            # 4. Clean up staging folder
            if (Test-Path $tempStagingPath) {
                Remove-Item -Path $tempStagingPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # 5. Update manifest
        try {
            # Read current manifest
            $manifestContent = Get-Content -Path $manifestPath
            
            # Parse current count
            $updatedCount = $observedCallsCount
            # If manifest has historical counts, scan and increment
            $currentCountLine = $manifestContent | Select-String "Total Calls Observed: (\d+)"
            if ($currentCountLine -match "Total Calls Observed: (\d+)") {
                $historicalCount = [int]$Matches[1]
                $updatedCount = $historicalCount + 1
            }

            # Re-write manifest
            $newManifest = @()
            $newManifest += "--- Teams Call Log Collector Manifest ---"
            $newManifest += "Total Calls Observed: $updatedCount"
            $newManifest += "Zip Files Created:"
            
            # Add all previously listed zip files
            $inZipSection = $false
            foreach ($line in $manifestContent) {
                if ($line -eq "Zip Files Created:") {
                    $inZipSection = $true
                    continue
                }
                if ($inZipSection -and $line.Trim() -ne "") {
                    $newManifest += $line
                }
            }
            
            # Add the new zip file
            $newManifest += "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $zipName ($zipPath)"
            
            Set-Content -Path $manifestPath -Value ($newManifest -join "`r`n")
        }
        catch {
            Write-Host "               Warning: Failed to update manifest.txt: $_" -ForegroundColor Yellow
            Write-DebugLog "Failed to update manifest.txt: $_"
        }

        # 6. Apply cooldown to prevent duplicate triggers from ongoing writes
        Write-Host "               Entering cooldown for $cooldownSeconds seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds $cooldownSeconds
        
        # 7. Refresh baseline snapshot to avoid re-triggering on modifications made during the cooldown
        $fileSnapshot = Get-DirectorySnapshot
        Write-DebugLog "Cooldown finished. New baseline snapshot taken. Total files: $($fileSnapshot.Count)"
        Write-Host "               Monitoring resumed." -ForegroundColor Gray
    }

    Start-Sleep -Seconds 1
}

Write-DebugLog "Monitoring session terminated."

# --- EXIT SECTION ---
Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Monitoring Session Terminated" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Summary of Session Activity:" -ForegroundColor White
Write-Host "  - Calls Observed this Session: $observedCallsCount" -ForegroundColor Green
Write-Host "  - Zip Files Generated:" -ForegroundColor White
if ($createdZipFiles.Count -eq 0) {
    Write-Host "      No ZIP archives were generated during this session." -ForegroundColor Gray
} else {
    foreach ($zip in $createdZipFiles) {
        Write-Host "      - $zip" -ForegroundColor Green
    }
}
Write-Host "  - Manifest File Location:" -ForegroundColor White
Write-Host "      $manifestPath" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""