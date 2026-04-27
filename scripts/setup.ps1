<#
.SYNOPSIS
    Windows client setup script for DevContainer development.

.DESCRIPTION
    Installs VS Code, Rancher Desktop (free Docker-compatible engine, Apache 2.0),
    and the VS Code Dev Containers extension.
    Skips any tool that is already installed.
    Compatible with Windows PowerShell 5.1 and PowerShell 7+.

    Rancher Desktop is used instead of Docker Desktop as it is free for all use
    including government and enterprise, and is a drop-in replacement.

    For macOS, use scripts/setup-mac.sh instead.

.EXAMPLE
    .\scripts\setup.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host "[x] This script is for Windows only. Use scripts/setup-mac.sh on macOS." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== DevContainer Client Setup (Windows) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
function Write-Header { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "  $([char]0x2713) $msg" -ForegroundColor Green }
function Write-Info   { param($msg) Write-Host "  $msg" -ForegroundColor Blue }
function Write-Warn   { param($msg) Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Fail   { param($msg) Write-Host "  [x] $msg" -ForegroundColor Red }

function Test-Command { param($Name) return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Install-Winget {
    param([string]$Id, [string]$Name)
    Write-Info "Installing $Name via winget..."
    winget install --exact --id $Id --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "winget failed for $Name (exit $LASTEXITCODE). Install manually."
        return $false
    }
    Write-Ok "$Name installed"
    return $true
}

# ---------------------------------------------------------------------------
# 1. winget
# ---------------------------------------------------------------------------
Write-Header "Package Manager"

if (-not (Test-Command 'winget')) {
    Write-Fail "winget not found. Install App Installer from the Microsoft Store, then re-run this script."
    exit 1
}
Write-Ok "winget $(winget --version)"

# ---------------------------------------------------------------------------
# 2. Docker Engine (Rancher Desktop)
# ---------------------------------------------------------------------------
Write-Header "Docker Engine"

$dockerFound = $false

if (Test-Command 'docker') {
    $dockerVersion = docker --version

    if (Test-Path "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe") {
        Write-Ok "Docker Desktop already installed: $dockerVersion"
        Write-Warn "Docker Desktop requires a paid license for government/enterprise use."
        Write-Warn "Consider replacing with Rancher Desktop: https://rancherdesktop.io"
    } elseif (Test-Path "$env:ProgramFiles\Rancher Desktop\Rancher Desktop.exe") {
        Write-Ok "Rancher Desktop already installed: $dockerVersion"
    } else {
        Write-Ok "Docker engine already installed: $dockerVersion"
    }
    $dockerFound = $true
}

if (-not $dockerFound) {
    Install-Winget -Id 'SUSE.RancherDesktop' -Name 'Rancher Desktop'
    Write-Warn "Start Rancher Desktop and set container engine to 'dockerd (moby)' in Preferences -> Container Engine."
}

# ---------------------------------------------------------------------------
# 3. VS Code
# ---------------------------------------------------------------------------
Write-Header "Visual Studio Code"

if (Test-Command 'code') {
    Write-Ok "Already installed: VS Code $(code --version | Select-Object -First 1)"
} else {
    Install-Winget -Id 'Microsoft.VisualStudioCode' -Name 'Visual Studio Code'
    # Refresh PATH so 'code' is available in this session
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')
}

# ---------------------------------------------------------------------------
# 4. VS Code extensions
# ---------------------------------------------------------------------------
Write-Header "VS Code Extensions"

$extensions = @{
    'ms-vscode-remote.remote-containers' = 'Dev Containers'
    'ms-vscode-remote.remote-ssh'        = 'Remote - SSH'
}

if (-not (Test-Command 'code')) {
    Write-Warn "'code' not in PATH -- open a new terminal and re-run, or install extensions manually in VS Code."
} else {
    $installed = code --list-extensions 2>$null
    foreach ($id in $extensions.Keys) {
        $name = $extensions[$id]
        if ($installed -contains $id) {
            Write-Ok "Already installed: $name"
        } else {
            Write-Info "Installing $name..."
            code --install-extension $id --force
            if ($LASTEXITCODE -eq 0) { Write-Ok "$name installed" }
            else { Write-Warn "Failed -- install $name manually in VS Code Extensions panel." }
        }
    }
}

# ---------------------------------------------------------------------------
# Git config
# ---------------------------------------------------------------------------
Write-Header "Git Configuration"

if (Test-Command 'git') {
    git config --global submodule.recurse true
    Write-Ok "git submodule.recurse set to true (git pull auto-updates submodules)"
} else {
    Write-Warn "git not found -- install Git for Windows, then run: git config --global submodule.recurse true"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Header "Summary"

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Start Rancher Desktop (uses Docker engine to run containers)"
Write-Host "     If first run: Preferences -> Container Engine -> dockerd (moby)"
Write-Host "  2. Open VS Code and connect to your devcontainer:"
Write-Host "     F1 -> 'Dev Containers: Clone Repository in Container Volume'"
Write-Host ""
Write-Host "Note: Git SSH authentication inside the devcontainer requires" -ForegroundColor Yellow
Write-Host "  the Windows OpenSSH agent running with your key loaded:" -ForegroundColor Yellow
Write-Host "  Start-Service ssh-agent"
Write-Host "  ssh-add $env:USERPROFILE\.ssh\id_ed25519"
Write-Host ""
Write-Host "Docs:" -ForegroundColor Yellow
Write-Host "  - Rancher Desktop: https://rancherdesktop.io"
Write-Host "  - Dev Containers:  https://code.visualstudio.com/docs/devcontainers/containers"
Write-Host ""
