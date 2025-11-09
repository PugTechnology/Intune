<#
.SYNOPSIS
    A dynamic PowerShell-based GUI for Help Desk tasks.
.DESCRIPTION
    Scans a '.\Scripts' sub-directory for .ps1 files, builds
    buttons for them, and displays a company logo and contact info.
#>

# --- Load WPF Assemblies ---
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- Define Paths ---
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ScriptsFolder = Join-Path $ScriptRoot "Scripts"
# Define the logo file we expect to find
$LogoFile = Join-Path $ScriptRoot "logo.png"

#=================================================================
# DEFINE THE GUI LAYOUT (XAML)
#=================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Help Desk Toolkit" 
        Width="350" MinHeight="450" MaxHeight="800"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        WindowStyle="SingleBorderWindow">
    
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" /> <!-- Logo & Title -->
            <RowDefinition Height="*" />   <!-- Buttons -->
            <RowDefinition Height="Auto" /> <!-- Contact Info -->
            <RowDefinition Height="Auto" /> <!-- Close Button -->
        </Grid.RowDefinitions>
        
        <!-- Logo and Title Block -->
        <StackPanel Grid.Row="0">
            
            <!-- Logo will be loaded here by PowerShell -->
            <!-- We set it to Collapsed so it doesn't take up -->
            <!-- space if the logo.png is missing. -->
            <Image x:Name="imgLogo" 
                   Height="60" 
                   Margin="0,0,0,10" 
                   Visibility="Collapsed" />
            
             <Label Content="Help Desk Self-Service" 
                    FontSize="16" 
                    FontWeight="Bold" 
                    HorizontalAlignment="Center" />
            <TextBlock TextWrapping="Wrap" 
                       Margin="0,5,0,15" 
                       HorizontalAlignment="Center">
                Click a button below to run a fix.
            </TextBlock>
        </StackPanel>
        
        <!-- Dynamic Button Container -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="ButtonContainer" Orientation="Vertical" />
        </ScrollViewer>
        
        <!-- Contact Info Block -->
        <StackPanel Grid.Row="2" Margin="0,15,0,0">
            <Separator />
            <TextBlock Text="Need more help? Contact the Help Desk:" 
                       Margin="0,10,0,5" 
                       HorizontalAlignment="Center" 
                       FontSize="11" />
            <TextBlock HorizontalAlignment="Center" FontWeight="Bold" FontSize="12">
                <Run Text="Email:"/>
                <Hyperlink NavigateUri="mailto:helpdesk@yourcompany.com">
                    helpdesk@yourcompany.com
                </Hyperlink>
            </TextBlock>
            <TextBlock Text="Phone: 123-456-7890" 
                       Margin="0,2,0,0" 
                       HorizontalAlignment="Center" 
                       FontWeight="Bold" 
                       FontSize="12" />
        </StackPanel>
        
        <!-- Close Button -->
        <Button x:Name="btnClose" 
                Content="Close" 
                Grid.Row="3"
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
    $imgLogo = $Window.FindName("imgLogo")
    $btnClose = $Window.FindName("btnClose")
    $ButtonContainer = $Window.FindName("ButtonContainer")

    # --- Add Click Handler for Hyperlink (Email) ---
    # This finds all Hyperlinks and adds an event to open them
    $Window.AddHandler(
        [System.Windows.Documents.Hyperlink]::RequestNavigateEvent,
        [System.Windows.Navigation.RequestNavigateEventHandler]{
            param($sender, $e)
            if ($e.Uri) {
                try {
                    Start-Process $e.Uri.AbsoluteUri -UseNewEnvironment
                }
                catch {
                    Write-Warning "Failed to open hyperlink: $_"
                }
            }
        }
    )

    $btnClose.Add_Click({
        $Window.Close()
    })

    # --- DYNAMICALLY LOAD LOGO ---
    if (Test-Path $LogoFile) {
        try {
            # Create a new BitmapImage
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            # We must use an absolute path for the UriSource
            $bmp.UriSource = (New-Object System.Uri($LogoFile, [System.UriKind]::Absolute))
            $bmp.EndInit()
            
            # Set the image source and make it visible
            $imgLogo.Source = $bmp
            $imgLogo.Visibility = "Visible"
        }
        catch {
            Write-Warning "Failed to load logo image from $LogoFile. Error: $_"
        }
    }
    else {
        Write-Host "logo.png not found at $LogoFile. Skipping."
    }

    # --- DYNAMICALLY LOAD SCRIPT BUTTONS ---
    if (-not (Test-Path $ScriptsFolder)) {
        New-Item -Path $ScriptsFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    }
    
    $ScriptFiles = Get-ChildItem -Path $ScriptsFolder -Filter "*.ps1" | Sort-Object Name
    
    if ($ScriptFiles.Count -eq 0) {
        $ButtonContainer.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{
            Text = "No scripts found in '.\Scripts' folder."
            Margin = "0,10"
        }))
    }

    foreach ($ScriptFile in $ScriptFiles) {
        $ButtonText = $ScriptFile.BaseName -replace '^\d+[-_]\s*', '' -replace '[-_]', ' '
        
        $NewButton = New-Object System.Windows.Controls.Button -Property @{
            Content = $ButtonText
            FontSize = 14
            Margin = "0,5"
            Padding = "10"
            Tag = $ScriptFile.FullName
        }
        
        $NewButton.Add_Click({
            param($sender, $e)
            $Button = $sender
            $ScriptToRun = $Button.Tag
            try {
                $Button.Content = "Running..."
                $Button.IsEnabled = $false
                Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptToRun`"" -WindowStyle Hidden -Wait
            }
            catch {
                [System.Windows.MessageBox]::Show("Error running script: $_", "Error", "OK", "Error")
            }
            finally {
                $Button.Content = $ButtonText
                $Button.IsEnabled = $true
            }
        })
        
        $ButtonContainer.Children.Add($NewButton)
    }

    # Show the window
    $Window.ShowDialog() | Out-Null
}
catch {
    Write-Error "Failed to load WPF GUI. Error: $_"
    [System.Windows.MessageBox]::Show("Failed to load GUI: $_", "Error", "OK", "Error")
}