#!/bin/bash

# DevPod Setup Script
# Installs necessary tools for DevPod to launch DevContainers
# Supports Ubuntu/Debian and RHEL/CentOS/Rocky/Alma/Fedora
# Skips tools that are already installed

set -e

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get installed version
get_version() {
    "$1" --version 2>/dev/null | head -n 1
}

# ============================================================================
# Detect distro and set package manager variables
# ============================================================================
# shellcheck source=/dev/null
source /etc/os-release
case "$ID" in
    ubuntu|debian)          DISTRO_FAMILY="debian" ;;
    rhel|centos|rocky|alma) DISTRO_FAMILY="rhel" ;;
    fedora)                 DISTRO_FAMILY="fedora" ;;
    *)
        echo -e "${RED}Unsupported distro: $ID — only Ubuntu/Debian and RHEL/CentOS/Rocky/Alma/Fedora are supported.${NC}"
        exit 1
        ;;
esac

if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    PKG_UPDATE="sudo apt-get update -qq"
    PKG_INSTALL="sudo apt-get install -y -qq"
    PKG_SSH="openssh-client"
else
    command_exists dnf && PKG_MGR="dnf" || PKG_MGR="yum"
    PKG_UPDATE="sudo $PKG_MGR makecache -q"
    PKG_INSTALL="sudo $PKG_MGR install -y -q"
    PKG_SSH="openssh-clients"
fi

echo -e "${BLUE}=== DevPod Setup (${PRETTY_NAME}) ===${NC}\n"

# ============================================================================
# 1. Update package manager
# ============================================================================
echo -e "${YELLOW}Updating package manager...${NC}"
$PKG_UPDATE

# ============================================================================
# 2. Install Docker
# ============================================================================
echo -e "\n${YELLOW}Checking Docker...${NC}"
if command_exists docker; then
    echo -e "${GREEN}✓ Docker is already installed${NC}"
    get_version docker
else
    echo -e "${BLUE}Installing Docker...${NC}"

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # Install Docker prerequisites
        sudo apt-get install -y -qq \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        # Set up Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
            https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
    else
        # RHEL/CentOS/Rocky/Alma use centos repo; Fedora uses its own
        case "$ID" in
            fedora) DOCKER_REPO_DISTRO="fedora" ;;
            *)      DOCKER_REPO_DISTRO="centos" ;;
        esac

        $PKG_INSTALL dnf-plugins-core
        sudo $PKG_MGR config-manager --add-repo \
            "https://download.docker.com/linux/${DOCKER_REPO_DISTRO}/docker-ce.repo"
        $PKG_INSTALL docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
    fi

    echo -e "${GREEN}✓ Docker installed successfully${NC}"
fi

# ============================================================================
# 3. Install Git
# ============================================================================
echo -e "\n${YELLOW}Checking Git...${NC}"
if command_exists git; then
    echo -e "${GREEN}✓ Git is already installed${NC}"
    get_version git
else
    echo -e "${BLUE}Installing Git...${NC}"
    $PKG_INSTALL git
    echo -e "${GREEN}✓ Git installed successfully${NC}"
fi

# Configure git to auto-update submodules on pull (needed for devcontainer submodule)
git config --global submodule.recurse true
echo -e "${GREEN}✓ git submodule.recurse set to true${NC}"

# ============================================================================
# 4. Install DevPod
# ============================================================================
echo -e "\n${YELLOW}Checking DevPod...${NC}"
if command_exists devpod; then
    echo -e "${GREEN}✓ DevPod is already installed${NC}"
    get_version devpod
else
    echo -e "${BLUE}Installing DevPod...${NC}"
    
    # Determine CPU architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DEVPOD_ARCH="amd64"
            ;;
        aarch64)
            DEVPOD_ARCH="arm64"
            ;;
        *)
            echo -e "${RED}✗ Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    # Get latest DevPod release
    DEVPOD_VERSION=$(curl -s https://api.github.com/repos/loft-sh/devpod/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    DEVPOD_URL="https://github.com/loft-sh/devpod/releases/download/${DEVPOD_VERSION}/devpod-linux-${DEVPOD_ARCH}"
    
    # Download and install
    sudo curl -fsSL -o /usr/local/bin/devpod "$DEVPOD_URL"
    sudo chmod +x /usr/local/bin/devpod
    
    echo -e "${GREEN}✓ DevPod installed successfully${NC}"
    get_version devpod
fi

# ============================================================================
# 5. Install Docker Compose (if not bundled with Docker)
# ============================================================================
echo -e "\n${YELLOW}Checking Docker Compose...${NC}"
if command_exists docker-compose; then
    echo -e "${GREEN}✓ Docker Compose is already installed${NC}"
    get_version docker-compose
else
    echo -e "${BLUE}Installing Docker Compose...${NC}"
    
    # Check if docker compose (v2) plugin is available
    if docker compose version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker Compose (v2 plugin) is available${NC}"
    else
        # Install standalone docker-compose
        ARCH=$(uname -m)
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
        COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${ARCH}"
        
        sudo curl -fsSL -o /usr/local/bin/docker-compose "$COMPOSE_URL"
        sudo chmod +x /usr/local/bin/docker-compose
        
        echo -e "${GREEN}✓ Docker Compose installed successfully${NC}"
        get_version docker-compose
    fi
fi

# ============================================================================
# 6. Install curl (if not already present)
# ============================================================================
echo -e "\n${YELLOW}Checking curl...${NC}"
if command_exists curl; then
    echo -e "${GREEN}✓ curl is already installed${NC}"
    get_version curl
else
    echo -e "${BLUE}Installing curl...${NC}"
    $PKG_INSTALL curl
    echo -e "${GREEN}✓ curl installed successfully${NC}"
fi

# ============================================================================
# 7. Install SSH (if not already present)
# ============================================================================
echo -e "\n${YELLOW}Checking SSH...${NC}"
if command_exists ssh; then
    echo -e "${GREEN}✓ SSH is already installed${NC}"
    ssh -V
else
    echo -e "${BLUE}Installing SSH...${NC}"
    $PKG_INSTALL $PKG_SSH
    echo -e "${GREEN}✓ SSH installed successfully${NC}"
fi

# ============================================================================
# 8. Verify DevPod installation and initialize
# ============================================================================
echo -e "\n${YELLOW}Verifying and initializing DevPod...${NC}"

# Ensure PATH is updated
export PATH="/usr/local/bin:$PATH"

if command_exists devpod; then
    echo -e "${GREEN}✓ DevPod found in PATH${NC}"
    
    # Add Docker provider (default provider for local development)
    echo -e "${BLUE}Setting up Docker provider...${NC}"
    if devpod provider list 2>/dev/null | grep -qi 'docker'; then
        echo -e "${GREEN}✓ Docker provider already registered${NC}"
    else
        devpod provider add docker
    fi
    
    # Configure DevPod for SSH-only access (no browser/GUI)
    echo -e "${BLUE}Configuring DevPod for SSH-only mode...${NC}"
    devpod context set-options -o IDE=none 2>/dev/null || true
    echo -e "${GREEN}✓ SSH-only mode configured (no GUI required)${NC}"
    
    # CRITICAL: Disable idle timeout for SSH-only mode
    echo -e "${BLUE}Disabling idle timeout (keeps DevPod running)...${NC}"
    devpod context set-options -o EXIT_AFTER_TIMEOUT=false 2>/dev/null || true
    echo -e "${GREEN}✓ Idle timeout disabled${NC}"
    echo -e "${YELLOW}   DevPod will not auto-stop during SSH sessions${NC}"
    
    # List available providers
    echo -e "\n${BLUE}Available providers:${NC}"
    devpod provider list || echo -e "${YELLOW}(Providers may be shown after Docker is running)${NC}"
else
    echo -e "${RED}✗ DevPod not found in PATH${NC}"
    echo -e "${YELLOW}Try running: export PATH=/usr/local/bin:\$PATH${NC}"
fi

# ============================================================================
# 9. Verify Docker daemon and enable on boot
# ============================================================================
echo -e "\n${YELLOW}Checking Docker daemon...${NC}"

# Enable Docker on boot (idempotent)
sudo systemctl enable docker >/dev/null 2>&1 || true

# Check if Docker is running
if sudo systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker daemon is running${NC}"
else
    echo -e "${YELLOW}⚠ Docker daemon is not running${NC}"
    echo -e "${BLUE}Starting Docker daemon...${NC}"
    sudo systemctl start docker
    
    # Wait for Docker to be ready
    for i in {1..10}; do
        if sudo systemctl is-active --quiet docker && [ -S /var/run/docker.sock ]; then
            echo -e "${GREEN}✓ Docker daemon started successfully${NC}"
            sleep 1
            break
        fi
        echo -e "${YELLOW}Waiting for Docker to be ready... ($i/10)${NC}"
        sleep 1
    done
    
    if ! sudo systemctl is-active --quiet docker; then
        echo -e "${RED}✗ Failed to start Docker daemon${NC}"
        echo -e "${YELLOW}Try: sudo systemctl start docker${NC}"
    elif [ ! -S /var/run/docker.sock ]; then
        echo -e "${RED}✗ Docker socket not available${NC}"
        echo -e "${YELLOW}Try: sudo systemctl restart docker${NC}"
    fi
fi

# Verify Docker socket exists
if [ -S /var/run/docker.sock ]; then
    echo -e "${GREEN}✓ Docker socket is available${NC}"
else
    echo -e "${RED}✗ Docker socket not found at /var/run/docker.sock${NC}"
fi

# ============================================================================
# 10. Activate Docker group for current user
# ============================================================================
echo -e "\n${YELLOW}Configuring Docker group access...${NC}"

# Check if user already has docker group access
if id -nG "$USER" | grep -qw docker; then
    echo -e "${GREEN}✓ User already has docker group access${NC}"
else
    echo -e "${BLUE}Adding user to docker group...${NC}"
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    echo -e "${GREEN}✓ Docker group applied${NC}"
fi

# ============================================================================
# 11. Configure Docker socket permissions (CRITICAL FOR DEVPOD)
# ============================================================================
echo -e "\n${YELLOW}Configuring Docker socket permissions...${NC}"

sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

# Verify the permission change
if [ -S /var/run/docker.sock ]; then
    SOCKET_PERMS=$(stat -c %a /var/run/docker.sock 2>/dev/null || stat -f %OLp /var/run/docker.sock 2>/dev/null || echo "unknown")
    
    if [ "$SOCKET_PERMS" = "666" ] || [ "$SOCKET_PERMS" = "666" ]; then
        echo -e "${GREEN}✓ Docker socket permissions configured: $SOCKET_PERMS${NC}"
        echo -e "${GREEN}✓ DevPod agent will be able to access Docker${NC}"
    else
        echo -e "${YELLOW}⚠ Docker socket permissions: $SOCKET_PERMS${NC}"
        echo -e "${YELLOW}   (May be reset on Docker restart - re-run this script if needed)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Docker socket not yet available (will be created when Docker starts)${NC}"
    echo -e "${YELLOW}   Permissions will be set automatically on next Docker restart${NC}"
fi

echo -e "\n${YELLOW}Note: chmod 666 persists until Docker restarts.${NC}"
echo -e "${YELLOW}If DevPod fails after Docker restart, run setup.sh again or:${NC}"
echo -e "${BLUE}sudo chmod 666 /var/run/docker.sock${NC}"

# ============================================================================
# 12. Setup SSH agent (auto-starts on boot, forwarded into devcontainers)
# ============================================================================
echo -e "\n${YELLOW}Setting up SSH agent...${NC}"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SSH_AGENT_SOCKET=""
SSH_AGENT_SOURCE=""

# Helper: persist SSH_AUTH_SOCK to ~/.bashrc and apply to current session
persist_ssh_auth_sock() {
    local sock="$1"
    local marker="$2"
    export SSH_AUTH_SOCK="$sock"
    export DEVPOD_SSH_AUTH_SOCK="$sock"
    if ! grep -q "$marker" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "${BLUE}Adding SSH_AUTH_SOCK to ~/.bashrc...${NC}"
        printf '\n# SSH agent socket for DevPod git authentication\nexport SSH_AUTH_SOCK="%s"\nexport DEVPOD_SSH_AUTH_SOCK="$SSH_AUTH_SOCK"\n' "$sock" >> "$HOME/.bashrc"
        echo -e "${GREEN}✓ SSH_AUTH_SOCK added to ~/.bashrc${NC}"
    else
        echo -e "${GREEN}✓ SSH_AUTH_SOCK already configured in ~/.bashrc${NC}"
    fi
}

# Enable linger so user services survive logout and start on boot
sudo loginctl enable-linger "$USER" 2>/dev/null || true

# --- Strategy 1: already-running agent in current session ---
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    echo -e "${GREEN}✓ SSH agent already running: ${SSH_AUTH_SOCK}${NC}"
    SSH_AGENT_SOCKET="$SSH_AUTH_SOCK"
    SSH_AGENT_SOURCE="existing"
    persist_ssh_auth_sock "$SSH_AGENT_SOCKET" "$SSH_AGENT_SOCKET"

# --- Strategy 2: use system-provided ssh-agent.service if available ---
elif [ -f "/usr/lib/systemd/user/ssh-agent.service" ]; then
    echo -e "${BLUE}Found system ssh-agent.service — starting it...${NC}"
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user start ssh-agent 2>/dev/null || true
    SYSTEM_SOCK="${RUNTIME_DIR}/ssh-agent.socket"
    if [ -S "$SYSTEM_SOCK" ]; then
        echo -e "${GREEN}✓ System ssh-agent started: ${SYSTEM_SOCK}${NC}"
        SSH_AGENT_SOCKET="$SYSTEM_SOCK"
        SSH_AGENT_SOURCE="system"
        persist_ssh_auth_sock "$SSH_AGENT_SOCKET" "ssh-agent.socket"
    else
        echo -e "${YELLOW}  System ssh-agent.service did not produce a socket — falling back${NC}"
    fi
fi

# --- Strategy 3: install and start custom devpod-ssh-agent service ---
if [ -z "$SSH_AGENT_SOCKET" ]; then
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/devpod-ssh-agent.service"
    CUSTOM_SOCK="${RUNTIME_DIR}/devpod-ssh-agent.socket"

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${BLUE}Installing devpod-ssh-agent systemd user service...${NC}"
        mkdir -p "$SERVICE_DIR"
        cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=SSH key agent for DevPod

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/devpod-ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a %t/devpod-ssh-agent.socket

[Install]
WantedBy=default.target
EOF
        echo -e "${GREEN}✓ devpod-ssh-agent service file created${NC}"
    else
        echo -e "${GREEN}✓ devpod-ssh-agent service file already exists${NC}"
    fi

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable devpod-ssh-agent 2>/dev/null || true
    systemctl --user start devpod-ssh-agent 2>/dev/null || true

    # Wait briefly then verify
    sleep 1
    if [ -S "$CUSTOM_SOCK" ]; then
        echo -e "${GREEN}✓ devpod-ssh-agent started: ${CUSTOM_SOCK}${NC}"
        SSH_AGENT_SOCKET="$CUSTOM_SOCK"
        SSH_AGENT_SOURCE="custom"
        persist_ssh_auth_sock "$SSH_AGENT_SOCKET" "devpod-ssh-agent.socket"
    else
        echo -e "${YELLOW}  systemd user service unavailable — trying fixed socket fallback${NC}"
    fi
fi

# --- Strategy 4: fixed socket path (SSM / no-systemd fallback) ---
if [ -z "$SSH_AGENT_SOCKET" ]; then
    FIXED_SOCK="$HOME/.ssh/agent.sock"
    echo -e "${BLUE}Starting SSH agent with fixed socket (SSM-compatible)...${NC}"

    rm -f "$FIXED_SOCK"
    ssh-agent -a "$FIXED_SOCK" > /dev/null 2>&1

    if [ -S "$FIXED_SOCK" ]; then
        SSH_AGENT_SOCKET="$FIXED_SOCK"
        SSH_AGENT_SOURCE="fixed-socket"
        export SSH_AUTH_SOCK="$FIXED_SOCK"
        export DEVPOD_SSH_AUTH_SOCK="$FIXED_SOCK"
        echo -e "${GREEN}✓ SSH agent started: ${FIXED_SOCK}${NC}"

        # Load key now — user types passphrase once
        if [ -f "$HOME/.ssh/id_ed25519" ]; then
            echo -e "${BLUE}Loading SSH key (enter passphrase when prompted)...${NC}"
            ssh-add "$HOME/.ssh/id_ed25519" && \
                echo -e "${GREEN}✓ SSH key loaded${NC}" || \
                echo -e "${YELLOW}⚠ Key not loaded — run: ssh-add ~/.ssh/id_ed25519${NC}"
        fi

        # Write smart bashrc entry — restarts agent if dead on next SSM session
        MARKER="devpod-ssh-agent-fixed"
        if ! grep -q "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
            cat >> "$HOME/.bashrc" << 'BASHRC_EOF'

# SSH agent with persistent fixed socket (SSM-compatible) devpod-ssh-agent-fixed
_SSH_SOCK="$HOME/.ssh/agent.sock"
export SSH_AUTH_SOCK="$_SSH_SOCK"
export DEVPOD_SSH_AUTH_SOCK="$_SSH_SOCK"
ssh-add -l >/dev/null 2>&1; _SSH_RC=$?
if [ $_SSH_RC -eq 2 ]; then
    rm -f "$_SSH_SOCK"
    ssh-agent -a "$_SSH_SOCK" >/dev/null 2>&1
    echo "SSH agent restarted. Run: ssh-add ~/.ssh/id_ed25519"
fi
unset _SSH_SOCK _SSH_RC
BASHRC_EOF
            echo -e "${GREEN}✓ Smart SSH agent entry added to ~/.bashrc${NC}"
        fi
    else
        echo -e "${RED}✗ Could not start SSH agent${NC}"
        echo -e "${YELLOW}  Try manually: ssh-agent -a ~/.ssh/agent.sock && ssh-add ~/.ssh/id_ed25519${NC}"
    fi
fi

# Final status
if [ -n "$SSH_AGENT_SOCKET" ] && [ -S "$SSH_AGENT_SOCKET" ]; then
    if ssh-add -l >/dev/null 2>&1; then
        KEY_COUNT=$(ssh-add -l 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ SSH agent ready (${SSH_AGENT_SOURCE}), ${KEY_COUNT} key(s) loaded${NC}"
    else
        echo -e "${GREEN}✓ SSH agent ready (${SSH_AGENT_SOURCE})${NC}"
        echo -e "${YELLOW}⚠ No keys loaded yet. Add your key:${NC}"
        echo -e "${BLUE}  ssh-add ~/.ssh/id_ed25519${NC}"
    fi
fi

# ============================================================================
# Summary
# ============================================================================
echo -e "\n${BLUE}=== Setup Complete ===${NC}"
echo -e "${GREEN}✓ All required tools have been installed/verified${NC}"

echo -e "\n${YELLOW}Important notes:${NC}"
echo "1. SSH-only mode configured (IDE=none)"
echo "   - No GUI/browser needed"
echo "   - Full terminal access via SSH"
echo "2. Idle timeout DISABLED (EXIT_AFTER_TIMEOUT=false)"
echo "   - DevPod won't auto-stop during SSH sessions"
echo "   - You can keep working without interruption"
echo "3. Docker socket permissions (chmod 666) set"
echo "   - Allows DevPod agent to access Docker"
echo "4. SSH agent configured as systemd user service"
echo "   - Starts automatically on boot (no login required)"
echo "   - Add your key once: ssh-add ~/.ssh/id_ed25519"
echo "   - Keys are forwarded into all devcontainers"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Verify DevPod providers: ${BLUE}devpod provider list${NC}"
echo "2. Create a workspace (SSH-only): ${BLUE}devpod up <repo-url>[@branch]${NC}"
echo "3. Example: ${BLUE}devpod up https://github.com/FordGroup/FordGroup.git@devcontainer${NC}"
echo "4. SSH into container: ${BLUE}ssh <workspace-name>.devpod${NC}"
echo ""
echo -e "${YELLOW}SSH-Only Mode (No GUI):${NC}"
echo "- Configured for headless/remote server usage"
echo "- Access container via: ${BLUE}ssh <workspace-name>.devpod${NC}"
echo "- Full terminal access inside the container"
echo "- No browser/VSCode GUI needed"
echo "- Use your preferred terminal editor (vim, nano, etc.)"

echo -e "\n${YELLOW}Troubleshooting:${NC}"

if ! command -v devpod >/dev/null 2>&1; then
    echo "- If devpod command not found, refresh PATH:"
    echo "  ${BLUE}export PATH=/usr/local/bin:\$PATH${NC}"
    echo "  Or restart your terminal"
fi

if ! sudo systemctl is-active --quiet docker; then
    echo "- If Docker isn't running:"
    echo "  ${BLUE}sudo systemctl start docker${NC}"
    echo "  ${BLUE}sudo systemctl enable docker${NC}"
fi

if [ ! -S /var/run/docker.sock ]; then
    echo "- If Docker socket is missing:"
    echo "  ${BLUE}sudo systemctl restart docker${NC}"
    echo "  ${BLUE}ls -la /var/run/docker.sock${NC} (verify socket exists)"
fi

if ! id -nG "$USER" | grep -qw docker; then
    echo "- If docker permission denied:"
    echo "  ${BLUE}newgrp docker${NC}"
    echo "  (or log out and back in)"
fi

echo -e "\n${YELLOW}Quick verification:${NC}"
echo "- Docker daemon: ${BLUE}sudo systemctl status docker${NC}"
echo "- Docker socket: ${BLUE}ls -la /var/run/docker.sock${NC}"
echo "- Docker access: ${BLUE}docker ps${NC}"
echo "- DevPod status: ${BLUE}devpod version${NC}"
echo "- DevPod providers: ${BLUE}devpod provider list${NC}"
echo "- SSH agent: ${BLUE}systemctl --user status ssh-agent${NC} or ${BLUE}devpod-ssh-agent${NC}"
echo "- Loaded keys: ${BLUE}ssh-add -l${NC}"

echo -e "\n${YELLOW}Documentation:${NC}"
echo "- DevPod: https://devpod.sh"
echo "- Docker: https://docs.docker.com"
echo "- DevContainers: https://containers.dev"

if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "${SSH_AUTH_SOCK}" ]; then
    echo -e "\n${YELLOW}Note: SSH_AUTH_SOCK is not active in this shell.${NC}"
    echo -e "${YELLOW}To avoid this, run setup with source so exports apply to your current session:${NC}"
    echo -e "${BLUE}  source scripts/setup.sh${NC}"
    echo -e "${YELLOW}Or apply it now:${NC}"
    echo -e "${BLUE}  source ~/.bashrc${NC}"
fi