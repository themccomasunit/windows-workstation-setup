# Windows Workstation Setup

Automated PowerShell DSC configuration for ephemeral Windows sandbox environments. Installs and configures development tools with a single command.

## What Gets Installed

- **Git for Windows** - Version control with your identity pre-configured
- **GitHub CLI (gh)** - Command-line interface for GitHub
- **Visual Studio Code** - Code editor
- **Claude Code Extension** - AI coding assistant for VS Code

## Quick Start

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/themccomasunit/windows-workstation-setup/master/bootstrap.ps1 | iex
```

The script will:
1. Download the setup files
2. Prompt for your Git name and email
3. Install all components using PowerShell DSC
4. Guide you through GitHub CLI authentication
5. Optionally open VS Code when complete

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges
- Internet connection
- winget (pre-installed on Windows 10/11)

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
├── Setup-Workstation.ps1                # Main setup orchestrator
├── configurations/
│   └── WorkstationConfig.ps1            # DSC configuration
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

### DSC configuration fails
Check the verbose output for specific errors. Common issues:
- Insufficient permissions (run as Administrator)
- Network connectivity problems
- winget package source issues

## Customization

To add additional tools, edit `configurations/WorkstationConfig.ps1` and add new `Script` resources following the existing pattern.

Example for adding Node.js:
```powershell
Script InstallNodeJS {
    DependsOn = '[Script]EnsureWinget'
    GetScript = {
        $node = Get-Command node -ErrorAction SilentlyContinue
        return @{ Result = ($null -ne $node) }
    }
    TestScript = {
        $node = Get-Command node -ErrorAction SilentlyContinue
        return ($null -ne $node)
    }
    SetScript = {
        winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}
```

## License

MIT License - Feel free to use and modify for your needs.
