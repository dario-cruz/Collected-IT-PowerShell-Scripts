function Format-PastedNameList {
    while ($true) {
        Write-Host ""
        Write-Host "Paste the content to format, then press Enter." -ForegroundColor Cyan
        $inputText = Read-Host "Input"

        if ([string]::IsNullOrWhiteSpace($inputText)) {
            Write-Host "No content provided." -ForegroundColor Yellow
        }
        else {
            # Remove everything before the first colon if present
            if ($inputText -match ":") {
                $inputText = ($inputText -split ":", 2)[1]
            }

            # Split on semicolons, trim whitespace, and remove blank entries
            $names = $inputText -split ";" |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            Write-Host ""
            Write-Host "Formatted List:" -ForegroundColor Green
            Write-Host "--------------"

            foreach ($name in $names) {
                Write-Host $name
            }

            Write-Host ""
            Write-Host "Total entries: $($names.Count)" -ForegroundColor DarkGray
        }

        Write-Host ""
        $again = Read-Host "Do you have more content to format? (Y/N)"

        if ($again -notmatch '^(Y|YES)$') {
            Write-Host "Exiting formatter." -ForegroundColor Cyan
            break
        }
    }
}

# Run the formatter
Format-PastedNameList