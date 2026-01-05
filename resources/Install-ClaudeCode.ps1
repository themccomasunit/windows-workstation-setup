#Requires -Version 5.1
<#
.SYNOPSIS
    Standalone helper script to install Claude Code extension.

.DESCRIPTION
    Installs the Claude Code VS Code extension. Can be run independently
    if the DSC configuration fails to install the extension.

.NOTES
    Author: themccomasunit
    Requires: Visual Studio Code must be installed
#>

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

function Find-VSCodeCLI {
    # Try to find code in PATH first
    $codePath = (Get-Command code -ErrorAction SilentlyContinue).Source
    if ($codePath) {
        return $codePath
    }

    # Check common installation locations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

Write-Host ""
Write-Host "Claude Code Extension Installer" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Find VS Code
Write-Status "Looking for VS Code..."
$codePath = Find-VSCodeCLI

if (-not $codePath) {
    Write-Error "Visual Studio Code not found!"
    Write-Host ""
    Write-Host "Please install VS Code first:" -ForegroundColor Yellow
    Write-Host "  winget install Microsoft.VisualStudioCode"
    Write-Host ""
    exit 1
}

Write-Success "Found VS Code at: $codePath"

# Check if extension is already installed
Write-Status "Checking installed extensions..."
$extensions = & $codePath --list-extensions 2>$null

if ($extensions -contains "anthropic.claude-code") {
    Write-Success "Claude Code extension is already installed!"
    exit 0
}

# Install the extension
Write-Status "Installing Claude Code extension..."

try {
    & $codePath --install-extension anthropic.claude-code --force
    Write-Success "Claude Code extension installed successfully!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Open VS Code"
    Write-Host "  2. Click the Claude Code icon in the sidebar"
    Write-Host "  3. Sign in to authenticate"
    Write-Host ""
} catch {
    Write-Error "Failed to install extension: $_"
    Write-Host ""
    Write-Host "You can try installing manually:" -ForegroundColor Yellow
    Write-Host "  1. Open VS Code"
    Write-Host "  2. Go to Extensions (Ctrl+Shift+X)"
    Write-Host "  3. Search for 'Claude Code'"
    Write-Host "  4. Click Install"
    Write-Host ""
    exit 1
}
