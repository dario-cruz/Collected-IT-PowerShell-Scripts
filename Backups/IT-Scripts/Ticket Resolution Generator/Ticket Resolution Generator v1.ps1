# ================================
# Ticket Resolution Generator
# ================================

function Get-TicketTemplates {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Template file not found: $Path"
    }

    $templates = @{}
    $currentTemplateName = $null
    $currentLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in Get-Content -Path $Path) {
        if ($line -match '^\s*\[(.+?)\]\s*$') {
            if ($currentTemplateName) {
                $templates[$currentTemplateName] = ($currentLines -join [Environment]::NewLine).Trim()
                $currentLines = New-Object System.Collections.Generic.List[string]
            }

            $currentTemplateName = $matches[1].Trim()
        }
        else {
            if ($null -ne $currentTemplateName) {
                [void]$currentLines.Add($line)
            }
        }
    }

    if ($currentTemplateName) {
        $templates[$currentTemplateName] = ($currentLines -join [Environment]::NewLine).Trim()
    }

    return $templates
}

function Get-TemplatePlaceholders {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TemplateText
    )

    $regex = '\{([A-Za-z0-9_]+)\}'
    $matches = [System.Text.RegularExpressions.Regex]::Matches($TemplateText, $regex)

    $placeholders = foreach ($match in $matches) {
        $match.Groups[1].Value
    }

    return $placeholders | Sort-Object -Unique
}

function Prompt-ForPlaceholderValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Placeholder
    )

    switch ($Placeholder.ToLower()) {
        'date' {
            return (Get-Date -Format 'MMMM dd, yyyy')
        }

        'technicianname' {
            $defaultValue = $env:USERNAME
            $inputValue = Read-Host "Enter value for $Placeholder [$defaultValue]"
            if ([string]::IsNullOrWhiteSpace($inputValue)) {
                return $defaultValue
            }
            else {
                return $inputValue
            }
        }

        default {
            do {
                $inputValue = Read-Host "Enter value for $Placeholder"
                if ([string]::IsNullOrWhiteSpace($inputValue)) {
                    Write-Host "Value cannot be blank. Please try again." -ForegroundColor Yellow
                }
            }
            until (-not [string]::IsNullOrWhiteSpace($inputValue))

            return $inputValue
        }
    }
}

function Build-ResolutionText {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TemplateText,

        [Parameter(Mandatory = $true)]
        [hashtable]$Values
    )

    $result = $TemplateText

    foreach ($key in $Values.Keys) {
        $token = [Regex]::Escape("{$key}")
        $replacement = [string]$Values[$key]
        $result = [System.Text.RegularExpressions.Regex]::Replace($result, $token, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement })
    }

    return $result
}

function Show-TicketMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$TicketTypes
    )

    Write-Host ""
    Write-Host "Available Ticket Types" -ForegroundColor Cyan
    Write-Host "----------------------"

    for ($i = 0; $i -lt $TicketTypes.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $TicketTypes[$i])
    }

    Write-Host "[Q] Quit"
    Write-Host ""
}

# -------------------------------
# Main Script
# -------------------------------

try {
    $defaultTemplatePath = ".\TicketTemplates.txt"
    $templatePathInput = Read-Host "Enter template file path [$defaultTemplatePath]"

    if ([string]::IsNullOrWhiteSpace($templatePathInput)) {
        $templatePath = $defaultTemplatePath
    }
    else {
        $templatePath = $templatePathInput
    }

    $templates = Get-TicketTemplates -Path $templatePath

    if ($templates.Count -eq 0) {
        throw "No templates were found in the template file."
    }

    do {
        Clear-Host
        $ticketTypes = $templates.Keys | Sort-Object
        Show-TicketMenu -TicketTypes $ticketTypes

        $selection = Read-Host "Select a ticket type by number or Q to quit"

        if ($selection -match '^[Qq]$') {
            Write-Host "Exiting..." -ForegroundColor Green
            break
        }

        $selectedIndex = $null
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt $ticketTypes.Count) {
            Write-Host "Selection out of range. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }

        $selectedTicketType = $ticketTypes[$selectedIndex - 1]
        $selectedTemplate = $templates[$selectedTicketType]

        $placeholders = Get-TemplatePlaceholders -TemplateText $selectedTemplate
        $values = @{}

        Write-Host ""
        Write-Host "You selected: $selectedTicketType" -ForegroundColor Green
        Write-Host "Please enter the required values below." -ForegroundColor Cyan
        Write-Host ""

        foreach ($placeholder in $placeholders) {
            $values[$placeholder] = Prompt-ForPlaceholderValue -Placeholder $placeholder
        }

        $finalResolution = Build-ResolutionText -TemplateText $selectedTemplate -Values $values

        Write-Host ""
        Write-Host "Generated Resolution" -ForegroundColor Cyan
        Write-Host "--------------------"
        Write-Host $finalResolution
        Write-Host ""

        $postAction = Read-Host "Choose action: [C] Copy to clipboard, [S] Save to file, [B] Both, [N] New ticket, [Q] Quit"

        switch -Regex ($postAction) {
            '^[Cc]$' {
                if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                    $finalResolution | Set-Clipboard
                    Write-Host "Resolution copied to clipboard." -ForegroundColor Green
                }
                else {
                    Write-Host "Set-Clipboard is not available in this session." -ForegroundColor Yellow
                }
            }

            '^[Ss]$' {
                $defaultFileName = "Resolution_{0}_{1}.txt" -f ($selectedTicketType -replace '[^\w\-]', '_'), (Get-Date -Format 'yyyyMMdd_HHmmss')
                $savePath = Read-Host "Enter save path [$defaultFileName]"
                if ([string]::IsNullOrWhiteSpace($savePath)) {
                    $savePath = $defaultFileName
                }

                $finalResolution | Out-File -FilePath $savePath -Encoding UTF8
                Write-Host "Resolution saved to: $savePath" -ForegroundColor Green
            }

            '^[Bb]$' {
                if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                    $finalResolution | Set-Clipboard
                    Write-Host "Resolution copied to clipboard." -ForegroundColor Green
                }
                else {
                    Write-Host "Set-Clipboard is not available in this session." -ForegroundColor Yellow
                }

                $defaultFileName = "Resolution_{0}_{1}.txt" -f ($selectedTicketType -replace '[^\w\-]', '_'), (Get-Date -Format 'yyyyMMdd_HHmmss')
                $savePath = Read-Host "Enter save path [$defaultFileName]"
                if ([string]::IsNullOrWhiteSpace($savePath)) {
                    $savePath = $defaultFileName
                }

                $finalResolution | Out-File -FilePath $savePath -Encoding UTF8
                Write-Host "Resolution saved to: $savePath" -ForegroundColor Green
            }

            '^[Qq]$' {
                Write-Host "Exiting..." -ForegroundColor Green
                break
            }

            default {
                # N or anything else just loops again
            }
        }

        Write-Host ""
        Read-Host "Press Enter to continue"

    } while ($true)
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}