# =========================================
# Microsoft Teams Diagnostic Collection Tool
# =========================================

# Logged-in user
$UserName = $env:USERNAME

# Destination root
$DestinationRoot = 'C:\Temp\TeamsLogs'

# Ensure destination exists
if (!(Test-Path $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

# =========================================
# USER PROMPT
# =========================================

Write-Host ''
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host 'Microsoft Teams Diagnostic Collection Tool' -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'This tool will collect all available Microsoft Teams diagnostic logs.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'The collection includes:' -ForegroundColor White
Write-Host '- Classic Teams logs' -ForegroundColor Gray
Write-Host '- New Teams logs' -ForegroundColor Gray
Write-Host '- Teams configuration files' -ForegroundColor Gray
Write-Host '- Windows Event Logs' -ForegroundColor Gray
Write-Host '- Teams process information' -ForegroundColor Gray
Write-Host '- System information' -ForegroundColor Gray
Write-Host ''
Write-Host 'A ZIP file will be generated automatically when collection is complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Logs will be saved to:' -ForegroundColor White
Write-Host $DestinationRoot -ForegroundColor Cyan
Write-Host ''
Write-Host 'Press ENTER to begin collection...' -ForegroundColor Magenta

Read-Host | Out-Null

Write-Host ''
Write-Host 'Teams diagnostic collection started...' -ForegroundColor Green

Start-Sleep -Seconds 2
Clear-Host

# =========================================
# Teams Diagnostic Collection Function
# =========================================

function Collect-TeamsDiagnostics {

    $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $FolderName = $UserName + '-TEAMSDIAGNOSTICS-' + $Timestamp
    $Destination = Join-Path $DestinationRoot $FolderName

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    # =========================================
	# Collect ALL Classic Teams Files
	# =========================================

	$ClassicTeamsRoot = "$env:APPDATA\Microsoft\Teams"

	if (Test-Path $ClassicTeamsRoot) {

		Get-ChildItem `
			$ClassicTeamsRoot `
			-Recurse `
			-File `
			-ErrorAction SilentlyContinue |

			ForEach-Object {

				try {

					$RelativePath = $_.FullName.Replace($ClassicTeamsRoot, '').TrimStart('\')

					$SafeName = $RelativePath -replace '[\\/:*?"<>|]', '_'

					Copy-Item `
						$_.FullName `
						-Destination (Join-Path $Destination ("ClassicTeams_" + $SafeName)) `
						-Force `
						-ErrorAction Stop
				}
				catch {}
			}
	}

    # =========================================
	# Collect ALL New Teams Files
	# =========================================

	$NewTeamsFolders = Get-ChildItem `
		"$env:LOCALAPPDATA\Packages" `
		-Directory `
		-Filter "MSTeams*" `
		-ErrorAction SilentlyContinue

	foreach ($Folder in $NewTeamsFolders) {

		try {

			Get-ChildItem `
				$Folder.FullName `
				-Recurse `
				-File `
				-ErrorAction SilentlyContinue |

				ForEach-Object {

					try {

						$RelativePath = $_.FullName.Replace($Folder.FullName, '').TrimStart('\')

						$SafeName = $RelativePath -replace '[\\/:*?"<>|]', '_'

						Copy-Item `
							$_.FullName `
							-Destination (Join-Path $Destination ("NewTeams_" + $SafeName)) `
							-Force `
							-ErrorAction Stop
					}
					catch {}
				}
		}
		catch {}
	}

	# Teams Process Information
	try {

		Get-Process |
			Where-Object {
				$_.Name -match 'teams'
			} |

			Select-Object `
				Name,
				Id,
				StartTime,
				Path |

			Export-Csv `
				(Join-Path $Destination 'TeamsProcesses.csv') `
				-NoTypeInformation
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

        
		Get-ChildItem "$env:LOCALAPPDATA\Packages" `
			-Directory `
			-Filter "MSTeams*" `
			-ErrorAction SilentlyContinue |


            Select-Object FullName, LastWriteTime |

            Export-Csv `
                (Join-Path $Destination 'TeamsConfigurationFiles.csv') `
                -NoTypeInformation
    }
    catch {}
	
	# Teams Version Details

	try {

		Get-AppxPackage *MSTeams* |

			Select-Object `
				Name,
				Version,
				InstallLocation |

			Export-Csv `
				(Join-Path $Destination 'TeamsVersionDetails.csv') `
				-NoTypeInformation
	}
	catch {}
		
	# File Count Summary
	try {

		$FileCount = (
			Get-ChildItem `
				$Destination `
				-Recurse `
				-File `
				-ErrorAction SilentlyContinue
		).Count

		$FileCount | Out-File (
			Join-Path $Destination 'CollectedFileCount.txt'
		)
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
            'Microsoft Teams Diagnostic Collection Manifest'
            '=================================='
            ''
            "Collected User: $UserName"
            "Computer Name: $env:COMPUTERNAME"
            "Collection Time Local: $(Get-Date)"
            "Collection Folder: $Destination"
            "Zip File: $ZipPath"
            ''
			'Included Data:'
			'- All Classic Teams files'
			'- All New Teams files'
			'- Teams process information'
			'- Windows Application event logs'
			'- Windows System event logs'
			'- System information'
			'- Teams log inventory'
			'- Teams configuration inventory'
			'- Teams version information'
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

Collect-TeamsDiagnostics

Write-Host ''
Write-Host 'Collection completed successfully.' -ForegroundColor Green
Write-Host ''
Write-Host 'Diagnostic ZIP package saved to:' -ForegroundColor Cyan
Write-Host $DestinationRoot -ForegroundColor White
Write-Host ''

Read-Host 'Press ENTER to exit'