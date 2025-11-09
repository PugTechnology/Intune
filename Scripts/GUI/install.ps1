<#
.SYNOPSIS
    Installer script for the Help Desk Toolkit.
.DESCRIPTION
    This script is run by Intune (as a Win32 App). It creates a
    shortcut that uses an EncodedCommand to reliably launch the
    GUI without quoting or escaping issues.
.NOTES
    This script assumes the following files are in the same directory:
    - HelpDesk-Tools.ps1
    - icon.ico (Your company icon)
    - logo.png (optional)
    - \Scripts\ (folder)
    - \AdminScripts\ (folder)
#>

# 1. Define paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Source files (in the Intune package)
$SourceGuiFile = Join-Path $ScriptRoot "HelpDesk-Tools.ps1"
$SourceLogoFile = Join-Path $ScriptRoot "logo.png"
$SourceIconFile = Join-Path $ScriptRoot "icon.ico"
$SourceScriptsFolder = Join-Path $ScriptRoot "Scripts"
$SourceAdminScriptsFolder = Join-Path $ScriptRoot "AdminScripts"

# Install destination (on the target machine)
$InstallDir = "C:\ProgramData\CompanyTools"
$InstallGuiFile = Join-Path $InstallDir "HelpDesk-Tools.ps1"
$InstallLogoFile = Join-Path $InstallDir "logo.png"
$InstallIconFile = Join-Path $InstallDir "icon.ico"
$InstallScriptsFolder = Join-Path $InstallDir "Scripts"
$InstallAdminScriptsFolder = Join-Path $InstallDir "AdminScripts"

$StartMenuProgramsPath = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
$StartMenuCompanyFolder = Join-Path $StartMenuProgramsPath "Company Name"
$StartMenuLink = Join-Path $StartMenuCompanyFolder "Help Desk GUI.lnk"

# 2. Create install directories
try {
    Write-Host "Creating directories..."
    if (-not (Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory -Force }
    if (-not (Test-Path $InstallScriptsFolder)) { New-Item -Path $InstallScriptsFolder -ItemType Directory -Force }
    if (-not (Test-Path $InstallAdminScriptsFolder)) { New-Item -Path $InstallAdminScriptsFolder -ItemType Directory -Force }
    
    if (-not (Test-Path $StartMenuCompanyFolder)) {
        New-Item -Path $StartMenuCompanyFolder -ItemType Directory -Force
    }

    # 3. Copy all files
    Write-Host "Copying tool files..."
    Copy-Item -Path $SourceGuiFile -Destination $InstallGuiFile -Force
    Copy-Item -Path $SourceLogoFile -Destination $InstallLogoFile -Force -ErrorAction SilentlyContinue
    Copy-Item -Path $SourceIconFile -Destination $InstallIconFile -Force -ErrorAction SilentlyContinue

    Write-Host "Copying scripts..."
    Copy-Item -Path "$SourceScriptsFolder\*" -Destination $InstallScriptsFolder -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$SourceAdminScriptsFolder\*" -Destination $InstallAdminScriptsFolder -Recurse -Force -ErrorAction SilentlyContinue

    # 4. Create the Start Menu shortcut
    Write-Host "Creating Start Menu shortcut..."
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($StartMenuLink)
    
    $shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    
    # --- ENCODED COMMAND LOGIC ---
    # The command we want to run is just the path to our script.
    # The '&' (call operator) ensures it runs.
    $CommandToRun = "& '$InstallGuiFile'"
    
    # Convert that command string to Base64
    $EncodedCommand = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($CommandToRun))
    
    # Set the shortcut argument to -EncodedCommand
    # This bypasses all quoting, execution policy, and pathing issues.
    $shortcut.Arguments = "-EncodedCommand $EncodedCommand"
    # --- END OF ENCODED COMMAND LOGIC ---
    
    # Set the 'Start in' folder so the GUI can find its logo and scripts
    $shortcut.WorkingDirectory = $InstallDir 
    
    $shortcut.Description = "Help Desk Self-Service Toolkit"
    
    # Set the icon for the shortcut
    if (Test-Path $InstallIconFile) {
        $shortcut.IconLocation = $InstallIconFile
    }
    else {
        # Fallback to a default system icon if icon.ico is missing
        $shortcut.IconLocation = "%SystemRoot%\System32\imageres.dll,111"
    }
    
    $shortcut.Save()

    Write-Host "Help Desk Tools installed and Start Menu shortcut created."
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}
