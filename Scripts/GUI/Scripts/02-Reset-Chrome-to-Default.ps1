function Invoke-ResetChrome {
    # 1. Kill Chrome
    Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue

    # 2. Define path
    $chromeProfilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    
    # 3. Rename the 'Default' profile folder. This forces Chrome to create a new one.
    if (Test-Path $chromeProfilePath) {
        try {
            # Append .old with a timestamp
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Rename-Item -Path $chromeProfilePath -NewName "Default.old-$timestamp" -ErrorAction Stop
            return $true
        }
        catch {
            return $false
        }
    }
}

$success = Invoke-ResetChrome

# --- Add Feedback Popup ---
Add-Type -AssemblyName PresentationFramework
if ($success) {
    [System.Windows.MessageBox]::Show(
        "Chrome profile has been reset. Your old profile is saved as 'Default.old'.", 
        "Task Complete", 
        "OK", 
        "Information"
    )
}
else {
    [System.Windows.MessageBox]::Show(
        "Could not reset Chrome profile. It may not have existed or was in use.", 
        "Error", 
        "OK", 
        "Error"
    )
}
