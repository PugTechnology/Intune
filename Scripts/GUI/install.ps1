# File: install.ps1 (at the root of your Intune package)

# 1. Define paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SourceGuiFile = Join-Path $ScriptRoot "HelpDesk-Tools.ps1"
$SourceScriptsFolder = Join-Path $ScriptRoot "Scripts"

$InstallDir = "C:\ProgramData\CompanyTools"
$InstallGuiFile = Join-Path $InstallDir "HelpDesk-Tools.ps1"
$InstallScriptsFolder = Join-Path $InstallDir "Scripts"
$StartMenuLink = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Help Desk Toolkit.lnk"

# 2. Create install directories
if (-not (Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory -Force }
if (-not (Test-Path $InstallScriptsFolder)) { New-Item -Path $InstallScriptsFolder -ItemType Directory -Force }

# 3. Copy the main GUI script
Copy-Item -Path $SourceGuiFile -Destination $InstallGuiFile -Force

# 4. Copy all "action" scripts
Copy-Item -Path "$SourceScriptsFolder\*" -Destination $InstallScriptsFolder -Recurse -Force

# 5. Create the Start Menu shortcut
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($StartMenuLink)
$shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
# We must set the WorkingDirectory so the GUI can find its '.\Scripts' folder!
$shortcut.WorkingDirectory = $InstallDir 
$shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstallGuiFile`""
$shortcut.Description = "Run common Help Desk fixes."
$shortcut.Save()

Write-Host "Dynamic Help Desk Tools installed successfully."