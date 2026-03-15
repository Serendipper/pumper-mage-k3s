#!/bin/bash
# Deploy project SSH public key to all hosts in config/nodes. Uses config/project.env for password and key.
# Run from repo root: ./scripts/deploy-keys-to-nodes.sh
# Requires: sshpass, config/nodes, config/project.env with K3S_NODE_PASSWORD and K3S_SSH_KEY set.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODES_FILE="$REPO_ROOT/config/nodes"

[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$REPO_ROOT/config/project.env" ] && . "$REPO_ROOT/config/project.env"

KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
USER="${K3S_SSH_USER:-serendipper}"
PASS="${K3S_NODE_PASSWORD:-}"

if [ -z "$PASS" ]; then
  echo "Set K3S_NODE_PASSWORD in config/project.env." >&2
  exit 1
fi

if [ ! -f "$NODES_FILE" ]; then
  echo "Missing $NODES_FILE" >&2
  exit 1
fi

PUBKEY=$(cat "${KEY}.pub")

while read -r line; do
  line="${line%%#*}"
  trim="${line%%[![:space:]]*}"
  line="${line#$trim}"
  [ -z "$line" ] && continue
  read -r name ip <<< "$line"
  [ -z "$name" ] && continue
  echo "--- $name ---"
  sshpass -p "$PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$USER@$ip" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>&1 || echo "FAILED (unreachable)"
done < "$NODES_FILE"
