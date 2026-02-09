#!/usr/bin/env bash
export NEEDRESTART_MODE=a
set -euo pipefail

# =============================================================================
# Ubuntu VM Setup Script
# Installs: Docker, tmux, Claude Code, Python uv, nvm, ssh-keygen, .bashrc
# =============================================================================

echo "=========================================="
echo "  Ubuntu VM Setup Script"
echo "=========================================="

# --- Update system packages ---
echo "[1/8] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# --- Install Docker (official method from docs.docker.com/engine/install/ubuntu/) ---
echo "[2/8] Installing Docker..."

# Remove conflicting packages
sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 \
  podman-docker containerd runc 2>/dev/null || true

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

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
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
echo "  -> Docker installed. Added '$USER' to docker group."

# --- Install tmux ---
echo "[3/8] Installing tmux..."
sudo apt-get install -y tmux
echo "  -> tmux installed."

# --- Install Claude Code (native installer for all users) ---
echo "[4/8] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
echo "  -> Claude Code installed."

# --- Install Python uv (for all users) ---
echo "[5/8] Installing Python uv..."
curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR="/usr/local/bin" sh
# Also install for current user in case system-wide doesn't set up shell integration
if [ ! -f "/usr/local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
echo "  -> uv installed."

# --- Install nvm (for all users) ---
echo "[6/8] Installing nvm..."
export NVM_DIR="/usr/local/nvm"
sudo mkdir -p "$NVM_DIR"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | sudo NVM_DIR="$NVM_DIR" bash

# Make nvm available to all users via /etc/profile.d
sudo tee /etc/profile.d/nvm.sh > /dev/null << 'NVMEOF'
export NVM_DIR="/usr/local/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMEOF
sudo chmod +r /etc/profile.d/nvm.sh
sudo chmod -R a+rx "$NVM_DIR"

# Install latest LTS Node.js
export NVM_DIR="/usr/local/nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts 2>/dev/null || true
echo "  -> nvm installed system-wide at $NVM_DIR."

# --- Generate SSH key ---
echo "[7/8] Generating SSH key..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
  echo "  -> SSH key generated at ~/.ssh/id_ed25519"
else
  echo "  -> SSH key already exists, skipping."
fi

# --- Install .bashrc from github.com/eakot/setup ---
echo "[8/8] Installing .bashrc from github.com/eakot/setup..."
BASHRC_URL="https://raw.githubusercontent.com/eakot/setup/main/.bashrc"
if curl -fsSL "$BASHRC_URL" -o /tmp/.bashrc_eakot 2>/dev/null; then
  # Backup existing .bashrc
  if [ -f "$HOME/.bashrc" ]; then
    cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
    echo "  -> Backed up existing .bashrc"
  fi
  cp /tmp/.bashrc_eakot "$HOME/.bashrc"
  rm -f /tmp/.bashrc_eakot
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
echo "  - Your SSH public key: $(cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || echo 'N/A')"
echo ""
