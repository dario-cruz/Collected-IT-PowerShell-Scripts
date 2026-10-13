Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Select DOCX file
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "Word Documents (*.docx)|*.docx"

if ($dialog.ShowDialog() -ne "OK") {
    return
}

$docPath = $dialog.FileName

# Extract text from Word document
$word = New-Object -ComObject Word.Application
$word.Visible = $false

$doc = $word.Documents.Open($docPath)
$text = $doc.Content.Text

$doc.Close()
$word.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null

# XAML Window
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowState="Maximized"
    WindowStyle="None"
    Background="Black"
    Topmost="True">

    <Grid Background="Black">

		<ScrollViewer Name="Scroller"
                  VerticalScrollBarVisibility="Hidden">
			<TextBlock Name="PromptText"
                   Foreground="White"
                   Background="Black"
                   FontSize="120"
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
           Text="Speed: 3"/>	   
		
		<TextBlock Name="FontSizeIndicator"
           Foreground="Cyan"
           FontSize="28"
           FontWeight="Bold"
           HorizontalAlignment="Left"
           VerticalAlignment="Top"
           Margin="20,60,20,20"
           Text="Font: 120"/>
		   
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
		
	</Grid>

</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$scroller = $window.FindName("Scroller")
$promptText = $window.FindName("PromptText")

$promptText.Text = $text

# Scrolling control
$scrollSpeed = 2
$isRunning = $false

$speedIndicator = $window.FindName("SpeedIndicator")

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(30)

$timer.Add_Tick({
    if ($isRunning) {
        $scroller.ScrollToVerticalOffset(
            $scroller.VerticalOffset + $scrollSpeed
        )
    }
})

$timer.Start()


$promptText = $window.FindName("PromptText")

$script:fontSize = 120
$promptText.FontSize = $script:fontSize

$fontSizeIndicator = $window.FindName("FontSizeIndicator")


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

			# If countdown enabled, reset
			if ($countdownTimer.IsEnabled)
			{
				$countdownTimer.Stop()
			}

			# Reset countdown
			$script:count = 5

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
				$script:isRunning = $true
			}
			else
			{
				$helpOverlay.Visibility = [System.Windows.Visibility]::Visible
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


$countdownText = $window.FindName("CountdownText")

$countdownTimer = New-Object System.Windows.Threading.DispatcherTimer
$countdownTimer.Interval = [TimeSpan]::FromSeconds(1)

$script:count = 5

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
    $countdownTimer.Start()
})

$window.Add_ContentRendered({

    $window.Focus()
    [System.Windows.Input.Keyboard]::Focus($window)

})

$helpOverlay = $window.FindName("HelpOverlay")

$window.ShowDialog() | Out-Null

$scroller = $window.FindName("Scroller")
$promptText = $window.FindName("PromptText")
$helpOverlay = $window.FindName("HelpOverlay")