#!/bin/bash
# create-sftp-user.sh
# Creates a jailed SFTP-only user, generates SSH key, and mounts target folder.

set -e

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
if id "$USERNAME" &>/dev/null; then
  echo "User $USERNAME already exists!"
else
  sudo useradd -m -g "$GROUP_NAME" -s /usr/sbin/nologin "$USERNAME"
  echo "User $USERNAME created."
fi

# Create jail structure
JAIL_DIR="/sftp/$USERNAME"
sudo mkdir -p "$JAIL_DIR"
sudo chown root:root "$JAIL_DIR"
sudo chmod 755 "$JAIL_DIR"

# SSH key setup
SSH_DIR="$JAIL_DIR/.ssh"
if [ ! -d "$SSH_DIR" ]; then
  sudo mkdir -p "$SSH_DIR"
  sudo chmod 700 "$SSH_DIR"
  sudo chown $USERNAME:$GROUP_NAME "$SSH_DIR"
fi

# Generate SSH key pair for user
KEY_FILE="$SSH_DIR/${USERNAME}_id_ed25519"
if [ ! -f "$KEY_FILE" ]; then
  sudo -u $USERNAME ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "$USERNAME@sftp"
  cat "$KEY_FILE.pub" | sudo tee "$SSH_DIR/authorized_keys" >/dev/null
  sudo chmod 600 "$SSH_DIR/authorized_keys"
  sudo chown $USERNAME:$GROUP_NAME "$SSH_DIR/authorized_keys"
  echo "SSH key generated for $USERNAME."
  echo "➡️  Private key saved at: $KEY_FILE"
  echo "⚠️  Provide this private key to the user for FileZilla login."
else
  echo "SSH key already exists for $USERNAME."
fi

# Bind mount target folder inside jail
MOUNT_POINT="$JAIL_DIR/$(basename $TARGET_FOLDER)"
sudo mkdir -p "$MOUNT_POINT"
if ! mountpoint -q "$MOUNT_POINT"; then
  sudo mount --bind "$TARGET_FOLDER" "$MOUNT_POINT"
  echo "$TARGET_FOLDER   $MOUNT_POINT   none   bind   0 0" | sudo tee -a /etc/fstab
  echo "Mounted $TARGET_FOLDER into $MOUNT_POINT"
else
  echo "$MOUNT_POINT already mounted."
fi

echo "✅ User $USERNAME ready. Jail: $JAIL_DIR  Target: $TARGET_FOLDER"
