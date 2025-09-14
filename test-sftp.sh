#!/bin/bash
# interactive-sftp-test.sh
# Prompts for SFTP user, validates setup, and tests login

set -e

# -------------------------------
# Prompt for input
# -------------------------------
read -p "Enter SFTP group name: " GROUP_NAME
read -p "Enter SFTP username: " USERNAME
read -p "Enter target folder inside jail (e.g., /opt/wordpress): " TARGET_FOLDER

# Validate input
if [[ -z "$GROUP_NAME" || -z "$USERNAME" || -z "$TARGET_FOLDER" ]]; then
  echo "❌ All fields are required. Exiting."
  exit 1
fi

# Paths
JAIL_DIR="/sftp/$USERNAME"
DATA_DIR="$JAIL_DIR/data"
PRIVATE_KEY="/etc/ssh/authorized_keys/$USERNAME/${USERNAME}_id_ed25519"

# -------------------------------
# Check if group exists
# -------------------------------
if ! getent group "$GROUP_NAME" >/dev/null; then
  echo "❌ Group $GROUP_NAME does not exist. Run setup-sftp.sh first."
  exit 1
fi

# -------------------------------
# Check if user exists
# -------------------------------
if ! id "$USERNAME" &>/dev/null; then
  echo "❌ User $USERNAME does not exist. Run create-sftp-user.sh first."
  exit 1
fi

# -------------------------------
# Check jail and data folder
# -------------------------------
echo "🔹 Checking jail and data folder..."
if [[ ! -d "$JAIL_DIR" || ! -d "$DATA_DIR" ]]; then
  echo "❌ Jail or data folder does not exist."
  exit 1
fi
ls -ld "$JAIL_DIR" "$DATA_DIR"

# -------------------------------
# Check .ssh and authorized_keys
# -------------------------------
if [[ ! -f "$JAIL_DIR/.ssh/authorized_keys" ]]; then
  echo "⚠️ authorized_keys not found in jail. Copying from /etc/ssh/authorized_keys..."
  sudo mkdir -p "$JAIL_DIR/.ssh"
  sudo cp "/etc/ssh/authorized_keys/$USERNAME/${USERNAME}_id_ed25519.pub" "$JAIL_DIR/.ssh/authorized_keys"
  sudo chown -R $USERNAME:$GROUP_NAME "$JAIL_DIR/.ssh"
  sudo chmod 700 "$JAIL_DIR/.ssh"
  sudo chmod 600 "$JAIL_DIR/.ssh/authorized_keys"
fi

# -------------------------------
# Test SFTP login
# -------------------------------
echo "🔹 Testing SFTP login..."
if sftp -i "$PRIVATE_KEY" -o IdentitiesOnly=yes "$USERNAME"@localhost <<EOF
pwd
ls
bye
EOF
then
    echo "✅ SFTP login successful"
else
    echo "❌ SFTP login failed - check keys, permissions, and SSHD config"
fi

# -------------------------------
# Test SSH login (should fail)
# -------------------------------
echo "🔹 Testing SSH shell login (should be refused)..."
if ssh -i "$PRIVATE_KEY" -o IdentitiesOnly=yes "$USERNAME"@localhost exit; then
    echo "⚠️ SSH shell login succeeded (unexpected for SFTP-only user)"
else
    echo "✅ SSH shell login refused (expected for SFTP-only user)"
fi
