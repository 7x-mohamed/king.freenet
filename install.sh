#!/bin/bash
set -euo pipefail

# Must be root
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root."
  exit 1
fi

echo "Installing kingfreenet Manager..."

MENU_URL="https://raw.githubusercontent.com/7x-mohamed/king.freenet/main/menu.sh"
SSHD_URL="https://raw.githubusercontent.com/7x-mohamed/king.freenet/main/ssh"

MENU_PATH="/usr/local/bin/menu"
SSHD_DIR="/etc/ssh/sshd_config.d"
SSHD_FILE="$SSHD_DIR/99-kingfreenet.conf"

# Ensure ssh config dir exists
mkdir -p "$SSHD_DIR"

# Download menu
echo "Downloading menu..."
if ! wget -4 -q -O "$MENU_PATH" "$MENU_URL"; then
  echo "ERROR: Failed to download menu"
  exit 1
fi
chmod +x "$MENU_PATH"

# Backup old kingfreenet SSH config if exists
if [[ -f "$SSHD_FILE" ]]; then
  cp "$SSHD_FILE" "$SSHD_FILE.backup.$(date +%F-%H%M%S)"
fi

# Download SSH config safely
echo "Applying kingfreenet SSH configuration..."
if ! wget -4 -q -O "$SSHD_FILE" "$SSHD_URL"; then
  echo "ERROR: Failed to download SSH config"
  exit 1
fi

chown root:root "$SSHD_FILE"
chmod 644 "$SSHD_FILE"

# Validate SSH config
if ! sshd -t 2>/dev/null; then
  echo "ERROR: SSH configuration invalid!"
  echo "Restoring previous config..."
  rm -f "$SSHD_FILE"
  exit 1
fi

echo "SSH configuration validated."

# Restart SSH safely
restart_ssh() {
  for svc in sshd ssh openssh; do
    systemctl restart "$svc" 2>/dev/null && return 0
    service "$svc" restart 2>/dev/null && return 0
  done
  return 1
}

if restart_ssh; then
  echo "SSH service restarted."
else
  echo "WARNING: Could not restart SSH automatically."
  echo "Please restart it manually if needed."
fi

# Run menu setup
if [[ -x "$MENU_PATH" ]]; then
  "$MENU_PATH" --install-setup
else
  echo "ERROR: menu is not executable"
  exit 1
fi

echo "Installation complete!"
echo "Type 'menu' to start."
