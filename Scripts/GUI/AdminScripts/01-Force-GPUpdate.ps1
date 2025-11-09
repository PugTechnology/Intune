# File: C:\ProgramData\CompanyTools\AdminScripts\01-Force-GPUpdate.ps1

try {
    gpupdate /force
    $Message = "Group Policy has been successfully updated."
    $Title = "Task Complete"
    $Icon = "Information"
}
catch {
    $Message = "An error occurred while forcing Group Policy update: $_"
    $Title = "Error"
    $Icon = "Error"
}

# --- Add Feedback Popup ---
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show($Message, $Title, "OK", $Icon)
