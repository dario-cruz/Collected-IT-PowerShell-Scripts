function Export-UsbDeviceListToCsv {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    # Get only USB devices
    $devices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object {
        $_.DeviceID -like 'USB\*'
    }

    # Write CSV header
    "DeviceID,Name" | Out-File -FilePath $FileName -Encoding UTF8 -Force

    # Write each device as a CSV row
    foreach ($device in $devices) {
        $DeviceID = ""
        $DeviceName = ""

        if ($device.DeviceID) {
            $DeviceID = $device.DeviceID -replace ',', ';'
        }

        if ($device.Name) {
            $DeviceName = $device.Name -replace ',', ';'
        }

        "$DeviceID,$DeviceName" | Out-File -FilePath $FileName -Encoding UTF8 -Append
    }

    Write-Host "CSV file created: $FileName" -ForegroundColor Green
}

function Compare-UsbDeviceLists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BaselineFile,

        [Parameter(Mandatory = $true)]
        [string]$SecondFile,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    # Import the CSV files
    $baselineDevices = Import-Csv -Path $BaselineFile
    $secondDevices   = Import-Csv -Path $SecondFile

    # Build a list of baseline DeviceIDs
    $baselineIds = @()
    foreach ($device in $baselineDevices) {
        if ($device.DeviceID) {
            $baselineIds += $device.DeviceID
        }
    }

    # Find devices in second file not present in baseline
    $newDevices = @()
    foreach ($device in $secondDevices) {
        if ($device.DeviceID -and ($baselineIds -notcontains $device.DeviceID)) {
            $newDevices += $device
        }
    }

    # Write output CSV header
    "DeviceID,Name" | Out-File -FilePath $OutputFile -Encoding UTF8 -Force

    if ($newDevices.Count -gt 0) {
        Write-Host ""
        Write-Host "Newly detected USB device(s):" -ForegroundColor Cyan
        Write-Host "----------------------------------------"

        foreach ($device in $newDevices) {
            Write-Host "DeviceID: $($device.DeviceID)"
            Write-Host "Name:     $($device.Name)"
            Write-Host ""

            "$($device.DeviceID),$($device.Name)" | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
        }

        Write-Host "Results exported to: $OutputFile" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "No new USB devices were detected." -ForegroundColor Yellow
        Write-Host "An empty results file was created: $OutputFile" -ForegroundColor Yellow
    }
}

# File names
$baselineCsv = "USB Capture 01.csv"
$secondCsv   = "USB Capture 02.csv"
$outputCsv   = "USB Capture Result.csv"

# Main script
Write-Host "USB Device ID Capture and Comparison Tool" -ForegroundColor Cyan
Write-Host "--------------------------------------------------"

# First capture
Export-UsbDeviceListToCsv -FileName $baselineCsv

Write-Host ""
Write-Host "USB devices have been captured." -ForegroundColor Yellow
Write-Host "Please plug in and power on the USB device to be whitelisted." -ForegroundColor Yellow
Write-Host ""
Read-Host "Once the device is connected and fully powered on, press Enter to continue"

# Second capture
Export-UsbDeviceListToCsv -FileName $secondCsv

# Compare files
Compare-UsbDeviceLists -BaselineFile $baselineCsv -SecondFile $secondCsv -OutputFile $outputCsv

Write-Host ""
Write-Host "Process complete." -ForegroundColor Green
Write-Host "You may review the results above or in '$outputCsv'." -ForegroundColor Cyan
Write-Host "Type 'exit' to close this window." -ForegroundColor Yellow

do {
    $userInput = Read-Host
} until ($userInput -eq "exit")