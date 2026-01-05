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

        # Ensure winget is available - install if missing
        Script EnsureWinget {
            GetScript = {
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $winget) }
            }
            TestScript = {
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                return ($null -ne $winget)
            }
            SetScript = {
                Write-Host "Winget not found. Installing winget (App Installer)..."

                # Create temp directory for downloads
                $tempDir = Join-Path $env:TEMP "winget-install"
                if (-not (Test-Path $tempDir)) {
                    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                }

                # Download dependencies and winget
                $downloads = @(
                    @{
                        Name = "VCLibs"
                        Url = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
                        File = "Microsoft.VCLibs.x64.14.00.Desktop.appx"
                    },
                    @{
                        Name = "UI.Xaml"
                        Url = "https://github.com/nicovs/NuGetPackageExplorer/releases/download/6.1.0.2/Microsoft.UI.Xaml.2.8.x64.appx"
                        File = "Microsoft.UI.Xaml.2.8.x64.appx"
                    },
                    @{
                        Name = "Winget"
                        Url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
                        File = "Microsoft.DesktopAppInstaller.msixbundle"
                    }
                )

                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                foreach ($download in $downloads) {
                    $filePath = Join-Path $tempDir $download.File
                    Write-Host "Downloading $($download.Name)..."
                    try {
                        Invoke-WebRequest -Uri $download.Url -OutFile $filePath -UseBasicParsing
                    } catch {
                        Write-Host "Failed to download $($download.Name): $_"
                        throw "Failed to download winget dependencies"
                    }
                }

                # Install VCLibs dependency
                Write-Host "Installing VCLibs..."
                Add-AppxPackage -Path (Join-Path $tempDir "Microsoft.VCLibs.x64.14.00.Desktop.appx") -ErrorAction SilentlyContinue

                # Install UI.Xaml dependency
                Write-Host "Installing UI.Xaml..."
                Add-AppxPackage -Path (Join-Path $tempDir "Microsoft.UI.Xaml.2.8.x64.appx") -ErrorAction SilentlyContinue

                # Install winget
                Write-Host "Installing Winget..."
                Add-AppxPackage -Path (Join-Path $tempDir "Microsoft.DesktopAppInstaller.msixbundle") -ErrorAction Stop

                # Clean up
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

                # Refresh PATH and verify
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                # Add winget to path if not already there
                $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
                if ($env:Path -notlike "*$wingetPath*") {
                    $env:Path = "$env:Path;$wingetPath"
                }

                # Verify installation
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                if (-not $winget) {
                    throw "Winget installation failed. Please install manually from the Microsoft Store (App Installer)."
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
