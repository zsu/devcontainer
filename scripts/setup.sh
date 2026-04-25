#!/bin/bash

# DevPod Ubuntu Setup Script
# Installs necessary tools for DevPod to launch DevContainers
# Skips tools that are already installed

set -e

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DevPod Setup for Ubuntu ===${NC}\n"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get installed version
get_version() {
    "$1" --version 2>/dev/null | head -n 1
}

# ============================================================================
# 1. Update package manager
# ============================================================================
echo -e "${YELLOW}Updating package manager...${NC}"
sudo apt-get update -qq

# ============================================================================
# 2. Install Docker
# ============================================================================
echo -e "\n${YELLOW}Checking Docker...${NC}"
if command_exists docker; then
    echo -e "${GREEN}✓ Docker is already installed${NC}"
    get_version docker
else
    echo -e "${BLUE}Installing Docker...${NC}"
    
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
    
    # Update and install Docker
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
    
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
    sudo apt-get install -y -qq git
    echo -e "${GREEN}✓ Git installed successfully${NC}"
fi

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
    sudo apt-get install -y -qq curl
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
    sudo apt-get install -y -qq openssh-client
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
    
    # Initialize DevPod (creates config directory if needed)
    if [ ! -d "$HOME/.devpod" ]; then
        echo -e "${BLUE}Initializing DevPod configuration...${NC}"
        devpod init --skip-credentials-setup || true
        echo -e "${GREEN}✓ DevPod initialized${NC}"
    else
        echo -e "${GREEN}✓ DevPod configuration already exists${NC}"
    fi
    
    # Add Docker provider (default provider for local development)
    echo -e "${BLUE}Setting up Docker provider...${NC}"
    devpod provider add docker || true
    
    # Configure DevPod for SSH-only access (no browser/GUI)
    echo -e "${BLUE}Configuring DevPod for SSH-only mode...${NC}"
    devpod context set-options -o IDE=ssh 2>/dev/null || true
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
# Summary
# ============================================================================
echo -e "\n${BLUE}=== Setup Complete ===${NC}"
echo -e "${GREEN}✓ All required tools have been installed/verified${NC}"

echo -e "\n${YELLOW}Important notes:${NC}"
echo "1. SSH-only mode configured (IDE=ssh)"
echo "   - No GUI/browser needed"
echo "   - Full terminal access via SSH"
echo "2. Idle timeout DISABLED (EXIT_AFTER_TIMEOUT=false)"
echo "   - DevPod won't auto-stop during SSH sessions"
echo "   - You can keep working without interruption"
echo "3. Docker socket permissions (chmod 666) set"
echo "   - Allows DevPod agent to access Docker"

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

echo -e "\n${YELLOW}Documentation:${NC}"
echo "- DevPod: https://devpod.sh"
echo "- Docker: https://docs.docker.com"
echo "- DevContainers: https://containers.dev"