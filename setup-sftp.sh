#!/bin/bash
# setup-sftp.sh
# Run once to prepare the system for jailed SFTP-only users.

set -euo pipefail

GROUP_NAME=${1:-}

if [ -z "$GROUP_NAME" ]; then
  echo "Usage: $0 <sftp-group>"
  exit 1
fi

# Ensure group exists
if ! getent group "$GROUP_NAME" >/dev/null; then
  sudo groupadd "$GROUP_NAME"
  echo "✅ Group $GROUP_NAME created."
else
  echo "ℹ Group $GROUP_NAME already exists."
fi

# Create jail base directory
JAIL_BASE="/sftp"
sudo mkdir -p "$JAIL_BASE"
sudo chown root:root "$JAIL_BASE"
sudo chmod 755 "$JAIL_BASE"
echo "✅ Jail base directory $JAIL_BASE ready."

# SSHD configuration
CONF_DIR="/etc/ssh/sshd_config.d"
CONF_FILE="$CONF_DIR/sftp-only.conf"

# Backup existing config if it exists
if [ -f "$CONF_FILE" ]; then
  sudo cp "$CONF_FILE" "${CONF_FILE}.bak.$(date +%F-%T)"
  echo "ℹ Backup of existing SSHD config saved as ${CONF_FILE}.bak"
fi

# Write config idempotently
sudo tee "$CONF_FILE" > /dev/null <<EOF
Subsystem sftp internal-sftp

Match Group $GROUP_NAME
    ChrootDirectory /sftp/%u
    ForceCommand internal-sftp -d /data
    AllowTcpForwarding no
    X11Forwarding no
EOF

echo "✅ SSHD configuration written to $CONF_FILE"

# Test SSHD config before reload
if sudo sshd -t; then
  sudo systemctl restart ssh
  echo "✅ SSHD restarted successfully"
else
  echo "❌ SSHD config test failed! Manual check required."
  exit 1
fi

echo "🎉 SFTP environment ready for group $GROUP_NAME"

