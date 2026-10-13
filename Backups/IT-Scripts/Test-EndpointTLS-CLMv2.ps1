param (
    [string]$HostName = "xlp.pitchbook.com",
    [int]$Port = 443
)

# Create log file
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$env:TEMP\PitchBook_TLS_Test_$TimeStamp.log"

function Write-Log {
    param([string]$Message)

    $Entry = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

    Write-Host $Entry
    Add-Content -Path $LogFile -Value $Entry
}

Write-Log "========================================================="
Write-Log "PitchBook TLS Connectivity Diagnostic"
Write-Log "========================================================="
Write-Log "Computer Name: $env:COMPUTERNAME"
Write-Log "User: $env:USERNAME"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Log "Target Host: $HostName"
Write-Log "Target Port: $Port"

try {
    Write-Log "Language Mode: $($ExecutionContext.SessionState.LanguageMode)"
}
catch {
    Write-Log "Unable to determine language mode."
}

Write-Log ""
Write-Log "========================================================="
Write-Log "DNS Resolution Test"
Write-Log "========================================================="

try {
    $DnsResults = Resolve-DnsName $HostName -ErrorAction Stop

    foreach ($Result in $DnsResults) {
        Add-Content $LogFile ($Result | Out-String)
        Write-Host ($Result | Out-String)
    }
}
catch {
    Write-Log "DNS lookup failed."
    Write-Log $_.Exception.Message
}

Write-Log ""
Write-Log "========================================================="
Write-Log "TCP Connectivity Test"
Write-Log "========================================================="

try {
    $TNC = Test-NetConnection `
        -ComputerName $HostName `
        -Port $Port `
        -InformationLevel Detailed

    $TNC | Format-List * | Out-File `
        -FilePath $LogFile `
        -Append

    Write-Host ($TNC | Format-List * | Out-String)

    if ($TNC.TcpTestSucceeded) {
        Write-Log "TCP connectivity succeeded."
    }
    else {
        Write-Log "TCP connectivity failed."
    }
}
catch {
    Write-Log "Test-NetConnection failed."
    Write-Log $_.Exception.Message
}

Write-Log ""
Write-Log "========================================================="
Write-Log "HTTPS / TLS Handshake Test"
Write-Log "========================================================="

$Url = "https://$HostName"

try {

    $CurlOutput = & curl.exe `
        --verbose `
        --head `
        --connect-timeout 15 `
        --max-time 30 `
        $Url 2>&1

    $CurlExitCode = $LASTEXITCODE

    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value "===== CURL OUTPUT ====="
    Add-Content -Path $LogFile -Value ($CurlOutput | Out-String)

    Write-Host ($CurlOutput | Out-String)

    Write-Log "curl.exe Exit Code: $CurlExitCode"

    switch ($CurlExitCode) {

        0 {
            Write-Log "TLS handshake succeeded."
        }

        6 {
            Write-Log "DNS resolution failure."
        }

        7 {
            Write-Log "Connection failed."
        }

        28 {
            Write-Log "Connection timed out."
        }

        35 {
            Write-Log "TLS handshake failure."
        }

        51 {
            Write-Log "Certificate hostname mismatch."
        }

        60 {
            Write-Log "Certificate validation failure."
        }

        Default {
            Write-Log "Non-zero curl exit code returned."
        }
    }

}
catch {
    Write-Log "curl.exe execution failed."
    Write-Log $_.Exception.Message
}

Write-Log ""
Write-Log "========================================================="
Write-Log "Network Configuration"
Write-Log "========================================================="

try {
    ipconfig /all | Out-File -FilePath $LogFile -Append
}
catch {
    Write-Log "Failed to capture ipconfig."
}

Write-Log ""
Write-Log "========================================================="
Write-Log "Proxy Configuration"
Write-Log "========================================================="

try {
    netsh winhttp show proxy | Out-File `
        -FilePath $LogFile `
        -Append
}
catch {
    Write-Log "Unable to collect proxy configuration."
}

Write-Log ""
Write-Log "========================================================="
Write-Log "Diagnostic Complete"
Write-Log "========================================================="
Write-Log "Log File: $LogFile"

Write-Host ""
Write-Host "Diagnostic log saved to:"
Write-Host $LogFile