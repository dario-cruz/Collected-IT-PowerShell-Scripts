function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [bool]$Default = $true
    )

    while ($true) {
        $suffix = if ($Default) { " [Y/n]" } else { " [y/N]" }
        $response = Read-Host "$Prompt$suffix"

        if ([string]::IsNullOrWhiteSpace($response)) {
            return $Default
        }

        switch -Regex ($response.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$'  { return $false }
            default {
                Write-Host "Please enter Y or N." -ForegroundColor Yellow
            }
        }
    }
}

function Get-MultilineInput {
    Write-Host ""
    Write-Host "Paste the content to format." -ForegroundColor Cyan
    Write-Host "When finished, press Enter on a blank line." -ForegroundColor Cyan
    Write-Host ""

    $lines = New-Object System.Collections.Generic.List[string]

    while ($true) {
        $line = Read-Host
        if ([string]::IsNullOrWhiteSpace($line)) {
            break
        }

        $lines.Add($line)
    }

    return ($lines -join "`n")
}

function Remove-IntroLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $patterns = @(
        '^\s*Access to be granted to\s*:\s*',
        '^\s*Please add\s*:\s*',
        '^\s*Users\s*:\s*',
        '^\s*Grant access to\s*:\s*',
        '^\s*Add\s*:\s*'
    )

    foreach ($pattern in $patterns) {
        if ($Text -match $pattern) {
            return ($Text -replace $pattern, '')
        }
    }

    # Generic fallback:
    # If a colon appears before the first list delimiter, remove everything before the colon.
    $colonIndex = $Text.IndexOf(':')

    if ($colonIndex -ge 0) {
        $delimiterIndexes = @(
            $Text.IndexOf(';'),
            $Text.IndexOf(','),
            $Text.IndexOf("`n")
        ) | Where-Object { $_ -ge 0 }

        if ($delimiterIndexes.Count -eq 0) {
            return $Text.Substring($colonIndex + 1).Trim()
        }

        $firstDelimiter = ($delimiterIndexes | Measure-Object -Minimum).Minimum

        if ($colonIndex -lt $firstDelimiter) {
            return $Text.Substring($colonIndex + 1).Trim()
        }
    }

    return $Text
}

function Convert-ToCleanNameList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText,

        [bool]$RemoveDuplicates = $true,
        [bool]$SortAlphabetically = $false
    )

    $cleanText = Remove-IntroLabel -Text $InputText

    # Normalize line endings
    $cleanText = $cleanText -replace "\r\n?", "`n"

    # Split on semicolons, commas, or line breaks
    $items = $cleanText -split '[;,\n]+'

    # Trim and remove blanks
    $items = $items |
        ForEach-Object { ($_ -replace '\s+', ' ').Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    # Remove duplicates while preserving original order
    if ($RemoveDuplicates) {
        $seen = @{}
        $deduped = foreach ($item in $items) {
            $key = $item.ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $item
            }
        }

        $items = $deduped
    }

    # Optional sorting
    if ($SortAlphabetically) {
        $items = $items | Sort-Object
    }

    return ,$items
}

function Save-FormattedListToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $defaultPath = Join-Path -Path (Get-Location) -ChildPath "Formatted_List_$timestamp.txt"

    $path = Read-Host "Enter output file path or press Enter to use default [$defaultPath]"

    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = $defaultPath
    }

    try {
        Set-Content -Path $path -Value $Content -Encoding UTF8
        Write-Host "Saved to: $path" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to save file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Format-PastedNameListV2 {
    while ($true) {
        $inputText = Get-MultilineInput

        if ([string]::IsNullOrWhiteSpace($inputText)) {
            Write-Host "No content provided." -ForegroundColor Yellow
        }
        else {
            $removeDuplicates = Read-YesNo -Prompt "Remove duplicate names?" -Default $true
            $sortAlphabetically = Read-YesNo -Prompt "Sort names alphabetically?" -Default $false
            $copyToClipboard = Read-YesNo -Prompt "Copy formatted list to clipboard?" -Default $true
            $saveToFile = Read-YesNo -Prompt "Save formatted list to a .txt file?" -Default $false

            $names = Convert-ToCleanNameList -InputText $inputText -RemoveDuplicates $removeDuplicates -SortAlphabetically $sortAlphabetically

            if (-not $names -or $names.Count -eq 0) {
                Write-Host "No valid entries were found." -ForegroundColor Yellow
            }
            else {
                $formattedOutput = $names -join [Environment]::NewLine

                Write-Host ""
                Write-Host "Formatted List:" -ForegroundColor Green
                Write-Host "--------------"
                Write-Host $formattedOutput
                Write-Host ""
                Write-Host "Total entries: $($names.Count)" -ForegroundColor DarkGray

                if ($copyToClipboard) {
                    try {
                        Set-Clipboard -Value $formattedOutput
                        Write-Host "Formatted list copied to clipboard." -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "Could not copy to clipboard in this session." -ForegroundColor Yellow
                    }
                }

                if ($saveToFile) {
                    Save-FormattedListToFile -Content $formattedOutput
                }
            }
        }

        Write-Host ""
        $again = Read-YesNo -Prompt "Do you have more content to format?" -Default $true

        if (-not $again) {
            Write-Host "Exiting formatter." -ForegroundColor Cyan
            break
        }
    }
}

# Run the script
Format-PastedNameListV2