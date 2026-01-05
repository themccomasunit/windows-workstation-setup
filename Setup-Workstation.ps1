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

# Prompt for Git configuration
Write-Host "Please provide your Git configuration:" -ForegroundColor Yellow
Write-Host ""

do {
    $GitUserName = Read-Host "Enter your name for Git commits (e.g., John Doe)"
    if ([string]::IsNullOrWhiteSpace($GitUserName)) {
        Write-Warning "Name cannot be empty. Please try again."
    }
} while ([string]::IsNullOrWhiteSpace($GitUserName))

do {
    $GitUserEmail = Read-Host "Enter your email for Git commits (e.g., john@example.com)"
    if ([string]::IsNullOrWhiteSpace($GitUserEmail)) {
        Write-Warning "Email cannot be empty. Please try again."
    }
} while ([string]::IsNullOrWhiteSpace($GitUserEmail))

Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "  Name:  $GitUserName"
Write-Host "  Email: $GitUserEmail"
Write-Host ""

$confirm = Read-Host "Proceed with installation? (Y/n)"
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
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

try {
    Start-DscConfiguration -Path $mofOutputPath -Wait -Verbose -Force
    Write-Success "DSC configuration applied successfully."
} catch {
    Write-Error "Failed to apply DSC configuration: $_"
    exit 1
}

# Refresh PATH after installations
Refresh-EnvironmentPath

# Verify installations
Write-Status "Verifying installations..."

$verificationResults = @()

# Check Git
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $gitVersion = git --version
    $verificationResults += @{ Name = "Git"; Status = "Installed"; Version = $gitVersion }
    Write-Success "Git: $gitVersion"
} else {
    $verificationResults += @{ Name = "Git"; Status = "Not Found"; Version = "N/A" }
    Write-Warning "Git: Not found in PATH"
}

# Check GitHub CLI
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    $ghVersion = gh --version | Select-Object -First 1
    $verificationResults += @{ Name = "GitHub CLI"; Status = "Installed"; Version = $ghVersion }
    Write-Success "GitHub CLI: $ghVersion"
} else {
    $verificationResults += @{ Name = "GitHub CLI"; Status = "Not Found"; Version = "N/A" }
    Write-Warning "GitHub CLI: Not found in PATH"
}

# Check VS Code
$code = Get-Command code -ErrorAction SilentlyContinue
if ($code) {
    $codeVersion = code --version | Select-Object -First 1
    $verificationResults += @{ Name = "VS Code"; Status = "Installed"; Version = $codeVersion }
    Write-Success "VS Code: $codeVersion"
} else {
    $verificationResults += @{ Name = "VS Code"; Status = "Not Found"; Version = "N/A" }
    Write-Warning "VS Code: Not found in PATH"
}

# Check Claude Code Extension
if ($code) {
    $extensions = code --list-extensions 2>$null
    if ($extensions -contains "anthropic.claude-code") {
        $verificationResults += @{ Name = "Claude Code"; Status = "Installed"; Version = "Extension" }
        Write-Success "Claude Code Extension: Installed"
    } else {
        $verificationResults += @{ Name = "Claude Code"; Status = "Not Found"; Version = "N/A" }
        Write-Warning "Claude Code Extension: Not installed"
    }
}

# Check Git config
$configuredName = git config --global user.name 2>$null
$configuredEmail = git config --global user.email 2>$null
Write-Success "Git configured as: $configuredName <$configuredEmail>"

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
