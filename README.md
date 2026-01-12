# Windows Workstation Setup

Automated PowerShell script for ephemeral Windows sandbox environments. Installs and configures development tools with a single command.

## What Gets Installed

- **PowerShell 7** - Latest PowerShell version
- **Git for Windows** - Version control with your identity pre-configured
- **GitHub CLI (gh)** - Command-line interface for GitHub
- **Visual Studio Code** - Code editor
- **Claude Code Extension** - AI coding assistant for VS Code
- **Python 3.13** - Python programming language with default options
- **Google Chrome** - Web browser (set as system default)

## Quick Start

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/themccomasunit/windows-workstation-setup/master/bootstrap.ps1 | iex
```

The script will:
1. Download the setup files
2. Install winget if not present
3. Install PowerShell 7, Git, GitHub CLI, VS Code, Python 3.13, and Google Chrome via winget
4. Configure Git with your identity
5. Install Claude Code extension
6. Fix Python PATH priority to prevent Windows Store prompt
7. Set Google Chrome as the default browser
8. Guide you through GitHub CLI authentication
9. Automatically open VS Code and launch Claude Code authentication

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges
- Internet connection

## Manual Installation

If you prefer to run the setup locally:

```powershell
# Clone the repository
git clone https://github.com/themccomasunit/windows-workstation-setup.git
cd windows-workstation-setup

# Run the setup script (as Administrator)
.\Setup-Workstation.ps1
```

## Project Structure

```
windows-workstation-setup/
├── bootstrap.ps1                        # Remote bootstrap script
├── Setup-Workstation.ps1                # Main setup script
├── resources/
│   └── Install-ClaudeCode.ps1           # Standalone extension installer
└── README.md
```

## Post-Installation

After the automated setup completes, you'll need to:

1. **Authenticate Claude Code**
   - Open VS Code
   - Click the Claude Code icon in the sidebar
   - Sign in with your Anthropic account

2. **GitHub CLI** (if skipped during setup)
   ```powershell
   gh auth login
   ```

## Troubleshooting

### winget not found
winget should be pre-installed on Windows 10/11. If missing, install "App Installer" from the Microsoft Store.

### VS Code not in PATH
Restart your terminal or open a new PowerShell window after installation.

### Claude Code extension not installing
Run the standalone installer:
```powershell
.\resources\Install-ClaudeCode.ps1
```

Or install manually in VS Code:
1. Open Extensions (Ctrl+Shift+X)
2. Search for "Claude Code"
3. Click Install

### Python command opens Microsoft Store
This should be automatically fixed by the setup script, which reorders your User PATH to prioritize the real Python installation over Windows Store aliases. If the issue persists:

1. Open Windows Settings
2. Search for "Manage app execution aliases"
3. Disable both `python.exe` and `python3.exe`

### Installation fails
Check the output for specific errors. Common issues:
- Insufficient permissions (run as Administrator)
- Network connectivity problems
- winget package source issues

## Customization

To add additional tools, edit `Setup-Workstation.ps1` and add new installation sections following the existing pattern.

Example for adding Node.js:
```powershell
# ============================================================
# STEP X: Install Node.js
# ============================================================
Write-Status "Checking for Node.js..."
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Status "Installing Node.js..."
    winget install --id OpenJS.NodeJS.LTS --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-EnvironmentPath
    Write-Success "Node.js installed successfully."
} else {
    Write-Success "Node.js is already installed."
}
```

> **Note:** Always include `--source winget` in winget commands to avoid certificate errors with the Microsoft Store source.

## License

MIT License - Feel free to use and modify for your needs.
