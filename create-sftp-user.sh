#!/bin/bash
# create-sftp-user.sh
# Creates a jailed SFTP-only user, generates SSH key, and mounts target folder safely.

set -euo pipefail

GROUP_NAME=$1
USERNAME=$2
TARGET_FOLDER=$3   # e.g. /opt/bitnami/wordpress

if [ -z "$GROUP_NAME" ] || [ -z "$USERNAME" ] || [ -z "$TARGET_FOLDER" ]; then
  echo "Usage: $0 <sftp-group> <username> <target-folder>"
  exit 1
fi

# Ensure group exists
if ! getent group "$GROUP_NAME" >/dev/null; then
  echo "Error: group $GROUP_NAME does not exist. Run setup-sftp.sh first."
  exit 1
fi

# Create user if not exists
if ! id "$USERNAME" &>/dev/null; then
  sudo useradd -m -g "$GROUP_NAME" -s /usr/sbin/nologin "$USERNAME"
  echo "✅ User $USERNAME created."
else
  echo "ℹ User $USERNAME already exists."
fi

# Add user to WordPress group if needed
sudo usermod -aG daemon "$USERNAME" || true  # adjust "daemon" if needed

# -------------------------------
# Create jail structure
# -------------------------------
JAIL_DIR="/sftp/$USERNAME"
DATA_DIR="$JAIL_DIR/data"
sudo mkdir -p "$DATA_DIR"
sudo chown root:root "$JAIL_DIR"
sudo chmod 755 "$JAIL_DIR"
sudo chown "$USERNAME:$GROUP_NAME" "$DATA_DIR"
sudo chmod 770 "$DATA_DIR"
echo "✅ Jail and /data folder ready"

# -------------------------------
# SSH key setup outside jail
# -------------------------------
SSH_DIR="/etc/ssh/authorized_keys/$USERNAME"
sudo mkdir -p "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"

KEY_FILE="$SSH_DIR/${USERNAME}_id_ed25519"
if [ ! -f "$KEY_FILE" ]; then
  sudo ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "$USERNAME@sftp"
  sudo cp "$KEY_FILE.pub" "$SSH_DIR/authorized_keys"
  sudo chmod 600 "$SSH_DIR/authorized_keys"
  sudo chown root:root "$SSH_DIR/authorized_keys"
  echo "✅ SSH key generated for $USERNAME"
  echo "➡️ Private key saved at: $KEY_FILE"
  echo "⚠️ Provide this private key to the user for FileZilla login"
else
  echo "ℹ SSH key already exists for $USERNAME"
fi

# -------------------------------
# Bind mount target folder
# -------------------------------
MOUNT_POINT="$DATA_DIR/$(basename "$TARGET_FOLDER")"
sudo mkdir -p "$MOUNT_POINT"

if ! mountpoint -q "$MOUNT_POINT"; then
  sudo mount --bind "$TARGET_FOLDER" "$MOUNT_POINT"
  if ! grep -qs "$MOUNT_POINT" /etc/fstab; then
    echo "$TARGET_FOLDER   $MOUNT_POINT   none   bind   0 0" | sudo tee -a /etc/fstab
  fi
  echo "✅ Mounted $TARGET_FOLDER into $MOUNT_POINT"
else
  echo "ℹ $MOUNT_POINT already mounted"
fi

# -------------------------------
# Summary
# -------------------------------
echo "🎉 User $USERNAME ready for SFTP"
echo "Jail root: $JAIL_DIR"
echo "Writable folder: $DATA_DIR"

