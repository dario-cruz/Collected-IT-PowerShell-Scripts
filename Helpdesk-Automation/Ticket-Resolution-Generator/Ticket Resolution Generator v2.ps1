# ==========================================
# Ticket Resolution Generator v2
# ==========================================

[CmdletBinding()]
param()

# -----------------------------
# Configuration
# -----------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptRoot "TicketTemplates.txt"
$OutputFolder = Join-Path $ScriptRoot "Output"
$LogFile = Join-Path $ScriptRoot "TicketResolutionLog.csv"

# -----------------------------
# Helper Functions
# -----------------------------

function Initialize-Environment {
    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    if (-not (Test-Path -Path $TemplatePath)) {
        throw "Template file not found: $TemplatePath"
    }

    if (-not (Test-Path -Path $LogFile)) {
        [PSCustomObject]@{
            Timestamp      = ""
            TicketType     = ""
            TicketNumber   = ""
            UserName       = ""
            TechnicianName = ""
            OutputFile     = ""
        } | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8
    }
}

function Get-TicketTemplates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $templates = @{}
    $currentTemplateName = $null
    $currentLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in Get-Content -Path $Path) {
        if ($line -match '^\s*\[(.+?)\]\s*$') {
            if (-not [string]::IsNullOrWhiteSpace($currentTemplateName)) {
                $templates[$currentTemplateName] = ($currentLines -join [Environment]::NewLine).Trim()
                $currentLines = New-Object System.Collections.Generic.List[string]
            }

            $currentTemplateName = $matches[1].Trim()
        }
        else {
            if (-not [string]::IsNullOrWhiteSpace($currentTemplateName)) {
                [void]$currentLines.Add($line)
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($currentTemplateName)) {
        $templates[$currentTemplateName] = ($currentLines -join [Environment]::NewLine).Trim()
    }

    return $templates
}

function Get-TemplatePlaceholders {
    param(
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

function Read-ValidatedInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [string]$DefaultValue = "",

        [switch]$AllowBlank
    )

    do {
        if ([string]::IsNullOrWhiteSpace($DefaultValue)) {
            $value = Read-Host $Prompt
        }
        else {
            $value = Read-Host "$Prompt [$DefaultValue]"
            if ([string]::IsNullOrWhiteSpace($value)) {
                $value = $DefaultValue
            }
        }

        if ($AllowBlank -or -not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }

        Write-Host "Input cannot be blank. Please try again." -ForegroundColor Yellow
    }
    while ($true)
}

function Get-DefaultPlaceholderValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Placeholder
    )

    switch ($Placeholder.ToLower()) {
        "date" {
            return (Get-Date -Format "MMMM dd, yyyy")
        }
        "technicianname" {
            return $env:USERNAME
        }
        "ticketnumber" {
            return ""
        }
        "username" {
            return ""
        }
        default {
            return ""
        }
    }
}

function Prompt-ForPlaceholderValues {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Placeholders
    )

    $values = @{}

    foreach ($placeholder in $Placeholders) {
        $defaultValue = Get-DefaultPlaceholderValue -Placeholder $placeholder

        if ($placeholder -eq "Date") {
            Write-Host ("{0}: {1}" -f $placeholder, $defaultValue) -ForegroundColor DarkGray
            $values[$placeholder] = $defaultValue
            continue
        }

        $promptText = "Enter value for $placeholder"
        $values[$placeholder] = Read-ValidatedInput -Prompt $promptText -DefaultValue $defaultValue
    }

    return $values
}

function Build-ResolutionText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateText,

        [Parameter(Mandatory = $true)]
        [hashtable]$Values
    )

    $result = $TemplateText

    foreach ($key in $Values.Keys) {
        $token = [regex]::Escape("{$key}")
        $replacement = [string]$Values[$key]
        $result = [regex]::Replace($result, $token, [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return $replacement
        })
    }

    return $result
}

function Show-TicketMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TicketTypes
    )

    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "      Ticket Resolution Generator v2      " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $TicketTypes.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $TicketTypes[$i])
    }

    Write-Host ""
    Write-Host "[Q] Quit"
    Write-Host ""
}

function Save-ResolutionToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TicketType,

        [Parameter(Mandatory = $true)]
        [string]$ResolutionText
    )

    $safeTicketType = ($TicketType -replace '[^\w\-]', '_')
    $fileName = "Resolution_{0}_{1}.txt" -f $safeTicketType, (Get-Date -Format "yyyyMMdd_HHmmss")
    $filePath = Join-Path $OutputFolder $fileName

    $ResolutionText | Out-File -FilePath $filePath -Encoding UTF8
    return $filePath
}

function Copy-ResolutionToClipboard {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolutionText
    )

    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
        $ResolutionText | Set-Clipboard
        return $true
    }

    return $false
}

function Write-ResolutionLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TicketType,

        [string]$TicketNumber = "",

        [string]$UserName = "",

        [string]$TechnicianName = "",

        [string]$OutputFile = ""
    )

    $entry = [PSCustomObject]@{
        Timestamp      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        TicketType     = $TicketType
        TicketNumber   = $TicketNumber
        UserName       = $UserName
        TechnicianName = $TechnicianName
        OutputFile     = $OutputFile
    }

    $entry | Export-Csv -Path $LogFile -NoTypeInformation -Append -Encoding UTF8
}

function Show-GeneratedResolution {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolutionText
    )

    Write-Host ""
    Write-Host "Generated Resolution" -ForegroundColor Green
    Write-Host "------------------------------------------" -ForegroundColor Green
    Write-Host $ResolutionText
    Write-Host "------------------------------------------" -ForegroundColor Green
    Write-Host ""
}

# -----------------------------
# Main
# -----------------------------
try {
    Initialize-Environment
    $templates = Get-TicketTemplates -Path $TemplatePath

    if ($templates.Count -eq 0) {
        throw "No templates were found in $TemplatePath"
    }

    $ticketTypes = $templates.Keys | Sort-Object

    do {
        Show-TicketMenu -TicketTypes $ticketTypes
        $selection = Read-Host "Select a ticket type by number or Q to quit"

        if ($selection -match '^[Qq]$') {
            Write-Host "Exiting..." -ForegroundColor Green
            break
        }

        $selectedIndex = 0
        $parsedSuccessfully = [int]::TryParse($selection, [ref]$selectedIndex)

        if (-not $parsedSuccessfully) {
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
        $values = Prompt-ForPlaceholderValues -Placeholders $placeholders
        $finalResolution = Build-ResolutionText -TemplateText $selectedTemplate -Values $values

        Show-GeneratedResolution -ResolutionText $finalResolution

        $postAction = Read-Host "Choose action: [C] Copy  [S] Save  [B] Both  [N] New Ticket  [Q] Quit"

        $savedFile = ""

        switch -Regex ($postAction) {
            '^[Cc]$' {
                $copied = Copy-ResolutionToClipboard -ResolutionText $finalResolution
                if ($copied) {
                    Write-Host "Resolution copied to clipboard." -ForegroundColor Green
                }
                else {
                    Write-Host "Clipboard support is not available in this session." -ForegroundColor Yellow
                }
            }

            '^[Ss]$' {
                $savedFile = Save-ResolutionToFile -TicketType $selectedTicketType -ResolutionText $finalResolution
                Write-Host "Resolution saved to: $savedFile" -ForegroundColor Green
            }

            '^[Bb]$' {
                $copied = Copy-ResolutionToClipboard -ResolutionText $finalResolution
                if ($copied) {
                    Write-Host "Resolution copied to clipboard." -ForegroundColor Green
                }
                else {
                    Write-Host "Clipboard support is not available in this session." -ForegroundColor Yellow
                }

                $savedFile = Save-ResolutionToFile -TicketType $selectedTicketType -ResolutionText $finalResolution
                Write-Host "Resolution saved to: $savedFile" -ForegroundColor Green
            }

            '^[Qq]$' {
                Write-ResolutionLog `
                    -TicketType $selectedTicketType `
                    -TicketNumber ($values["TicketNumber"]) `
                    -UserName ($values["UserName"]) `
                    -TechnicianName ($values["TechnicianName"]) `
                    -OutputFile $savedFile

                Write-Host "Exiting..." -ForegroundColor Green
                break
            }

            default {
                # N or anything else returns to main menu
            }
        }

        Write-ResolutionLog `
            -TicketType $selectedTicketType `
            -TicketNumber ($values["TicketNumber"]) `
            -UserName ($values["UserName"]) `
            -TechnicianName ($values["TechnicianName"]) `
            -OutputFile $savedFile

        Write-Host ""
        Read-Host "Press Enter to continue"

    } while ($true)
}
catch {
    Write-Host ("Error: {0}" -f $_.Exception.Message) -ForegroundColor Red
}