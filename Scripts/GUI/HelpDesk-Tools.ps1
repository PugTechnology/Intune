<#
.SYNOPSIS
    A *dynamic* PowerShell-based GUI for Help Desk tasks.
.DESCRIPTION
    Scans a '.\Scripts' sub-directory and dynamically creates a
    button for each .ps1 file it finds.
#>

# --- Load WPF Assemblies ---
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- Define Paths ---
# The main script assumes its "plugin" scripts are in a folder named 'Scripts'
# located in the same directory as the script itself.
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ScriptsFolder = Join-Path $ScriptRoot "Scripts"

#=================================================================
# DEFINE THE GUI LAYOUT (XAML)
#=================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Help Desk Toolkit" 
        Width="350" MinHeight="300" MaxHeight="600"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        WindowStyle="SingleBorderWindow">
    
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0">
             <Label Content="Help Desk Self-Service" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center" />
            <TextBlock TextWrapping="Wrap" Margin="0,5,0,15" HorizontalAlignment="Center">
                Click a button below to run a fix.
            </TextBlock>
        </StackPanel>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="ButtonContainer" Orientation="Vertical" />
        </ScrollViewer>
        
        <Button x:Name="btnClose" 
                Content="Close" 
                Grid.Row="2"
                VerticalAlignment="Bottom" 
                HorizontalAlignment="Right" 
                Width="80" 
                Padding="5" 
                Margin="0,15,0,0" />
    </Grid>
</Window>
"@

#=================================================================
# BUILD & LAUNCH THE GUI
#=================================================================
try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $Window = [System.Windows.Markup.XamlReader]::Load($reader)

    # Find the GUI elements
    $btnClose = $Window.FindName("btnClose")
    $ButtonContainer = $Window.FindName("ButtonContainer")

    $btnClose.Add_Click({
        $Window.Close()
    })

    # --- DYNAMICALLY LOAD SCRIPT BUTTONS ---
    
    # Check if the Scripts folder exists
    if (-not (Test-Path $ScriptsFolder)) {
        New-Item -Path $ScriptsFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Find all .ps1 files, sort them by name
    $ScriptFiles = Get-ChildItem -Path $ScriptsFolder -Filter "*.ps1" | Sort-Object Name
    
    if ($ScriptFiles.Count -eq 0) {
        $ButtonContainer.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{
            Text = "No scripts found in '.\Scripts' folder."
            Margin = "0,10"
        }))
    }

    foreach ($ScriptFile in $ScriptFiles) {
        # Format the button text. "01-Reset-Teams.ps1" -> "Reset Teams"
        $ButtonText = $ScriptFile.BaseName -replace '^\d+[-_]\s*', '' -replace '[-_]', ' '
        
        # Create a new button
        $NewButton = New-Object System.Windows.Controls.Button -Property @{
            Content = $ButtonText
            FontSize = 14
            Margin = "0,5"
            Padding = "10"
            Tag = $ScriptFile.FullName  # <-- Store the script path in the 'Tag' property
        }
        
        # Define the click action
        $NewButton.Add_Click({
            param($sender, $e)
            
            $Button = $sender
            $ScriptToRun = $Button.Tag # <-- Get the path from the 'Tag'
            
            try {
                $Button.Content = "Running..."
                $Button.IsEnabled = $false
                
                # Run the script in a new, hidden PowerShell process
                Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptToRun`"" -WindowStyle Hidden -Wait
            }
            catch {
                [System.Windows.MessageBox]::Show("Error running script: $_", "Error", "OK", "Error")
            }
            finally {
                # Re-enable the button
                $Button.Content = $ButtonText
                $Button.IsEnabled = $true
            }
        })
        
        # Add the new button to the GUI
        $ButtonContainer.Children.Add($NewButton)
    }

    # Show the window
    $Window.ShowDialog() | Out-Null

}
catch {
    Write-Error "Failed to load WPF GUI. Error: $_"
    [System.Windows.MessageBox]::Show("Failed to load GUI: $_", "Error", "OK", "Error")
}