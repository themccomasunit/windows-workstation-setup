#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Main orchestration script for Windows workstation setup.

.DESCRIPTION
    Prompts for user configuration, compiles DSC, applies configuration,
    and runs post-installation tasks.

.NOTES
    Author: themccomasunit
    Requires: Windows 10/11 with PowerShell 5.1+, Administrator privileges
#>

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string]$Message)
    Write-Host "`n[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

function Refresh-EnvironmentPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Banner
Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║            Windows Workstation Setup                          ║
║                                                               ║
║   This script will install and configure:                     ║
║   - Git for Windows                                           ║
║   - GitHub CLI (gh)                                           ║
║   - Visual Studio Code                                        ║
║   - Claude Code Extension                                     ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ============================================================
# CONFIGURATION - Edit these values for your environment
# ============================================================
$GitUserName = "themccomasunit"
$GitUserEmail = "themccomasunit@gmail.com"
# ============================================================

Write-Host "Git Configuration:" -ForegroundColor Yellow
Write-Host "  Name:  $GitUserName"
Write-Host "  Email: $GitUserEmail"
Write-Host ""

$confirm = Read-Host "Proceed with installation? (Y/n)"
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
}

# Ensure WinRM is configured (required for DSC)
Write-Status "Configuring WinRM for DSC..."
try {
    # Enable WinRM service
    $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
    if ($winrmService.Status -ne 'Running') {
        Set-Service -Name WinRM -StartupType Automatic
        Start-Service -Name WinRM
    }

    # Quick configure WinRM for local use
    winrm quickconfig -quiet 2>$null

    # Ensure LocalAccountTokenFilterPolicy is set for local admin
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $regName = "LocalAccountTokenFilterPolicy"
    $currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($currentValue.$regName -ne 1) {
        Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Type DWord -Force
    }

    Write-Success "WinRM configured successfully."
} catch {
    Write-Warning "Could not fully configure WinRM: $_"
    Write-Host "Attempting to continue anyway..." -ForegroundColor Yellow
}

# Run DSC Configuration
Write-Status "Compiling DSC configuration..."

$configScript = Join-Path $ScriptDir "configurations\WorkstationConfig.ps1"
$mofOutputPath = Join-Path $env:TEMP "WorkstationDSC"

if (-not (Test-Path $configScript)) {
    Write-Error "Configuration script not found: $configScript"
    exit 1
}

try {
    & $configScript -GitUserName $GitUserName -GitUserEmail $GitUserEmail -OutputPath $mofOutputPath
    Write-Success "DSC configuration compiled."
} catch {
    Write-Error "Failed to compile DSC configuration: $_"
    exit 1
}

# Apply DSC Configuration
Write-Status "Applying DSC configuration (this may take several minutes)..."

$dscError = $null
try {
    $dscJob = Start-DscConfiguration -Path $mofOutputPath -Wait -Verbose -Force -ErrorVariable dscError 2>&1

    # Check if there were any errors in the DSC run
    if ($dscError) {
        Write-Warning "DSC configuration encountered errors:"
        $dscError | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
} catch {
    Write-Error "Failed to apply DSC configuration: $_"
    exit 1
}

# Refresh PATH after installations
Refresh-EnvironmentPath

# Verify installations
Write-Status "Verifying installations..."

$installFailed = $false

# Check Git
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $gitVersion = git --version
    Write-Success "Git: $gitVersion"
} else {
    Write-Warning "Git: Not found in PATH"
    $installFailed = $true
}

# Check GitHub CLI
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    $ghVersion = gh --version | Select-Object -First 1
    Write-Success "GitHub CLI: $ghVersion"
} else {
    Write-Warning "GitHub CLI: Not found in PATH"
    $installFailed = $true
}

# Check VS Code
$code = Get-Command code -ErrorAction SilentlyContinue
if ($code) {
    $codeVersion = code --version | Select-Object -First 1
    Write-Success "VS Code: $codeVersion"
} else {
    Write-Warning "VS Code: Not found in PATH"
    $installFailed = $true
}

# Check Claude Code Extension
if ($code) {
    $extensions = code --list-extensions 2>$null
    if ($extensions -contains "anthropic.claude-code") {
        Write-Success "Claude Code Extension: Installed"
    } else {
        Write-Warning "Claude Code Extension: Not installed"
        $installFailed = $true
    }
}

# If installations failed, offer to retry or exit
if ($installFailed) {
    Write-Host ""
    Write-Warning "Some components were not installed successfully."
    Write-Host "This may be due to WinRM/DSC issues or network problems." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You can try:" -ForegroundColor Cyan
    Write-Host "  1. Run this script again"
    Write-Host "  2. Install components manually using winget:"
    Write-Host "     winget install Git.Git"
    Write-Host "     winget install GitHub.cli"
    Write-Host "     winget install Microsoft.VisualStudioCode"
    Write-Host ""

    $continueChoice = Read-Host "Continue with post-installation steps anyway? (y/N)"
    if ($continueChoice -ne 'y' -and $continueChoice -ne 'Y') {
        Write-Host "Setup incomplete. Please resolve issues and run again." -ForegroundColor Yellow
        exit 1
    }
}

# Check Git config (only if git is available)
if ($git) {
    $configuredName = git config --global user.name 2>$null
    $configuredEmail = git config --global user.email 2>$null
    if ($configuredName -and $configuredEmail) {
        Write-Success "Git configured as: $configuredName <$configuredEmail>"
    }
}

# Post-installation tasks
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    POST-INSTALLATION STEPS                     " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# GitHub CLI Authentication
Write-Status "GitHub CLI Authentication"
Write-Host "You need to authenticate with GitHub to use the CLI and push/pull repos."
Write-Host ""

$authChoice = Read-Host "Would you like to authenticate with GitHub now? (Y/n)"
if ($authChoice -ne 'n' -and $authChoice -ne 'N') {
    Write-Host ""
    Write-Host "A browser window will open for authentication." -ForegroundColor Yellow
    Write-Host "Follow the prompts to complete GitHub authentication." -ForegroundColor Yellow
    Write-Host ""

    try {
        gh auth login --web --git-protocol https
        Write-Success "GitHub authentication complete!"
    } catch {
        Write-Warning "GitHub authentication was not completed. You can run 'gh auth login' later."
    }
} else {
    Write-Host ""
    Write-Host "You can authenticate later by running: gh auth login" -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                    SETUP COMPLETE!                             " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor Cyan
Write-Host "  - Git for Windows (configured with your identity)"
Write-Host "  - GitHub CLI"
Write-Host "  - Visual Studio Code"
Write-Host "  - Claude Code Extension"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Open Visual Studio Code"
Write-Host "  2. Click on the Claude Code icon in the sidebar"
Write-Host "  3. Sign in to authenticate Claude Code"
Write-Host ""
Write-Host "Tip: You may need to restart your terminal or open a new one"
Write-Host "     for all PATH changes to take effect."
Write-Host ""

# Open VS Code
$openVSCode = Read-Host "Would you like to open VS Code now? (Y/n)"
if ($openVSCode -ne 'n' -and $openVSCode -ne 'N') {
    Write-Status "Opening Visual Studio Code..."
    Start-Process code
}

Write-Host ""
Write-Host "Thank you for using Windows Workstation Setup!" -ForegroundColor Cyan
Write-Host ""
