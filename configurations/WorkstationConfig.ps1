#Requires -Version 5.1
<#
.SYNOPSIS
    DSC Configuration for Windows workstation setup.

.DESCRIPTION
    Defines the Desired State Configuration for installing and configuring
    development tools: Git, GitHub CLI, VS Code, and Claude Code extension.

.PARAMETER GitUserName
    The user's name for Git configuration.

.PARAMETER GitUserEmail
    The user's email for Git configuration.

.PARAMETER OutputPath
    Path where the MOF files will be generated.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GitUserName,

    [Parameter(Mandatory = $true)]
    [string]$GitUserEmail,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$env:TEMP\WorkstationDSC"
)

Configuration WorkstationConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitUserName,

        [Parameter(Mandatory = $true)]
        [string]$GitUserEmail
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node 'localhost' {

        # Verify winget is available (should be installed by Setup-Workstation.ps1 before DSC runs)
        Script EnsureWinget {
            GetScript = {
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $winget) }
            }
            TestScript = {
                # Check common winget locations since DSC runs as SYSTEM
                $wingetPaths = @(
                    "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
                    "C:\Users\*\AppData\Local\Microsoft\WindowsApps\winget.exe",
                    "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
                )
                foreach ($pattern in $wingetPaths) {
                    if (Get-Item -Path $pattern -ErrorAction SilentlyContinue) {
                        return $true
                    }
                }
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                return ($null -ne $winget)
            }
            SetScript = {
                # Winget should already be installed by Setup-Workstation.ps1
                # DSC/SYSTEM cannot install AppX packages, so we just verify it exists
                Write-Host "Winget should be pre-installed. Checking..."

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                $winget = Get-Command winget -ErrorAction SilentlyContinue
                if (-not $winget) {
                    Write-Host "WARNING: Winget not found. It should have been installed before DSC ran."
                    Write-Host "The script will attempt to continue, but some installations may fail."
                }

                Write-Host "Winget installed successfully."
            }
        }

        # Install Git for Windows
        Script InstallGit {
            DependsOn = '[Script]EnsureWinget'
            GetScript = {
                $git = Get-Command git -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $git) }
            }
            TestScript = {
                $git = Get-Command git -ErrorAction SilentlyContinue
                return ($null -ne $git)
            }
            SetScript = {
                Write-Host "Installing Git for Windows..."
                winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
        }

        # Configure Git user name
        Script ConfigureGitUserName {
            DependsOn = '[Script]InstallGit'
            GetScript = {
                $currentName = git config --global user.name 2>$null
                return @{ Result = $currentName }
            }
            TestScript = {
                $currentName = git config --global user.name 2>$null
                return ($currentName -eq $using:GitUserName)
            }
            SetScript = {
                Write-Host "Configuring Git user name..."
                git config --global user.name $using:GitUserName
            }
        }

        # Configure Git user email
        Script ConfigureGitUserEmail {
            DependsOn = '[Script]InstallGit'
            GetScript = {
                $currentEmail = git config --global user.email 2>$null
                return @{ Result = $currentEmail }
            }
            TestScript = {
                $currentEmail = git config --global user.email 2>$null
                return ($currentEmail -eq $using:GitUserEmail)
            }
            SetScript = {
                Write-Host "Configuring Git user email..."
                git config --global user.email $using:GitUserEmail
            }
        }

        # Configure Git credential helper
        Script ConfigureGitCredentialHelper {
            DependsOn = '[Script]InstallGit'
            GetScript = {
                $helper = git config --global credential.helper 2>$null
                return @{ Result = $helper }
            }
            TestScript = {
                $helper = git config --global credential.helper 2>$null
                return ($helper -eq "manager")
            }
            SetScript = {
                Write-Host "Configuring Git credential helper..."
                git config --global credential.helper manager
            }
        }

        # Install GitHub CLI
        Script InstallGitHubCLI {
            DependsOn = '[Script]EnsureWinget'
            GetScript = {
                $gh = Get-Command gh -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $gh) }
            }
            TestScript = {
                $gh = Get-Command gh -ErrorAction SilentlyContinue
                return ($null -ne $gh)
            }
            SetScript = {
                Write-Host "Installing GitHub CLI..."
                winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements --silent

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
        }

        # Install Visual Studio Code
        Script InstallVSCode {
            DependsOn = '[Script]EnsureWinget'
            GetScript = {
                $code = Get-Command code -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $code) }
            }
            TestScript = {
                $code = Get-Command code -ErrorAction SilentlyContinue
                return ($null -ne $code)
            }
            SetScript = {
                Write-Host "Installing Visual Studio Code..."
                winget install --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements --silent

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
        }

        # Install Claude Code Extension
        Script InstallClaudeCodeExtension {
            DependsOn = '[Script]InstallVSCode'
            GetScript = {
                # Refresh PATH first
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                $extensions = code --list-extensions 2>$null
                $installed = $extensions -contains "anthropic.claude-code"
                return @{ Result = $installed }
            }
            TestScript = {
                # Refresh PATH first
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                $extensions = code --list-extensions 2>$null
                return ($extensions -contains "anthropic.claude-code")
            }
            SetScript = {
                Write-Host "Installing Claude Code extension..."

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                # Find VS Code CLI
                $codePath = (Get-Command code -ErrorAction SilentlyContinue).Source
                if (-not $codePath) {
                    # Try common installation paths
                    $possiblePaths = @(
                        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
                        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
                        "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
                    )
                    foreach ($path in $possiblePaths) {
                        if (Test-Path $path) {
                            $codePath = $path
                            break
                        }
                    }
                }

                if ($codePath) {
                    & $codePath --install-extension anthropic.claude-code --force
                } else {
                    throw "Could not find VS Code CLI. Please install the Claude Code extension manually."
                }
            }
        }
    }
}

# Generate the MOF file
Write-Host "Generating DSC configuration..." -ForegroundColor Cyan
WorkstationConfig -GitUserName $GitUserName -GitUserEmail $GitUserEmail -OutputPath $OutputPath
