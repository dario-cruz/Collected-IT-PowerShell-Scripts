Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# -------------------------------
# Main Launcher GUI
# -------------------------------

function Get-ScrollSpeedFromLevel {
    param(
        [int]$Level
    )

    switch ($Level) {
        1 { return 0.5 }
        2 { return 1 }
        3 { return 2 }
        4 { return 3 }
        5 { return 5 }
        default { return 1 }
    }
}

[xml]$launcherXaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Teleprompter Launcher"
    Width="620"
    Height="500"
    WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize"
    Background="#1E1E1E">

    <Grid Margin="25">

        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="160"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="110"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0"
                   Grid.ColumnSpan="3"
                   Text="Teleprompter Launcher"
                   Foreground="White"
                   FontSize="28"
                   FontWeight="Bold"
                   Margin="0,0,0,25"/>

        <TextBlock Grid.Row="1"
                   Grid.Column="0"
                   Text="Script File:"
                   Foreground="White"
                   FontSize="15"
                   VerticalAlignment="Center"
                   Margin="0,0,10,12"/>

        <TextBox Grid.Row="1"
                 Grid.Column="1"
                 Name="FilePathTextBox"
                 FontSize="14"
                 Height="30"
                 Margin="0,0,10,12"
                 IsReadOnly="True"/>

        <Button Grid.Row="1"
                Grid.Column="2"
                Name="BrowseButton"
                Content="Browse..."
                Height="30"
                Margin="0,0,0,12"/>

        <TextBlock Grid.Row="2"
                   Grid.Column="0"
                   Text="Default Font Size:"
                   Foreground="White"
                   FontSize="15"
                   VerticalAlignment="Center"
                   Margin="0,0,10,12"/>

        <TextBox Grid.Row="2"
                 Grid.Column="1"
                 Name="FontSizeTextBox"
                 Text="120"
                 FontSize="14"
                 Height="30"
                 Margin="0,0,10,12"/>

        <TextBlock Grid.Row="3"
                   Grid.Column="0"
                   Text="Default Speed:"
                   Foreground="White"
                   FontSize="15"
                   VerticalAlignment="Center"
                   Margin="0,0,10,12"/>

        <ComboBox Grid.Row="3"
                  Grid.Column="1"
                  Name="SpeedComboBox"
                  SelectedIndex="1"
                  FontSize="14"
                  Height="30"
                  Margin="0,0,10,12">
            <ComboBoxItem Content="1 - Very Slow"/>
            <ComboBoxItem Content="2 - Slow"/>
            <ComboBoxItem Content="3 - Normal"/>
            <ComboBoxItem Content="4 - Fast"/>
            <ComboBoxItem Content="5 - Very Fast"/>
        </ComboBox>

        <TextBlock Grid.Row="4"
                   Grid.Column="0"
                   Text="Countdown Seconds:"
                   Foreground="White"
                   FontSize="15"
                   VerticalAlignment="Center"
                   Margin="0,0,10,12"/>

        <TextBox Grid.Row="4"
                 Grid.Column="1"
                 Name="CountdownTextBox"
                 Text="5"
                 FontSize="14"
                 Height="30"
                 Margin="0,0,10,12"/>

        <TextBlock Grid.Row="5"
                   Grid.Column="0"
                   Text="Font Color:"
                   Foreground="White"
                   FontSize="15"
                   VerticalAlignment="Center"
                   Margin="0,0,10,12"/>

        <ComboBox Grid.Row="5"
                  Grid.Column="1"
                  Name="FontColorComboBox"
                  SelectedIndex="0"
                  FontSize="14"
                  Height="30"
                  Margin="0,0,10,12">
            <ComboBoxItem Content="White"/>
            <ComboBoxItem Content="Yellow"/>
            <ComboBoxItem Content="Cyan"/>
            <ComboBoxItem Content="LightGreen"/>
            <ComboBoxItem Content="Orange"/>
        </ComboBox>

        <TextBlock Grid.Row="6"
                   Grid.Column="0"
                   Text="Background Color:"
                   Foreground="White"
                   FontSize="15"
                   VerticalAlignment="Center"
                   Margin="0,0,10,12"/>

        <ComboBox Grid.Row="6"
                  Grid.Column="1"
                  Name="BackgroundColorComboBox"
                  SelectedIndex="0"
                  FontSize="14"
                  Height="30"
                  Margin="0,0,10,12">
            <ComboBoxItem Content="Black"/>
            <ComboBoxItem Content="#101010"/>
            <ComboBoxItem Content="#1E1E1E"/>
            <ComboBoxItem Content="DarkBlue"/>
            <ComboBoxItem Content="DarkSlateGray"/>
        </ComboBox>

        <TextBlock Grid.Row="7"
                   Grid.ColumnSpan="3"
                   Text="Keyboard controls available inside teleprompter: Space = Pause/Resume, 1-5 = Speed, +/- = Font Size, R = Reset, ? = Help, Esc = Exit"
                   Foreground="Gray"
                   FontSize="13"
                   TextWrapping="Wrap"
                   Margin="0,20,0,20"/>

        <StackPanel Grid.Row="8"
                    Grid.ColumnSpan="3"
                    Orientation="Horizontal"
                    HorizontalAlignment="Right">

            <Button Name="StartButton"
                    Content="Start Teleprompter"
                    Width="160"
                    Height="36"
                    Margin="0,0,10,0"
                    Background="#0078D4"
                    Foreground="White"
                    FontWeight="Bold"/>

            <Button Name="CancelButton"
                    Content="Cancel"
                    Width="90"
                    Height="36"/>
        </StackPanel>

    </Grid>
</Window>
"@

$launcherReader = New-Object System.Xml.XmlNodeReader $launcherXaml
$launcherWindow = [Windows.Markup.XamlReader]::Load($launcherReader)

$filePathTextBox = $launcherWindow.FindName("FilePathTextBox")
$browseButton = $launcherWindow.FindName("BrowseButton")
$fontSizeTextBox = $launcherWindow.FindName("FontSizeTextBox")
$speedComboBox = $launcherWindow.FindName("SpeedComboBox")
$countdownTextBox = $launcherWindow.FindName("CountdownTextBox")
$fontColorComboBox = $launcherWindow.FindName("FontColorComboBox")
$backgroundColorComboBox = $launcherWindow.FindName("BackgroundColorComboBox")
$startButton = $launcherWindow.FindName("StartButton")
$cancelButton = $launcherWindow.FindName("CancelButton")

$script:launcherAccepted = $false

$browseButton.Add_Click({

    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "Word Documents (*.docx)|*.docx"
    $fileDialog.Title = "Select Teleprompter Script"

    if ($fileDialog.ShowDialog() -eq "OK") {
        $filePathTextBox.Text = $fileDialog.FileName
    }
})

$cancelButton.Add_Click({
    $script:launcherAccepted = $false
    $launcherWindow.Close()
})

$startButton.Add_Click({

    if ([string]::IsNullOrWhiteSpace($filePathTextBox.Text) -or -not (Test-Path $filePathTextBox.Text)) {
        [System.Windows.MessageBox]::Show(
            "Please select a valid DOCX file.",
            "Missing Script File",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    $parsedFontSize = 0
    if (-not [int]::TryParse($fontSizeTextBox.Text, [ref]$parsedFontSize)) {
        [System.Windows.MessageBox]::Show(
            "Please enter a valid font size.",
            "Invalid Font Size",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    if ($parsedFontSize -lt 20 -or $parsedFontSize -gt 300) {
        [System.Windows.MessageBox]::Show(
            "Font size must be between 20 and 300.",
            "Invalid Font Size",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    $parsedCountdown = 0
    if (-not [int]::TryParse($countdownTextBox.Text, [ref]$parsedCountdown)) {
        [System.Windows.MessageBox]::Show(
            "Please enter a valid countdown value.",
            "Invalid Countdown",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    if ($parsedCountdown -lt 0 -or $parsedCountdown -gt 30) {
        [System.Windows.MessageBox]::Show(
            "Countdown must be between 0 and 30 seconds.",
            "Invalid Countdown",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    $selectedSpeedText = $speedComboBox.SelectedItem.Content.ToString()
    $selectedSpeedLevel = [int]($selectedSpeedText.Substring(0,1))

    $script:docPath = $filePathTextBox.Text
    $script:fontSize = $parsedFontSize
    $script:defaultSpeedLevel = $selectedSpeedLevel
    $script:scrollSpeed = Get-ScrollSpeedFromLevel -Level $selectedSpeedLevel
    $script:countdownSeconds = $parsedCountdown
    $script:fontColor = $fontColorComboBox.SelectedItem.Content.ToString()
    $script:backgroundColor = $backgroundColorComboBox.SelectedItem.Content.ToString()

    $script:launcherAccepted = $true
    $launcherWindow.Close()
})

$launcherWindow.ShowDialog() | Out-Null

if (-not $script:launcherAccepted) {
    return
}

$docPath = $script:docPath

# Extract text from Word document
$word = New-Object -ComObject Word.Application
$word.Visible = $false

$doc = $word.Documents.Open($docPath)
$text = $doc.Content.Text

$doc.Close()
$word.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc)  | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null

# XAML Window
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowState="Maximized"
    WindowStyle="None"
    Background="$($script:backgroundColor)"
    Topmost="True">

    <Grid Background="$($script:backgroundColor)">

		<ScrollViewer Name="Scroller"
                  VerticalScrollBarVisibility="Hidden">
			<TextBlock Name="PromptText"        
				Foreground="$($script:fontColor)"
				Background="$($script:backgroundColor)"
				FontSize="$($script:fontSize)"
				FontFamily="Segoe UI"
				TextWrapping="Wrap"
				Margin="100"
				TextAlignment="Center"/>
		</ScrollViewer>

		<TextBlock Name="CountdownText"
               Foreground="Red"
               FontSize="200"
               FontWeight="Bold"
               HorizontalAlignment="Center"
               VerticalAlignment="Center"
               Visibility="Visible"/>
		
		<TextBlock Name="SpeedIndicator"
				   Foreground="Lime"
				   FontSize="28"
				   FontWeight="Bold"
				   HorizontalAlignment="Right"
				   VerticalAlignment="Top"
				   Margin="20"
				   Opacity="0.4"
				   Text="Speed: $($script:defaultSpeedLevel)"/>

		<TextBlock Name="FontSizeIndicator"
				   Foreground="Cyan"
				   FontSize="28"
				   FontWeight="Bold"
				   HorizontalAlignment="Left"
				   VerticalAlignment="Top"
				   Margin="20"
				   Opacity="0.4"
				   Text="Font: $($script:fontSize)"/>
		   
		<Border Name="HelpOverlay"
        Visibility="Collapsed"
        Background="#DD000000"
        BorderBrush="White"
        BorderThickness="2"
        Width="800"
        Padding="20"
        HorizontalAlignment="Center"
        VerticalAlignment="Center">

			<Grid>
			
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
				</Grid.RowDefinitions>

				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="120"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>

				<TextBlock Grid.Row="0" Grid.ColumnSpan="2"
					Text="Teleprompter Controls"
					FontSize="32"
					FontWeight="Bold"
					Foreground="White"
					Margin="0,0,0,20"/>

				<TextBlock Grid.Row="1" Grid.Column="0"
					Text="SPACE"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="1" Grid.Column="1"
					Text="Pause / Resume"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="2" Grid.Column="0"
					Text="1-5"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="2" Grid.Column="1"
					Text="Change Scrolling Speed"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="3" Grid.Column="0"
					Text="+ / -"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="3" Grid.Column="1"
					Text="Adjust Font Size"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="4" Grid.Column="0"
					Text="R"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="4" Grid.Column="1"
					Text="Reset Script"
					Foreground="White"
					FontSize="24"/>

				<TextBlock Grid.Row="5" Grid.Column="0"
					   Text="?"
					   Foreground="White"
					   FontSize="24"/>

				<TextBlock Grid.Row="5" Grid.Column="1"
					   Text="Show / Hide Help"
					   Foreground="White"
					   FontSize="24"/>

				<TextBlock Grid.Row="6" Grid.Column="0"
					   Text="ESC"
					   Foreground="White"
					   FontSize="24"/>

				<TextBlock Grid.Row="6" Grid.Column="1"
					   Text="Exit"
					   Foreground="White"
					   FontSize="24"/>

			</Grid>

		</Border>
		
		<TextBlock Name="HelpHint"
           Text="Press '?' for Help"
           Foreground="Gray"
           FontSize="18"
           HorizontalAlignment="Right"
           VerticalAlignment="Bottom"
           Margin="0,0,20,20"
           Opacity="0.7"/>
		   

		<TextBlock Name="ProgressIndicator"
				   Text="Progress: 0%"
				   Foreground="Gray"
				   FontSize="18"
				   HorizontalAlignment="Left"
				   VerticalAlignment="Bottom"
				   Margin="20"
				   Opacity="0.7"/>

	</Grid>

</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$script:progressIndicator = $window.FindName("ProgressIndicator")

$scroller = $window.FindName("Scroller")
$promptText = $window.FindName("PromptText")

Write-Host "Type:"
Write-Host $script:progressIndicator.GetType().FullName

$promptText.Text = $text

# Scrolling control
$script:scrollSpeed = Get-ScrollSpeedFromLevel -Level $script:defaultSpeedLevel
$script:isRunning = $false

$speedIndicator = $window.FindName("SpeedIndicator")

# Timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(30)

$timer.Add_Tick({

    if ($script:isRunning)
    {
        $scroller.ScrollToVerticalOffset(
            $scroller.VerticalOffset + $script:scrollSpeed
        )
    }

    # Progress Indicator
    if ($scroller.ScrollableHeight -gt 0)
    {
        $progress = [math]::Round(
            ($scroller.VerticalOffset /
             $scroller.ScrollableHeight) * 100
        )

        if ($progress -gt 100)
        {
            $progress = 100
        }

        $script:progressIndicator.Text = "Progress: $progress%"
    }
    else
    {
        $script:progressIndicator.Text = "Progress: 0%"
    }
})

$timer.Start()

$promptText.FontSize = $script:fontSize
$fontSizeIndicator = $window.FindName("FontSizeIndicator")
$speedIndicator.Text = "Speed: $($script:defaultSpeedLevel)"


# Keyboard controls
$window.Add_PreviewKeyDown({

    switch ($_.Key) {

        # Pause / Resume
        "Space" {
            $script:isRunning = -not $script:isRunning
        }

        # Speed 1
        "D1" {
            $script:scrollSpeed = 0.5
            $speedIndicator.Text = "Speed: 1"
        }

        # Speed 2
        "D2" {
            $script:scrollSpeed = 1
            $speedIndicator.Text = "Speed: 2"
        }

        # Speed 3
        "D3" {
            $script:scrollSpeed = 2
            $speedIndicator.Text = "Speed: 3"
        }

        # Speed 4
        "D4" {
            $script:scrollSpeed = 3
            $speedIndicator.Text = "Speed: 4"
        }

        # Speed 5
        "D5" {
            $script:scrollSpeed = 5
            $speedIndicator.Text = "Speed: 5"
        }

        # Numpad Support
        "NumPad1" {
            $script:scrollSpeed = 0.5
            $speedIndicator.Text = "Speed: 1"
        }

        "NumPad2" {
            $script:scrollSpeed = 1
            $speedIndicator.Text = "Speed: 2"
        }

        "NumPad3" {
            $script:scrollSpeed = 2
            $speedIndicator.Text = "Speed: 3"
        }

        "NumPad4" {
            $script:scrollSpeed = 3
            $speedIndicator.Text = "Speed: 4"
        }

        "NumPad5" {
            $script:scrollSpeed = 5
            $speedIndicator.Text = "Speed: 5"
        }
		
		# Increase font size
		"OemPlus" {

			if ($script:fontSize -lt 200) {

				$script:fontSize += 5

				$promptText.FontSize = $script:fontSize
				$fontSizeIndicator.Text = "Font: $($script:fontSize)"
			}
		}

		# Decrease font size
		"OemMinus" {

			if ($script:fontSize -gt 60) {

				$script:fontSize -= 5

				$promptText.FontSize = $script:fontSize
				$fontSizeIndicator.Text = "Font: $($script:fontSize)"
			}
		}
		
				# Increase font size (Num +)
		"Add" {

			if ($script:fontSize -lt 200) {

				$script:fontSize += 5

				$promptText.FontSize = $script:fontSize
				$fontSizeIndicator.Text = "Font: $($script:fontSize)"
			}
		}

		# Decrease font size (Num -)
		"Subtract" {

			if ($script:fontSize -gt 60) {

				$script:fontSize -= 5

				$promptText.FontSize = $script:fontSize
				$fontSizeIndicator.Text = "Font: $($script:fontSize)"
			}
		}
		
		# Stop scrolling		
		"R" {

			$script:isRunning = $false

			# Reset scroll position
			$scroller.ScrollToVerticalOffset(0)
			$script:progressIndicator.Text = "Progress: 0%"

			# If countdown enabled, reset
			if ($countdownTimer.IsEnabled)
			{
				$countdownTimer.Stop()
			}

			# Reset countdown
			$script:count = $script:countdownSeconds

			$countdownText.Visibility = "Visible"
			$countdownText.Text = $script:count

			# Restart countdown
			$countdownTimer.Start()

		}
		
		# Help Menu
		"OemQuestion" {

			if ($helpOverlay.Visibility -eq [System.Windows.Visibility]::Visible)
			{
				$helpOverlay.Visibility = [System.Windows.Visibility]::Collapsed
				$helpHint.Visibility = [System.Windows.Visibility]::Visible

				$script:isRunning = $true
			}
			else
			{
				$helpOverlay.Visibility = [System.Windows.Visibility]::Visible
				$helpHint.Visibility = [System.Windows.Visibility]::Collapsed

				$script:isRunning = $false
			}
		}
		
        # Exit
        "Escape" {
            $window.Close()
        }
    }
})

# Debug Key Press Issues
#$window.Add_PreviewKeyDown({
#
#    Write-Host "Key Pressed:" $_.Key
#
#})

# Help/Hint Window
$helpHint = $window.FindName("HelpHint")
$helpOverlay = $window.FindName("HelpOverlay")

# Countdown funcitonlaity
$countdownText = $window.FindName("CountdownText")

$countdownTimer = New-Object System.Windows.Threading.DispatcherTimer
$countdownTimer.Interval = [TimeSpan]::FromSeconds(1)

$script:count = $script:countdownSeconds

$countdownText.Text = $script:count

$countdownTimer.Add_Tick({

    $script:count--

    if ($script:count -gt 0) {
        $countdownText.Text = $script:count
    }
    elseif ($script:count -eq 0) {
        $countdownText.Text = "GO!"
    }
    else {
        $countdownTimer.Stop()
        $countdownText.Visibility = "Collapsed"
        $script:isRunning = $true
    }
})

$window.Add_ContentRendered({

    if ($script:countdownSeconds -gt 0) {
        $script:count = $script:countdownSeconds
        $countdownText.Text = $script:count
        $countdownText.Visibility = [System.Windows.Visibility]::Visible
        $countdownTimer.Start()
    }
    else {
        $countdownText.Visibility = [System.Windows.Visibility]::Collapsed
        $script:isRunning = $true
    }

})


$window.Add_ContentRendered({

    $window.Focus()
    [System.Windows.Input.Keyboard]::Focus($window)

})

# Render Prompter Window
$window.ShowDialog() | Out-Null


