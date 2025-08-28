#!/bin/bash
# setup-sftp.sh
# Run once to prepare the system for jailed SFTP-only users.

set -e

GROUP_NAME=$1

if [ -z "$GROUP_NAME" ]; then
  echo "Usage: $0 <sftp-group>"
  exit 1
fi

# Ensure group exists
if ! getent group "$GROUP_NAME" >/dev/null; then
  sudo groupadd "$GROUP_NAME"
  echo "Group $GROUP_NAME created."
else
  echo "Group $GROUP_NAME already exists."
fi

# Create jail base directory
sudo mkdir -p /sftp
sudo chmod 755 /sftp
sudo chown root:root /sftp

# Configure SSHD
CONF_FILE="/etc/ssh/sshd_config.d/sftp-only.conf"
if [ ! -f "$CONF_FILE" ]; then
  cat <<EOF | sudo tee "$CONF_FILE"
Subsystem sftp internal-sftp

Match Group $GROUP_NAME
    ChrootDirectory /sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
  echo "Created $CONF_FILE"
else
  echo "$CONF_FILE already exists, skipping."
fi

# Reload SSHD safely
sudo sshd -t && sudo systemctl restart ssh

echo "✅ SFTP environment ready for group $GROUP_NAME"
