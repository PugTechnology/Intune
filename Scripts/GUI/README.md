# Help Desk Toolkit GUI

This project is a dynamic, WPF-based PowerShell GUI designed to provide end-users and Help Desk staff with a simple, one-click interface for running common troubleshooting scripts.

It is built to be deployed via Microsoft Intune as a Win32 application, with support for standard user scripts and a hidden menu for admin-only scripts.

## Features

* **Dynamic Button Loading:** The GUI automatically scans `.\Scripts` and `.\AdminScripts` folders on launch and creates a button for every `.ps1` file it finds.

* **Hidden Admin Menu:** A "Konami Code" (`Up, Up, Down, Down, Left, Right, Left, Right`) reveals an "Admin Tools" section with its own scripts.

* **Self-Elevating Scripts:** Admin scripts can contain logic to self-elevate, triggering the standard Windows UAC prompt for credentials.

* **Asynchronous Feedback:** Clicking a script disables the button, changes the text to "Running...", and runs the script in a hidden background process. The button is re-enabled when the script is complete.

* **Custom Branding:** The GUI displays a company logo and provides "Contact Us" links (Email, Website).

* **Secure Deployment:** Designed to be code-signed, removing the need for `ExecutionPolicy Bypass` and adhering to a secure `AllSigned` environment.

## File Architecture

The final package is structured as follows:



\Intune-Package-Source

|
+--- install.ps1                 (The main installer script run by Intune)
+--- HelpDesk-Tools.ps1          (The main GUI application script)
+--- icon.ico                    (The icon for the Start Menu shortcut)
+--- logo.png                    (The logo displayed inside the GUI)
|
+--- \Scripts\                   (Folder for standard user scripts)
|    +--- 01-Reset-Teams-Cache.ps1
|    +--- 02-Reset-Chrome.ps1
|
+--- \AdminScripts\              (Folder for admin-only scripts)
|    +--- 01-Force-GPUpdate.ps1
|    +--- 99-Test-Admin-Rights.ps1


### Key Files

1. **`HelpDesk-Tools.ps1`**

   * This is the main application. It's a PowerShell script that builds and displays a WPF GUI.

   * It dynamically loads buttons from its sub-folders.

   * It handles the Konami code, button-click logic (with "Running..." feedback), and timer-based polling to check when a script finishes.

2. **`install.ps1`**

   * This is the installer script for Intune.

   * It copies all the application files and script folders to `C:\ProgramData\CompanyTools`.

   * It creates the Start Menu shortcut in `Start > Company Name > Help Desk GUI`.

   * The shortcut is configured to use the custom `icon.ico` and run the script correctly so that UAC prompts are allowed.

3. **Plugin Scripts (`\Scripts\` & `\AdminScripts\`)**

   * These are the individual "action" scripts.

   * They are run in a hidden window.

   * **Crucially, they must provide their own user feedback**, such as a pop-up box (e.g., `[System.Windows.MessageBox]::Show(...)`), to tell the user the task is complete.

## Deployment with Intune

1. **Prepare the Package:**

   * Ensure all your scripts (GUI, installer, plugins) are **code-signed** if your environment uses an `AllSigned` execution policy.

   * Place all the files in the source directory as shown in the architecture above.

2. **Package the App:**

   * Use the Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`) to package your source directory into a single `.intunewin` file.

3. **Upload to Intune:**

   * In the Intune admin center, go to **Apps > Windows > Add**.

   * Select **Windows app (Win32)**.

   * Upload your `.intunewin` file.

4. **Configure in Intune:**

   * **Program:**

     * **Install command:** `powershell.exe -ExecutionPolicy Bypass -File .\install.ps1` (Use `Bypass` here *only* for the installer, or remove if your installer is also signed).

     * **Uninstall command:** (You would need to create a corresponding `uninstall.ps1` script).

     * **Install behavior:** `System`

   * **Requirements:** Set your OS and architecture requirements (e.g., 64-bit).

   * **Detection rules:**

     * **Rule type:** `File`

     * **Path:** `C:\ProgramData\CompanyTools`

     * **File or folder:** `HelpDesk-Tools.ps1`

     * **Detection method:** `File or folder exists`

   * Assign the app to your target device group.

## How to Add New Scripts (Updating)

Updating the tool with new scripts is simple and does **not** require creating a new app.

1. **Add Your New Script:**

   * Place your new script (e.g., `03-Clear-Print-Spooler.ps1`) into the `\Scripts` or `\AdminScripts` folder in your **source package directory**.

   * If it's an admin script, make sure it contains its own self-elevation logic (like the `99-Test-Admin-Rights.ps1` example).

2. **Re-Package:**

   * Run the `IntuneWinAppUtil.exe` tool on your source directory again to create an updated `.intunewin` file.

3. **Update in Intune:**

   * Go to your existing Win32 app in Intune.

   * Go to **Properties**.

   * In the **App package file** section, upload your new `.intunewin` file.

   * Save the changes.

Intune will detect the new version and push the update to all clients. The `install.ps1` will run again, copying your new script, and it will automatically appear in the GUI on the next launch.
