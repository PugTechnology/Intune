<#
.SYNOPSIS
    A self-elevating script to test UAC functionality.
.DESCRIPTION
    1. Checks if it is running as Admin.
    2. If YES, it shows a "Success" message.
    3. If NO, it asks the user (Yes/No) if they want to elevate.
    4. If user clicks "Yes", it re-launches itself as Admin (triggering UAC)
       and *waits* for the admin process to finish.
    5. If user clicks "No", it exits.
#>

# --- Load Required Assemblies ---
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms # For the Yes/No box

# --- Check for Admin Rights ---
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal $identity
$isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    # 1. WE ARE ADMIN
    # This is the "elevated" instance of the script.
    [System.Windows.MessageBox]::Show(
        "This script is now running as an Administrator.", 
        "UAC Test: SUCCESS", 
        "OK", 
        "Information"
    )
    # The script exits here.
}
else {
    # 2. WE ARE A STANDARD USER
    # Ask the user if they want to elevate.
    $question = "This script requires admin rights to continue.`n`nDo you want to elevate (triggers UAC)?"
    $result = [System.Windows.Forms.MessageBox]::Show(
        $question, 
        "UAC Test: Elevation Required", 
        "YesNo", 
        "Warning"
    )
    
    if ($result -eq "Yes") {
        # 3. RE-LAUNCH AS ADMIN
        try {
            # We re-launch *this script file* using -Verb RunAs.
            # -Wait is CRITICAL. It forces this (non-admin) script
            # to pause until the new admin script is closed.
            # This keeps the GUI's "Running..." button active.
            $processArgs = @{
                FilePath     = "powershell.exe"
                ArgumentList = "-File `"$($MyInvocation.MyCommand.Definition)`""
                Verb         = "RunAs"
                Wait         = $true
            }
            Start-Process @processArgs
        }
        catch {
            # User may have clicked "No" on the UAC prompt
            [System.Windows.MessageBox]::Show(
                "Failed to elevate. The UAC prompt may have been cancelled.", 
                "UAC Test: Canceled", 
                "OK", 
                "Warning"
            )
        }
    }
    else {
        # 4. USER CLICKED "NO"
        # Do nothing and exit.
    }
    
    # This (non-admin) script exits here, after the -Wait is satisfied
    # or the user clicked "No".
}
