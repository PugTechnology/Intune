# Help Desk Toolkit GUI

A dynamic PowerShell-based GUI for Help Desk tasks. This tool is designed for front-line Help Desk technicians (Tier 1 support) to streamline common tasks and run PowerShell scripts without needing to directly interact with the command line.

## Features

*   **Dynamic Script Loading:** Automatically creates buttons for each `.ps1` script found in the `.\Scripts` subdirectory.
*   **User-Friendly Interface:** Provides a simple and intuitive graphical interface for running scripts.
*   **Customizable:** Includes a version with a customizable company logo.
*   **Easy to Deploy:** Can be deployed as a Win32 package via Intune.

## Prerequisites

*   **Operating System:** Windows 10/11
*   **PowerShell Version:** 5.1

## How to Use

To launch the GUI, run one of the following scripts:

*   `HelpDesk-Tools.ps1`: The standard version of the GUI.
*   `HelpDesk-Tools-Logo.ps1`: A version that includes a company logo.

### Customizing the Logo

To customize the logo in the `HelpDesk-Tools-Logo.ps1` version, simply replace the `logo.png` file in this directory with your own company's logo. The GUI is designed for a logo with a height of 60 pixels.

## Adding New Scripts

To add a new script to the GUI, follow these steps:

1.  Create a new `.ps1` file in the `.\Scripts` subdirectory.
2.  Number the script file in the order you want it to appear in the GUI. For example:
    *   `01-Reset-Teams-Cache.ps1`
    *   `02-Reset-Chrome-to-Default.ps1`
3.  The script will automatically appear as a button in the GUI. The button's text will be generated from the script's filename (e.g., "Reset Teams Cache").

## Installation (for IT Administrators)

The `install.ps1` script is provided for deploying the Help Desk Toolkit as a Win32 package through Microsoft Intune. This script will handle the installation and setup process, including creating a Start Menu shortcut for easy access.
