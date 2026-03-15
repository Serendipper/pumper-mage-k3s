#!/bin/bash
# Print SSH config entries for all hosts in config/nodes. Append to ~/.ssh/config.
# Run from repo root: ./scripts/ssh-config-from-nodes.sh
# To append: ./scripts/ssh-config-from-nodes.sh >> ~/.ssh/config

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODES_FILE="$REPO_ROOT/config/nodes"

[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$REPO_ROOT/config/project.env" ] && . "$REPO_ROOT/config/project.env"

USER="${K3S_SSH_USER:-serendipper}"
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"

if [ ! -f "$NODES_FILE" ]; then
  echo "Missing $NODES_FILE" >&2
  exit 1
fi

echo "# K3s Homelab Cluster (from config/nodes)"
while read -r line; do
  line="${line%%#*}"
  trim="${line%%[![:space:]]*}"
  line="${line#$trim}"
  [ -z "$line" ] && continue
  read -r host ip <<< "$line"
  [ -z "$host" ] && continue
  echo "Host $host"
  echo "    HostName $ip"
  echo "    User $USER"
  echo "    IdentityFile $KEY"
  echo ""
done < "$NODES_FILE"
