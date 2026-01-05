#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap script for Windows workstation setup.

.DESCRIPTION
    Downloads and executes the workstation configuration from GitHub.
    Run this with: irm https://raw.githubusercontent.com/themccomasunit/windows-workstation-setup/main/bootstrap.ps1 | iex

.NOTES
    Author: themccomasunit
    Requires: Windows 10/11 with PowerShell 5.1+
#>

$ErrorActionPreference = 'Stop'

# Configuration
$RepoOwner = "themccomasunit"
$RepoName = "windows-workstation-setup"
$Branch = "main"
$TempPath = Join-Path $env:TEMP "workstation-setup"

function Write-Status {
    param([string]$Message)
    Write-Host "`n[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Self-elevate if not running as admin
if (-not (Test-Administrator)) {
    Write-Status "Requesting administrator privileges..."

    # Create a temporary script file to run elevated
    $elevatedScript = @"
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/bootstrap.ps1 | iex
"@

    $tempScriptPath = Join-Path $env:TEMP "bootstrap-elevated.ps1"
    $elevatedScript | Out-File -FilePath $tempScriptPath -Encoding UTF8

    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$tempScriptPath`"" -Verb RunAs
    exit
}

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║         Windows Workstation Setup - Bootstrap                 ║
║                   themccomasunit                              ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Status "Starting bootstrap process..."

# Clean up any previous download
if (Test-Path $TempPath) {
    Write-Status "Cleaning up previous installation files..."
    Remove-Item -Path $TempPath -Recurse -Force
}

# Download the repository
Write-Status "Downloading setup files from GitHub..."
$zipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
$zipPath = Join-Path $env:TEMP "workstation-setup.zip"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Write-Success "Download complete."
} catch {
    Write-Error "Failed to download repository: $_"
    exit 1
}

# Extract the archive
Write-Status "Extracting files..."
try {
    Expand-Archive -Path $zipPath -DestinationPath $TempPath -Force
    Write-Success "Extraction complete."
} catch {
    Write-Error "Failed to extract archive: $_"
    exit 1
}

# Find the extracted folder (GitHub adds branch name to folder)
$extractedFolder = Get-ChildItem -Path $TempPath -Directory | Select-Object -First 1

if (-not $extractedFolder) {
    Write-Error "Could not find extracted files."
    exit 1
}

# Run the main setup script
$setupScript = Join-Path $extractedFolder.FullName "Setup-Workstation.ps1"

if (Test-Path $setupScript) {
    Write-Status "Launching main setup script..."
    & $setupScript
} else {
    Write-Error "Setup script not found at: $setupScript"
    exit 1
}

# Cleanup
Write-Status "Cleaning up temporary files..."
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Success "Bootstrap complete!"
