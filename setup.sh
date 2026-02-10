#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Ubuntu VM Setup Script (idempotent - safe to run multiple times)
# Installs: Docker, tmux, Claude Code, Python uv, nvm, ssh-keygen, .bashrc
# =============================================================================

export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
export DEBIAN_FRONTEND=noninteractive

# Make these env vars survive sudo
sudo_apt() {
  sudo NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

echo "=========================================="
echo "  Ubuntu VM Setup Script"
echo "=========================================="

# Disable needrestart interactive mode permanently
if [ -f /etc/needrestart/needrestart.conf ]; then
  sudo sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
fi

# --- Update system packages ---
echo "[1/9] Updating system packages..."
sudo_apt update -y
sudo_apt upgrade -y

# --- Install Docker (official method from docs.docker.com/engine/install/ubuntu/) ---
echo "[2/9] Installing Docker..."

if command -v docker &>/dev/null; then
  echo "  -> Docker already installed: $(docker --version)"
else
  # Remove conflicting packages
  sudo_apt remove -y docker.io docker-doc docker-compose docker-compose-v2 \
    podman-docker containerd runc 2>/dev/null || true

  # Install prerequisites
  sudo_apt install -y ca-certificates curl gnupg

  # Add Docker's official GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Add Docker repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine
  sudo_apt update -y
  sudo_apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "  -> Docker installed."
fi

# Add current user to docker group (idempotent)
sudo groupadd docker 2>/dev/null || true
if ! groups "$USER" | grep -q '\bdocker\b'; then
  sudo usermod -aG docker "$USER"
  echo "  -> Added '$USER' to docker group."
else
  echo "  -> '$USER' already in docker group."
fi

# --- Install tmux ---
echo "[3/9] Installing tmux..."
if command -v tmux &>/dev/null; then
  echo "  -> tmux already installed: $(tmux -V)"
else
  sudo_apt install -y tmux
  echo "  -> tmux installed."
fi

# --- Install nvm (for all users) --- (before Claude Code, so npm is available)
echo "[4/9] Installing nvm..."
export NVM_DIR="/usr/local/nvm"

# Remove system Node.js to avoid conflicts with nvm
if dpkg -l nodejs 2>/dev/null | grep -q '^ii'; then
  echo "  -> Removing system Node.js to avoid conflicts with nvm..."
  sudo_apt remove -y nodejs npm 2>/dev/null || true
fi

if [ -s "$NVM_DIR/nvm.sh" ]; then
  echo "  -> nvm already installed at $NVM_DIR."
else
  NVM_LATEST=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  echo "  -> Installing nvm $NVM_LATEST..."
  sudo mkdir -p "$NVM_DIR"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | sudo NVM_DIR="$NVM_DIR" bash
  sudo chmod -R a+rx "$NVM_DIR"
  echo "  -> nvm installed."
fi

# Make nvm available to all users via /etc/profile.d
sudo tee /etc/profile.d/nvm.sh > /dev/null << 'NVMEOF'
export NVM_DIR="/usr/local/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMEOF
sudo chmod +r /etc/profile.d/nvm.sh

# Load nvm and install latest LTS Node.js
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if ! command -v node &>/dev/null; then
  nvm install --lts
  echo "  -> Node.js LTS installed."
else
  echo "  -> Node.js already installed: $(node --version)"
fi

# --- Install Claude Code (via npm, region-safe) ---
echo "[5/9] Installing Claude Code..."
if command -v claude &>/dev/null; then
  echo "  -> Claude Code already installed."
else
  # Try native installer first, fall back to npm
  INSTALL_SCRIPT=$(curl -fsSL https://claude.ai/install.sh 2>/dev/null || echo "")
  if echo "$INSTALL_SCRIPT" | head -1 | grep -q '#!/'; then
    echo "$INSTALL_SCRIPT" | bash
    echo "  -> Claude Code installed (native)."
  else
    echo "  -> Native installer unavailable (region block), using npm..."
    npm install -g @anthropic-ai/claude-code
    echo "  -> Claude Code installed (npm)."
  fi
fi

# --- Install Python uv ---
echo "[6/9] Installing Python uv..."
if command -v uv &>/dev/null; then
  echo "  -> uv already installed: $(uv --version)"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo "  -> uv installed."
fi

# --- Generate SSH key ---
echo "[7/9] Generating SSH key..."
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  echo "  -> SSH key already exists, skipping."
else
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
  echo "  -> SSH key generated at ~/.ssh/id_ed25519"
fi

# --- Configure SSH to prevent session timeouts ---
echo "[8/9] Configuring SSH keepalive..."
SSHD_CONFIG="/etc/ssh/sshd_config"
if ! grep -q "^ClientAliveInterval" "$SSHD_CONFIG" 2>/dev/null; then
  sudo tee -a "$SSHD_CONFIG" > /dev/null << 'SSHEOF'

# Prevent SSH session timeout
ClientAliveInterval 60
ClientAliveCountMax 120
TCPKeepAlive yes
SSHEOF
  sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh 2>/dev/null || true
  echo "  -> SSH keepalive configured (60s interval, 120 max count)."
else
  echo "  -> SSH keepalive already configured."
fi

# --- Install .bashrc from github.com/eakot/setup ---
echo "[9/9] Installing .bashrc from github.com/eakot/setup..."
BASHRC_URL="https://raw.githubusercontent.com/eakot/setup/main/.bashrc"
BASHRC_CONTENT=$(curl -fsSL "$BASHRC_URL" 2>/dev/null || echo "")

if [ -n "$BASHRC_CONTENT" ] && echo "$BASHRC_CONTENT" | head -1 | grep -qv '<!DOCTYPE'; then
  # Backup existing .bashrc (only once per day to avoid piling up)
  BACKUP="$HOME/.bashrc.bak.$(date +%Y%m%d)"
  if [ -f "$HOME/.bashrc" ] && [ ! -f "$BACKUP" ]; then
    cp "$HOME/.bashrc" "$BACKUP"
    echo "  -> Backed up existing .bashrc to $BACKUP"
  fi
  echo "$BASHRC_CONTENT" > "$HOME/.bashrc"
  echo "  -> .bashrc installed from eakot/setup repo."
else
  echo "  -> WARNING: Could not download .bashrc from $BASHRC_URL"
  echo "     The repo may be empty or the file may not exist yet."
  echo "     Keeping existing .bashrc."
fi

# --- Done ---
echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo ""
echo "NOTES:"
echo "  - Log out and back in (or run 'newgrp docker') to use Docker without sudo."
echo "  - Run 'source ~/.bashrc' or open a new shell to load the new .bashrc."
echo "  - Run 'claude' to start Claude Code and authenticate."
echo "  - nvm is available system-wide via /etc/profile.d/nvm.sh"
echo "  - Your SSH public key:"
echo "    $(cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || echo 'N/A')"
echo ""
