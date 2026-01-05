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

                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                # Download VCLibs
                Write-Host "Downloading VCLibs..."
                $vclibsPath = Join-Path $tempDir "Microsoft.VCLibs.x64.14.00.Desktop.appx"
                try {
                    Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vclibsPath -UseBasicParsing
                } catch {
                    Write-Host "Failed to download VCLibs: $_"
                    throw "Failed to download winget dependencies"
                }

                # Download UI.Xaml from NuGet (official source)
                Write-Host "Downloading UI.Xaml from NuGet..."
                $nugetZipPath = Join-Path $tempDir "microsoft.ui.xaml.zip"
                $xamlPath = Join-Path $tempDir "Microsoft.UI.Xaml.2.8.appx"
                try {
                    # Download the NuGet package (save as .zip so Expand-Archive accepts it)
                    Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -OutFile $nugetZipPath -UseBasicParsing

                    # Extract the appx from the nupkg (it's just a zip)
                    $extractPath = Join-Path $tempDir "xaml-extract"
                    Expand-Archive -Path $nugetZipPath -DestinationPath $extractPath -Force

                    # Find and copy the x64 appx
                    $appxFile = Get-ChildItem -Path $extractPath -Recurse -Filter "Microsoft.UI.Xaml.2.8.x64.appx" | Select-Object -First 1
                    if ($appxFile) {
                        Copy-Item -Path $appxFile.FullName -Destination $xamlPath -Force
                    } else {
                        throw "Could not find UI.Xaml appx in NuGet package"
                    }
                } catch {
                    Write-Host "Failed to download/extract UI.Xaml: $_"
                    throw "Failed to download winget dependencies"
                }

                # Download winget
                Write-Host "Downloading Winget..."
                $wingetPath = Join-Path $tempDir "Microsoft.DesktopAppInstaller.msixbundle"
                try {
                    Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $wingetPath -UseBasicParsing
                } catch {
                    Write-Host "Failed to download Winget: $_"
                    throw "Failed to download winget dependencies"
                }

                # Install VCLibs dependency
                Write-Host "Installing VCLibs..."
                Add-AppxPackage -Path $vclibsPath -ErrorAction SilentlyContinue

                # Install UI.Xaml dependency
                Write-Host "Installing UI.Xaml..."
                Add-AppxPackage -Path $xamlPath -ErrorAction SilentlyContinue

                # Install winget
                Write-Host "Installing Winget..."
                Add-AppxPackage -Path $wingetPath -ErrorAction Stop

                # Clean up
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

                # Refresh PATH and verify
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                # Add winget to path if not already there
                $wingetPathDir = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
                if ($env:Path -notlike "*$wingetPathDir*") {
                    $env:Path = "$env:Path;$wingetPathDir"
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
