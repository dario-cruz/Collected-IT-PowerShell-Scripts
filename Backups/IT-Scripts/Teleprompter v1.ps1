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
                       FontSize="42"
                       FontFamily="Segoe UI"
                       TextWrapping="Wrap"
                       Margin="100"
                       TextAlignment="Center"/>
        </ScrollViewer>
    </Grid>

</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$scroller = $window.FindName("Scroller")
$promptText = $window.FindName("PromptText")

$promptText.Text = $text

# Scrolling control
$scrollSpeed = 1
$isRunning = $true

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

# Keyboard controls
$window.Add_KeyDown({

    switch ($_.Key) {

        "Space" {
            $script:isRunning = -not $script:isRunning
        }

        "Add" {
            $script:scrollSpeed += 0.5
        }

        "OemPlus" {
            $script:scrollSpeed += 0.5
        }

        "Subtract" {
            if ($script:scrollSpeed -gt 0.5) {
                $script:scrollSpeed -= 0.5
            }
        }

        "OemMinus" {
            if ($script:scrollSpeed -gt 0.5) {
                $script:scrollSpeed -= 0.5
            }
        }

        "Escape" {
            $window.Close()
        }
    }
})

$window.ShowDialog() | Out-Null