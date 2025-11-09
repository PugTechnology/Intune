<#
.SYNOPSIS
    A dynamic PowerShell-based GUI for Help Desk tasks with a
    hidden admin menu.
.DESCRIPTION
    This script is launched from a shortcut (via EncodedCommand).
    A console will flash briefly, which is required to allow
    UAC prompts to function.
#>

# --- Load WPF Assemblies ---
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- Define Paths ---
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogoFile = Join-Path $ScriptRoot "logo.png"
$ScriptsFolder = Join-Path $ScriptRoot "Scripts"
$AdminScriptsFolder = Join-Path $ScriptRoot "AdminScripts" 

# --- Secret Code State ---
$global:SecretCode = "Up,Up,Down,Down,Left,Right,Left,Right"
$global:KeyHistory = [System.Collections.Generic.List[string]]::new()
$global:AdminScriptsLoaded = $false 

#=================================================================
# DEFINE THE GUI LAYOUT (XAML)
#=================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Help Desk Toolkit" 
        Width="350" MinHeight="400" MaxHeight="800"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        WindowStyle="SingleBorderWindow">
    
    <Window.Resources>
        <!-- This style fixes the color of the admin buttons -->
        <Style x:Key="AdminButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#CC0000" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="FontSize" Value="14" />
            <Setter Property="Margin" Value="0,5" />
            <Setter Property="Padding" Value="10" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="#888" BorderThickness="1" CornerRadius="3">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#E60000" />
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#990000" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0">
            <Image x:Name="imgLogo" Height="60" Margin="0,0,0,10" Visibility="Collapsed" />
             <Label Content="Help Desk Self-Service" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center" />
            <TextBlock TextWrapping="Wrap" Margin="0,5,0,15" HorizontalAlignment="Center">
                Click a button below to run a fix.
            </TextBlock>
        </StackPanel>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="ButtonContainer" Orientation="Vertical" />
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Margin="0,15,0,0">
            <Separator />
            <TextBlock Text="Need more help? Contact the Help Desk:" 
                       Margin="0,10,0,5" HorizontalAlignment="Center" FontSize="11" />
            <TextBlock HorizontalAlignment="Center" FontWeight="Bold" FontSize="12">
                <Run Text="Email:"/>
                <Hyperlink NavigateUri="mailto:helpdesk@yourcompany.com">
                    helpdesk@yourcompany.com
                </Hyperlink>
            </TextBlock>
            <TextBlock HorizontalAlignment="Center" FontWeight="Bold" FontSize="12" Margin="0,2,0,0">
                <Run Text="Website:"/>
                <Hyperlink NavigateUri="https://helpdesk.yourcompany.com">
                    helpdesk.yourcompany.com
                </Hyperlink>
            </TextBlock>
        </StackPanel>
        
        <Button x:Name="btnClose" 
                Content="Close" 
                Grid.Row="3" 
                VerticalAlignment="Bottom" HorizontalAlignment="Right" 
                Width="80" Padding="5" Margin="0,15,0,0" />
    </Grid>
</Window>
"@

#=========================================================
# --- DYNAMIC SCRIPT LOADING FUNCTIONS ---
#=========================================================

# Function to create and add a button for a script
function Add-ScriptButton {
    param(
        [System.IO.FileInfo]$ScriptFile,
        [System.Windows.Controls.StackPanel]$Container,
        [string]$ButtonColor = $null
    )
    
    $ButtonText = $ScriptFile.BaseName -replace '^\d+[-_]\s*', '' -replace '[-_]', ' '
    
    $NewButton = New-Object System.Windows.Controls.Button -Property @{
        Content = $ButtonText
        FontSize = 14
        Margin = "0,5"
        Padding = "10"
        Tag = $ScriptFile.FullName 
    }
    
    if ($ButtonColor) {
        $NewButton.Style = $Window.FindResource("AdminButtonStyle")
    }

    # Asynchronous Button click logic with Timer Polling
    $NewButton.Add_Click({
        param($sender, $e)
        
        $Button = $sender
        $ScriptToRun = $Button.Tag 
        
        $OriginalText = $Button.Content
        
        try {
            $Button.IsEnabled = $false
            $Button.Content = "Running..."
            
            # The GUI will run *all* scripts as a standard,
            # hidden process. The script itself is responsible
            # for self-elevation if it needs it.
            $ProcessArgs = @{
                FilePath     = "powershell.exe"
                ArgumentList = "-File `"$ScriptToRun`"" 
                PassThru     = $true
                WindowStyle  = "Hidden"
            }
            
            $Process = Start-Process @ProcessArgs

            # Create a GUI-thread timer to poll for process exit
            $PollTimer = New-Object System.Windows.Threading.DispatcherTimer
            $PollTimer.Interval = [TimeSpan]::FromMilliseconds(250)
            
            # Store the objects we need to check/reset
            # We add them to the timer object itself to avoid scoping issues
            $PollTimer | Add-Member -MemberType NoteProperty -Name "Process" -Value $Process
            $PollTimer | Add-Member -MemberType NoteProperty -Name "ButtonToReset" -Value $Button
            $PollTimer | Add-Member -MemberType NoteProperty -Name "TextToRestore" -Value $OriginalText
            
            # This is the code that runs every 250ms
            $PollTimer.Add_Tick({
                param($timerSender, $timerArgs)
                
                # '$this' is the timer object
                $Proc = $this.Process
                $Btn = $this.ButtonToReset
                
                # Check if the process has exited
                if ($Proc.HasExited) {
                    # Process is done, stop the timer
                    $this.Stop()
                    
                    # Reset the button
                    $Btn.Content = $this.TextToRestore
                    $Btn.IsEnabled = $true
                }
            })
            
            $PollTimer.Start()
        }
        catch {
            [System.Windows.MessageBox]::Show("Error starting script: $_", "Error", "OK", "Error")
            # Reset the button on failure
            $Button.Content = $OriginalText
            $Button.IsEnabled = true
        }
    })
    
    $Container.Children.Add($NewButton)
}

# Function to load Admin Scripts (called by Konami)
function Load-AdminScripts {
    if ($global:AdminScriptsLoaded) { return } 
    $global:AdminScriptsLoaded = $true
    
    if ($global:ButtonContainer) {
        $global:ButtonContainer.Children.Add((New-Object System.Windows.Controls.Separator -Property @{ Margin = "0,15,0,5" }))
        $global:ButtonContainer.Children.Add((New-Object System.Windows.Controls.Label -Property @{
            Content = "Admin Tools"
            FontWeight = [System.Windows.FontWeights]::Bold
            HorizontalAlignment = "Center"
        }))

        $AdminScriptFiles = Get-ChildItem -Path $AdminScriptsFolder -Filter "*.ps1" | Sort-Object Name
        
        if ($AdminScriptFiles.Count -eq 0) {
            $global:ButtonContainer.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = "No admin scripts found." }))
        }

        foreach ($ScriptFile in $AdminScriptFiles) {
            Add-ScriptButton -ScriptFile $ScriptFile -Container $global:ButtonContainer -ButtonColor "DarkRed"
        }
    }
}

#=================================================================
# BUILD & LAUNCH THE GUI
#=================================================================
try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $global:Window = [System.Windows.Markup.XamlReader]::Load($reader)

    # Find GUI elements and assign to GLOBAL variables
    $global:imgLogo = $global:Window.FindName("imgLogo")
    $global:btnClose = $global:Window.FindName("btnClose")
    $global:ButtonContainer = $global:Window.FindName("ButtonContainer")

    # Hyperlink Click Handler (for Email and Website)
    if ($global:Window) {
        $global:Window.AddHandler(
            [System.Windows.Documents.Hyperlink]::RequestNavigateEvent,
            [System.Windows.Navigation.RequestNavigateEventHandler]{
                param($sender, $e)
                if ($e.Uri) {
                    try { Start-Process $e.Uri.AbsoluteUri -UseNewEnvironment } 
                    catch { Write-Warning "Failed to open hyperlink: $_" }
                }
            }
        )
    }

    # Close Button
    if ($global:btnClose) {
        $global:btnClose.Add_Click({ $global:Window.Close() })
    }

    # Load Logo
    if ($global:imgLogo -and (Test-Path $LogoFile)) {
        try {
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = (New-Object System.Uri($LogoFile, [System.UriKind]::Absolute))
            $bmp.EndInit()
            $global:imgLogo.Source = $bmp
            $global:imgLogo.Visibility = "Visible"
        } catch { Write-Warning "Failed to load logo image: $_" }
    }

    # Load USER Scripts (on startup)
    if ($global:ButtonContainer) {
        if (-not (Test-Path $ScriptsFolder)) {
            New-Item -Path $ScriptsFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        }
        
        $ScriptFiles = Get-ChildItem -Path $ScriptsFolder -Filter "*.ps1" | Sort-Object Name
        
        if ($ScriptFiles.Count -eq 0) {
            $global:ButtonContainer.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = "No scripts found." }))
        }

        foreach ($ScriptFile in $ScriptFiles) {
            Add-ScriptButton -ScriptFile $ScriptFile -Container $global:ButtonContainer
        }
    }

    # KONAMI CODE LISTENER
    if ($global:Window) {
        $global:Window.Add_PreviewKeyDown({
            param($sender, $e)
            
            $Key = $e.Key.ToString()
            
            if ("Up", "Down", "Left", "Right" -contains $Key) {
                $global:KeyHistory.Add($Key)
                
                $MaxHistory = $global:SecretCode.Split(',').Count
                if ($global:KeyHistory.Count -gt $MaxHistory) {
                    $global:KeyHistory.RemoveAt(0) 
                }
                
                $CurrentSequence = [string]::Join(",", $global:KeyHistory)
                
                if ($CurrentSequence -eq $global:SecretCode) {
                    Load-AdminScripts
                    $global:KeyHistory.Clear()
                }
            }
            else {
                $global:KeyHistory.Clear()
            }
        })
    }

    # Show the window
    $global:Window.ShowDialog() | Out-Null
}
catch {
    Write-Error "Failed to load WPF GUI. Error: $_"
    Write-Error $_.Exception.StackTrace
    [System.Windows.MessageBox]::Show("Failed to load GUI: $_", "Error", "OK", "Error")
}
