#!/bin/bash
# SSH to a cluster node with explicit key and known_hosts.
# Use this when running from the Cursor agent so context (user/HOME) doesn't matter.
#
# Usage: ssh-node.sh <hostname> <command>
# Example: ./scripts/ssh-node.sh dalaran 'hostname'
#          ./scripts/ssh-node.sh <hostname> 'echo "$K3S_NODE_PASSWORD" | sudo -S nmap -sn $K3S_SCAN_SUBNET'
#
# Node list: config/nodes (hostname IP, one per line). Agent maintains it when nodes change.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODES_FILE="$REPO_ROOT/config/nodes"

[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$REPO_ROOT/config/project.env" ] && . "$REPO_ROOT/config/project.env"

set -e
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
KNOWN_HOSTS="${K3S_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
USER="${K3S_SSH_USER:-serendipper}"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <hostname> <command>" >&2
  if [ -f "$NODES_FILE" ]; then
    echo "Hosts (from config/nodes):" >&2
    grep -v '^#' "$NODES_FILE" | grep -v '^[[:space:]]*$' | awk '{print "  " $1}' | tr '\n' ' ' >&2
    echo "" >&2
  fi
  exit 1
fi

HOST="$1"
shift
CMD="$*"

if [ ! -f "$NODES_FILE" ]; then
  echo "Missing $NODES_FILE. Create it with lines: hostname IP" >&2
  exit 1
fi

IP=""
while read -r line; do
  line="${line%%#*}"
  trim="${line%%[![:space:]]*}"
  line="${line#$trim}"
  [ -z "$line" ] && continue
  read -r n addr <<< "$line"
  if [ "$n" = "$HOST" ]; then
    IP="${addr%% *}"
    break
  fi
done < "$NODES_FILE"

if [ -z "$IP" ]; then
  echo "Unknown host: $HOST. Add it to config/nodes (hostname IP)." >&2
  exit 1
fi

exec ssh -i "$KEY" \
  -o "UserKnownHostsFile=$KNOWN_HOSTS" \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  "$USER@$IP" "$CMD"
