#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Main script for Windows workstation setup.

.DESCRIPTION
    Installs and configures development tools using plain PowerShell.
    No DSC dependency - runs entirely as the current user.

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
║   - PowerShell 7 (latest)                                     ║
║   - Git for Windows                                           ║
║   - GitHub CLI (gh)                                           ║
║   - Visual Studio Code                                        ║
║   - Claude Code Extension                                     ║
║   - Python 3.13 (with default options)                        ║
║   - Google Chrome (set as default browser)                    ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

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
Write-Host "Proceeding with installation..." -ForegroundColor Green

# ============================================================
# STEP 1: Ensure winget is installed
# ============================================================
Write-Status "Checking for winget..."
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Status "Installing winget (App Installer)..."

    $tempDir = Join-Path $env:TEMP "winget-install"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Download VCLibs
    Write-Host "  Downloading VCLibs..." -ForegroundColor Gray
    $vclibsPath = Join-Path $tempDir "Microsoft.VCLibs.x64.14.00.Desktop.appx"
    try {
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vclibsPath -UseBasicParsing
    } catch {
        Write-Warning "Failed to download VCLibs: $_"
    }

    # Download UI.Xaml from NuGet
    Write-Host "  Downloading UI.Xaml..." -ForegroundColor Gray
    $nugetZipPath = Join-Path $tempDir "microsoft.ui.xaml.zip"
    $xamlPath = Join-Path $tempDir "Microsoft.UI.Xaml.2.8.appx"
    try {
        Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -OutFile $nugetZipPath -UseBasicParsing
        $extractPath = Join-Path $tempDir "xaml-extract"
        Expand-Archive -Path $nugetZipPath -DestinationPath $extractPath -Force
        $appxFile = Join-Path $extractPath "tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx"
        if (Test-Path $appxFile) {
            Copy-Item -Path $appxFile -Destination $xamlPath -Force
        }
    } catch {
        Write-Warning "Failed to download UI.Xaml: $_"
    }

    # Download winget
    Write-Host "  Downloading Winget (this may take a few minutes)..." -ForegroundColor Gray
    $wingetBundlePath = Join-Path $tempDir "Microsoft.DesktopAppInstaller.msixbundle"
    try {
        Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $wingetBundlePath -UseBasicParsing
    } catch {
        Write-Warning "Failed to download Winget: $_"
    }

    # Install packages
    Write-Host "  Installing VCLibs..." -ForegroundColor Gray
    if (Test-Path $vclibsPath) {
        Add-AppxPackage -Path $vclibsPath -ErrorAction SilentlyContinue
    }

    Write-Host "  Installing UI.Xaml..." -ForegroundColor Gray
    if (Test-Path $xamlPath) {
        Add-AppxPackage -Path $xamlPath -ErrorAction SilentlyContinue
    }

    Write-Host "  Installing Winget..." -ForegroundColor Gray
    if (Test-Path $wingetBundlePath) {
        Add-AppxPackage -Path $wingetBundlePath -ErrorAction SilentlyContinue
    }

    # Clean up
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    # Refresh PATH
    Refresh-EnvironmentPath
    $wingetPathDir = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if ($env:Path -notlike "*$wingetPathDir*") {
        $env:Path = "$env:Path;$wingetPathDir"
    }

    # Verify
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Success "Winget installed successfully."
    } else {
        Write-Error "Winget installation failed. Cannot continue."
        exit 1
    }
} else {
    Write-Success "Winget is already installed."
}

# ============================================================
# STEP 2: Install PowerShell 7 (latest)
# ============================================================
Write-Status "Checking for PowerShell 7..."
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwsh) {
    Write-Status "Installing PowerShell 7..."
    winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-EnvironmentPath

    # Add PowerShell 7 to path manually if needed
    $pwshPath = "$env:ProgramFiles\PowerShell\7"
    if ((Test-Path $pwshPath) -and ($env:Path -notlike "*$pwshPath*")) {
        $env:Path = "$env:Path;$pwshPath"
    }

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        Write-Success "PowerShell 7 installed successfully."
    } else {
        Write-Warning "PowerShell 7 installation may require a terminal restart."
    }
} else {
    Write-Success "PowerShell 7 is already installed."
}

# ============================================================
# STEP 3: Install Git for Windows
# ============================================================
Write-Status "Checking for Git..."
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Status "Installing Git for Windows..."
    winget install --id Git.Git --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-EnvironmentPath

    # Also add Git to path manually if needed
    $gitPath = "C:\Program Files\Git\cmd"
    if ((Test-Path $gitPath) -and ($env:Path -notlike "*$gitPath*")) {
        $env:Path = "$env:Path;$gitPath"
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        Write-Success "Git installed successfully."
    } else {
        Write-Warning "Git installation may require a terminal restart."
    }
} else {
    Write-Success "Git is already installed."
}

# ============================================================
# STEP 4: Configure Git
# ============================================================
Write-Status "Configuring Git..."
Refresh-EnvironmentPath
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    # Configure user name
    $currentName = git config --global user.name 2>$null
    if ($currentName -ne $GitUserName) {
        git config --global user.name $GitUserName
        Write-Success "Git user.name set to: $GitUserName"
    } else {
        Write-Success "Git user.name already configured."
    }

    # Configure user email
    $currentEmail = git config --global user.email 2>$null
    if ($currentEmail -ne $GitUserEmail) {
        git config --global user.email $GitUserEmail
        Write-Success "Git user.email set to: $GitUserEmail"
    } else {
        Write-Success "Git user.email already configured."
    }

    # Configure credential helper
    $helper = git config --global credential.helper 2>$null
    if ($helper -ne "manager") {
        git config --global credential.helper manager
        Write-Success "Git credential.helper set to: manager"
    } else {
        Write-Success "Git credential.helper already configured."
    }
} else {
    Write-Warning "Git not available for configuration. Will configure after terminal restart."
}

# ============================================================
# STEP 5: Install GitHub CLI
# ============================================================
Write-Status "Checking for GitHub CLI..."
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Status "Installing GitHub CLI..."
    winget install --id GitHub.cli --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-EnvironmentPath

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        Write-Success "GitHub CLI installed successfully."
    } else {
        Write-Warning "GitHub CLI installation may require a terminal restart."
    }
} else {
    Write-Success "GitHub CLI is already installed."
}

# ============================================================
# STEP 6: Install Visual Studio Code
# ============================================================
Write-Status "Checking for VS Code..."
$code = Get-Command code -ErrorAction SilentlyContinue
if (-not $code) {
    Write-Status "Installing Visual Studio Code..."
    winget install --id Microsoft.VisualStudioCode --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-EnvironmentPath

    # Also check common VS Code paths
    $vscodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin",
        "$env:ProgramFiles\Microsoft VS Code\bin"
    )
    foreach ($path in $vscodePaths) {
        if ((Test-Path $path) -and ($env:Path -notlike "*$path*")) {
            $env:Path = "$env:Path;$path"
        }
    }

    $code = Get-Command code -ErrorAction SilentlyContinue
    if ($code) {
        Write-Success "VS Code installed successfully."
    } else {
        Write-Warning "VS Code installation may require a terminal restart."
    }
} else {
    Write-Success "VS Code is already installed."
}

# ============================================================
# STEP 7: Install Claude Code Extension
# ============================================================
Write-Status "Checking for Claude Code extension..."
Refresh-EnvironmentPath
$code = Get-Command code -ErrorAction SilentlyContinue

if ($code) {
    $extensions = code --list-extensions 2>$null
    if ($extensions -contains "anthropic.claude-code") {
        Write-Success "Claude Code extension is already installed."
    } else {
        Write-Status "Installing Claude Code extension..."
        code --install-extension anthropic.claude-code --force

        # Verify
        $extensions = code --list-extensions 2>$null
        if ($extensions -contains "anthropic.claude-code") {
            Write-Success "Claude Code extension installed successfully."
        } else {
            Write-Warning "Claude Code extension installation may have failed."
        }
    }
} else {
    Write-Warning "VS Code not available. Claude Code extension will need to be installed manually."
}

# ============================================================
# STEP 8: Install Python 3.13
# ============================================================
Write-Status "Checking for Python 3.13..."

# Check if real Python is installed (not the Windows Store stub)
$pythonInstalled = $false
$pythonPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
    "$env:ProgramFiles\Python313\python.exe",
    "${env:ProgramFiles(x86)}\Python313\python.exe"
)

foreach ($path in $pythonPaths) {
    if (Test-Path $path) {
        $pythonInstalled = $true
        break
    }
}

if (-not $pythonInstalled) {
    Write-Status "Installing Python 3.13..."
    winget install --id Python.Python.3.13 --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-EnvironmentPath

    # Also add Python to path manually if needed
    $pythonPathDirs = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313",
        "$env:LOCALAPPDATA\Programs\Python\Python313\Scripts",
        "$env:ProgramFiles\Python313",
        "$env:ProgramFiles\Python313\Scripts"
    )
    foreach ($path in $pythonPathDirs) {
        if ((Test-Path $path) -and ($env:Path -notlike "*$path*")) {
            $env:Path = "$env:Path;$path"
        }
    }

    # Verify installation by checking the actual executable
    $pythonInstalled = $false
    foreach ($path in $pythonPaths) {
        if (Test-Path $path) {
            $pythonInstalled = $true
            $pythonVersion = & $path --version 2>&1
            Write-Success "Python 3.13 installed successfully: $pythonVersion"
            break
        }
    }

    if (-not $pythonInstalled) {
        Write-Warning "Python 3.13 installation may require a terminal restart."
    }
} else {
    # Find the installed Python and get version
    foreach ($path in $pythonPaths) {
        if (Test-Path $path) {
            $pythonVersion = & $path --version 2>&1
            Write-Success "Python is already installed: $pythonVersion"
            break
        }
    }
}

# ============================================================
# STEP 9: Install Google Chrome and Set as Default Browser
# ============================================================
Write-Status "Checking for Google Chrome..."
$chromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
$chromePathX86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"

if (-not (Test-Path $chromePath) -and -not (Test-Path $chromePathX86)) {
    Write-Status "Installing Google Chrome..."
    winget install --id Google.Chrome --source winget --accept-source-agreements --accept-package-agreements --silent

    # Wait a moment for installation to complete
    Start-Sleep -Seconds 3

    if ((Test-Path $chromePath) -or (Test-Path $chromePathX86)) {
        Write-Success "Google Chrome installed successfully."
    } else {
        Write-Warning "Google Chrome installation may require a system restart."
    }
} else {
    Write-Success "Google Chrome is already installed."
}

# Set Chrome as default browser
Write-Status "Setting Google Chrome as default browser..."
try {
    # Use the SetUserFTA tool approach or registry method
    # This opens the Windows Settings to let user confirm (required on Windows 10/11)
    $progId = "ChromeHTML"

    # Register Chrome protocol associations via registry
    $protocols = @("http", "https")
    foreach ($protocol in $protocols) {
        $regPath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$protocol\UserChoice"
        # Note: Direct registry modification for UserChoice is protected by hash in Windows 10+
        # The most reliable method is to use Start-Process to open default apps settings
    }

    # Open Default Apps settings for user to confirm Chrome as default
    # This is the most reliable cross-version approach
    Start-Process "ms-settings:defaultapps"
    Write-Host ""
    Write-Host "  Windows Default Apps settings has been opened." -ForegroundColor Yellow
    Write-Host "  Please scroll down to 'Web browser' and select Google Chrome." -ForegroundColor Yellow
    Write-Host "  Press Enter once you've set Chrome as the default browser..." -ForegroundColor Yellow
    Read-Host
    Write-Success "Default browser configuration completed."
} catch {
    Write-Warning "Could not automatically set default browser. Please set manually in Windows Settings."
}

# ============================================================
# VERIFICATION
# ============================================================
Write-Status "Verifying installations..."
Refresh-EnvironmentPath

$installFailed = $false

# Check PowerShell 7
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
    $pwshVersion = pwsh --version
    Write-Success "PowerShell 7: $pwshVersion"
} else {
    Write-Warning "PowerShell 7: Not found in PATH (restart terminal)"
    $installFailed = $true
}

# Check Git
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $gitVersion = git --version
    Write-Success "Git: $gitVersion"
} else {
    Write-Warning "Git: Not found in PATH (restart terminal)"
    $installFailed = $true
}

# Check GitHub CLI
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    $ghVersion = gh --version | Select-Object -First 1
    Write-Success "GitHub CLI: $ghVersion"
} else {
    Write-Warning "GitHub CLI: Not found in PATH (restart terminal)"
    $installFailed = $true
}

# Check VS Code
$code = Get-Command code -ErrorAction SilentlyContinue
if ($code) {
    $codeVersion = code --version | Select-Object -First 1
    Write-Success "VS Code: $codeVersion"
} else {
    Write-Warning "VS Code: Not found in PATH (restart terminal)"
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

# Check Python
$pythonFound = $false
$pythonCheckPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
    "$env:ProgramFiles\Python313\python.exe",
    "${env:ProgramFiles(x86)}\Python313\python.exe"
)
foreach ($path in $pythonCheckPaths) {
    if (Test-Path $path) {
        $pythonVersion = & $path --version 2>&1
        Write-Success "Python: $pythonVersion"
        $pythonFound = $true
        break
    }
}
if (-not $pythonFound) {
    Write-Warning "Python: Not found in PATH (restart terminal)"
    $installFailed = $true
}

# Check Google Chrome
$chromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
$chromePathX86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
if ((Test-Path $chromePath) -or (Test-Path $chromePathX86)) {
    Write-Success "Google Chrome: Installed"
} else {
    Write-Warning "Google Chrome: Not installed"
    $installFailed = $true
}

# Check Git config
if ($git) {
    $configuredName = git config --global user.name 2>$null
    $configuredEmail = git config --global user.email 2>$null
    if ($configuredName -and $configuredEmail) {
        Write-Success "Git configured as: $configuredName <$configuredEmail>"
    }
}

if ($installFailed) {
    Write-Host ""
    Write-Warning "Some components may not be visible until you restart your terminal."
    Write-Host ""
}

# ============================================================
# POST-INSTALLATION
# ============================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    POST-INSTALLATION STEPS                     " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# GitHub CLI Authentication
Write-Status "GitHub CLI Authentication"

# Check if already authenticated
$ghAuthStatus = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "GitHub CLI is already authenticated."
} else {
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
}

# Final summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                    SETUP COMPLETE!                             " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor Cyan
Write-Host "  - PowerShell 7 (latest)"
Write-Host "  - Git for Windows (configured with your identity)"
Write-Host "  - GitHub CLI"
Write-Host "  - Visual Studio Code"
Write-Host "  - Claude Code Extension"
Write-Host "  - Python 3.13"
Write-Host "  - Google Chrome (default browser)"
Write-Host ""
Write-Host "Tip: You may need to restart your terminal or open a new one"
Write-Host "     for all PATH changes to take effect."
Write-Host ""

# Open VS Code and launch Claude Code authentication
Write-Status "Opening Visual Studio Code with Claude Code..."
Start-Process code

# Wait for VS Code to fully launch
Start-Sleep -Seconds 5

# Open Claude Code sidebar view and trigger authentication
# The vscode:// URI scheme can open extensions and trigger commands
Write-Status "Launching Claude Code authentication..."
Start-Process "vscode://anthropic.claude-code/login"

Write-Host ""
Write-Host "Thank you for using Windows Workstation Setup!" -ForegroundColor Cyan
Write-Host ""
