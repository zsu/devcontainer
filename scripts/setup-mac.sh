#!/bin/bash
# macOS client setup script for DevContainer development.
#
# Installs VS Code, Rancher Desktop (free Docker-compatible engine, Apache 2.0),
# and the VS Code Dev Containers extension.
# Skips any tool that is already installed.
#
# Rancher Desktop is used instead of Docker Desktop as it is free for all use
# including government and enterprise, and is a drop-in replacement.
#
# For Windows, use scripts/setup.ps1 instead.
# For Linux hosts, use scripts/setup.sh instead.
#
# Usage:
#   bash scripts/setup-mac.sh

set -e

if [[ "$(uname)" != "Darwin" ]]; then
    echo "[x] This script is for macOS only."
    echo "    For Windows: scripts/setup.ps1"
    echo "    For Linux:   scripts/setup.sh"
    exit 1
fi

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓ $*${NC}"; }
info() { echo -e "  ${BLUE}$*${NC}"; }
warn() { echo -e "  ${YELLOW}[!] $*${NC}"; }
fail() { echo -e "  ${RED}[x] $*${NC}"; exit 1; }
header() { echo -e "\n${BLUE}=== $* ===${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

echo -e "${BLUE}=== DevContainer Client Setup (macOS) ===${NC}"

# ---------------------------------------------------------------------------
# 1. Homebrew
# ---------------------------------------------------------------------------
header "Package Manager"

if ! command_exists brew; then
    warn "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for this session (Apple Silicon vs Intel)
    if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

ok "$(brew --version | head -1)"

# ---------------------------------------------------------------------------
# 2. Docker Engine (Rancher Desktop)
# ---------------------------------------------------------------------------
header "Docker Engine"

dockerFound=false

if command_exists docker; then
    dockerVersion=$(docker --version)

    if [[ -d "/Applications/Docker.app" ]]; then
        ok "Docker Desktop already installed: $dockerVersion"
        warn "Docker Desktop requires a paid license for government/enterprise use."
        warn "Consider replacing with Rancher Desktop: https://rancherdesktop.io"
    elif [[ -d "/Applications/Rancher Desktop.app" ]]; then
        ok "Rancher Desktop already installed: $dockerVersion"
    else
        ok "Docker engine already installed: $dockerVersion"
    fi
    dockerFound=true
fi

if [[ "$dockerFound" == false ]]; then
    info "Installing Rancher Desktop via Homebrew..."
    brew install --cask rancher
    warn "Start Rancher Desktop and set container engine to 'dockerd (moby)' in Preferences -> Container Engine."
fi

# ---------------------------------------------------------------------------
# 3. VS Code
# ---------------------------------------------------------------------------
header "Visual Studio Code"

if command_exists code; then
    ok "Already installed: VS Code $(code --version | head -1)"
else
    info "Installing Visual Studio Code via Homebrew..."
    brew install --cask visual-studio-code
    # Add code to PATH for this session
    export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# ---------------------------------------------------------------------------
# 4. VS Code extensions
# ---------------------------------------------------------------------------
header "VS Code Extensions"

declare -A EXTENSIONS=(
    ["ms-vscode-remote.remote-containers"]="Dev Containers"
    ["ms-vscode-remote.remote-ssh"]="Remote - SSH"
)

if ! command_exists code; then
    warn "'code' not in PATH — open a new terminal and re-run, or install extensions manually in VS Code."
else
    installed=$(code --list-extensions 2>/dev/null)
    for id in "${!EXTENSIONS[@]}"; do
        name="${EXTENSIONS[$id]}"
        if echo "$installed" | grep -q "^${id}$"; then
            ok "Already installed: $name"
        else
            info "Installing $name..."
            if code --install-extension "$id" --force; then
                ok "$name installed"
            else
                warn "Failed — install $name manually in VS Code Extensions panel."
            fi
        fi
    done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
header "Summary"

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Start Rancher Desktop -> Preferences -> Container Engine -> dockerd (moby)"
echo "  2. Open VS Code and connect to your devcontainer:"
echo "     F1 -> 'Dev Containers: Clone Repository in Container Volume'"
echo ""
echo -e "${YELLOW}Note: Git SSH authentication inside the devcontainer${NC}"
echo "  macOS SSH agent runs automatically. Load your key once:"
echo "    ssh-add ~/.ssh/id_ed25519"
echo "  The macOS keychain will keep it loaded across reboots."
echo ""
echo -e "${YELLOW}Docs:${NC}"
echo "  - Rancher Desktop: https://rancherdesktop.io"
echo "  - Dev Containers:  https://code.visualstudio.com/docs/devcontainers/containers"
echo ""
