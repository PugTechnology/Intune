function Invoke-ResetTeamsCache {
    # 1. Kill all Teams processes
    Stop-Process -Name "Teams" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "ms-teams" -Force -ErrorAction SilentlyContinue
    
    # 2. Define Cache Paths
    $classicTeamsPath = "$env:APPDATA\Microsoft\Teams"
    $newTeamsPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe"

    # 3. Clear Classic Teams Cache
    if (Test-Path $classicTeamsPath) {
        Get-ChildItem -Path $classicTeamsPath -Directory | Where-Object { $_.Name -ne "Update.exe" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $classicTeamsPath -File | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # 4. Clear New Teams Cache
    if (Test-Path $newTeamsPath) {
        $newCacheFolders = @(
            "$newTeamsPath\LocalCache\Microsoft\MSTeams",
            "$newTeamsPath\LocalCache\Microsoft\Window" 
        )
        foreach ($folder in $newCacheFolders) {
            if (Test-Path $folder) {
                Remove-Item -Recurse -Force -Path $folder -ErrorAction SilentlyContinue
            }
        }
    }
}

Invoke-ResetTeamsCache

# --- Add Feedback Popup ---
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
    "Teams cache has been cleared. Please restart Teams.", 
    "Task Complete", 
    "OK", 
    "Information"
)
