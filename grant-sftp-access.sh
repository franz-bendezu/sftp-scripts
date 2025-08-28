#!/bin/bash
# grant-sftp-access.sh
# Grants an existing SFTP user full ACL access to a folder.

set -e

USERNAME=$1
FOLDER=$2

if [ -z "$USERNAME" ] || [ -z "$FOLDER" ]; then
  echo "Usage: $0 <username> <folder>"
  exit 1
fi

if ! id "$USERNAME" &>/dev/null; then
  echo "Error: user $USERNAME does not exist."
  exit 1
fi

# Ensure ACL available
if ! command -v setfacl &>/dev/null; then
  echo "Installing ACL package..."
  sudo apt-get update && sudo apt-get install -y acl
fi

# Apply permissions
sudo setfacl -R -m u:$USERNAME:rwx "$FOLDER"
sudo setfacl -d -m u:$USERNAME:rwx "$FOLDER"

echo "✅ Granted $USERNAME full access to $FOLDER"
