<#
.SYNOPSIS
    Tests TCP and TLS/SSL connectivity to an HTTPS endpoint.

.DESCRIPTION
    Designed for PowerShell Constrained Language Mode.

    This script:
      - Confirms the current PowerShell language mode
      - Tests TCP port 443
      - Uses the native curl.exe executable
      - Performs a TLS handshake
      - Validates the certificate using the Windows trust store
      - Preserves hostname and certificate validation
      - Displays curl's TLS and HTTP diagnostic output

    It does not bypass certificate validation.
#>

param (
    [string]$HostName = "xlp.pitchbook.com",
    [int]$Port = 443,
    [int]$ConnectTimeoutSeconds = 10,
    [int]$MaximumTimeSeconds = 20
)

$Url = "https://${HostName}:${Port}/"

Write-Output ""
Write-Output "============================================================"
Write-Output " HTTPS/TLS diagnostics"
Write-Output "============================================================"
Write-Output "Host: $HostName"
Write-Output "Port: $Port"
Write-Output "URL:  $Url"
Write-Output ""

# Display the current PowerShell language mode.
Write-Output "PowerShell language mode:"
Write-Output $ExecutionContext.SessionState.LanguageMode
Write-Output ""

# Confirm that curl.exe is available.
$CurlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue

if ($null -eq $CurlCommand) {
    Write-Error "curl.exe was not found or is not permitted by application-control policy."
    exit 10
}

# Perform a basic TCP connectivity test.
Write-Output "============================================================"
Write-Output " TCP connectivity test"
Write-Output "============================================================"

Test-NetConnection `
    -ComputerName $HostName `
    -Port $Port `
    -InformationLevel Detailed

Write-Output ""
Write-Output "============================================================"
Write-Output " TLS certificate and HTTPS test"
Write-Output "============================================================"
Write-Output ""

Write-Output "Starting curl.exe with certificate validation enabled..."
Write-Output ""

# Important:
# No --insecure or -k option is used.
# curl.exe will reject an untrusted, expired, revoked, or mismatched
# certificate according to the TLS provider and policies available
# on the endpoint.

$CurlOutput = & curl.exe `
    --verbose `
    --head `
    --connect-timeout $ConnectTimeoutSeconds `
    --max-time $MaximumTimeSeconds `
    --output NUL `
    $Url 2>&1

$CurlExitCode = $LASTEXITCODE

# Display the complete diagnostic output because the exact certificate
# fields emitted by curl differ between curl and Windows versions.
Write-Output $CurlOutput

Write-Output ""
Write-Output "============================================================"
Write-Output " Result"
Write-Output "============================================================"
Write-Output "curl.exe exit code: $CurlExitCode"

if ($CurlExitCode -eq 0) {
    Write-Output ""
    Write-Output "SUCCESS: TCP connectivity and the TLS handshake completed."
    Write-Output "The certificate was accepted by curl.exe."
}
else {
    Write-Output ""
    Write-Warning "The HTTPS/TLS test failed."

    switch ($CurlExitCode) {
        5 {
            Write-Warning "curl could not resolve the configured proxy."
        }

        6 {
            Write-Warning "DNS resolution failed for $HostName."
        }

        7 {
            Write-Warning "TCP connection to ${HostName}:${Port} failed."
        }

        28 {
            Write-Warning "The operation timed out."
        }

        35 {
            Write-Warning "The TLS handshake failed."
        }

        51 {
            Write-Warning "Certificate hostname validation failed."
        }

        58 {
            Write-Warning "A local certificate-related problem occurred."
        }

        60 {
            Write-Warning "The server certificate was not trusted or failed certificate validation."
        }

        77 {
            Write-Warning "A problem occurred while accessing the local CA certificate store or CA file."
        }

        80 {
            Write-Warning "The SSL/TLS connection could not be closed correctly."
        }

        83 {
            Write-Warning "The certificate issuer check failed."
        }

        90 {
            Write-Warning "The certificate public-key pin did not match."
        }

        91 {
            Write-Warning "The certificate status validation failed."
        }

        default {
            Write-Warning "Review the verbose curl output above for the specific failure."
        }
    }
}

Write-Output ""
Write-Output "Diagnostic test completed."

exit $CurlExitCode