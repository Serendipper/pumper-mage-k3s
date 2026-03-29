#!/bin/bash
# Phase 3: Join a Pi (or Debian arm64 SBC) to the cluster after OS prep and reboot.
# Run from repo root. Requires sshpass, config, and SSH to the control plane for the token.
# Join step can take 5–10 minutes on Pi over Wi‑Fi (downloads ~68 MB). No internal timeout;
# if you run this under a wrapper (e.g. CI), allow at least 600 seconds for this script.
# See scripts/runbook-worker-pi.md for full procedure.
#
# Usage: ./scripts/pi-worker-join.sh <NODE_HOSTNAME> <NODE_IP>
# Example: ./scripts/pi-worker-join.sh medivh 192.168.1.50

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$REPO_ROOT/config/project.env" ] && . "$REPO_ROOT/config/project.env"
. "$SCRIPT_DIR/lib/spinner.sh"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <NODE_HOSTNAME> <NODE_IP>" >&2
  echo "Example: $0 medivh 192.168.1.50" >&2
  exit 1
fi

NODE_HOSTNAME="$1"
NODE_IP="$2"

if [ -z "$K3S_NODE_PASSWORD" ] || [ -z "$K3S_SSH_USER" ] || [ -z "$K3S_CP_HOST" ] || [ -z "$K3S_CP_IP" ]; then
  echo "Set K3S_NODE_PASSWORD, K3S_SSH_USER, K3S_CP_HOST, K3S_CP_IP in config (defaults.env / project.env)" >&2
  exit 1
fi

echo "=== 3.1 Verify cgroups ==="
sshpass -p "$K3S_NODE_PASSWORD" ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@$NODE_IP" "cat /proc/cmdline | grep cgroup" || { echo "SSH failed; is the Pi back from reboot?" >&2; exit 1; }

echo "=== 3.2 Get join token and join (may take 5–10 min on Pi over Wi‑Fi) ==="
# Token: read from control plane (node-token is root-only, so use sudo on CP)
K3S_TOKEN=$(sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=no "$K3S_SSH_USER@$K3S_CP_HOST" "echo $K3S_NODE_PASSWORD | sudo -S cat $K3S_NODE_TOKEN_PATH")

K3S_URL="https://${K3S_CP_IP}:${K3S_API_PORT}"
# Use curl -4 for Pi; no timeout in script — join runs to completion. Prefer key-based SSH if os-prep deployed the key.
do_join() {
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$K3S_SSH_USER@$NODE_IP" "true" 2>/dev/null; then
    ssh -o StrictHostKeyChecking=no "$K3S_SSH_USER@$NODE_IP" \
      "echo $K3S_NODE_PASSWORD | sudo -S env K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -c 'curl -sfL -4 $K3S_INSTALL_URL | sh -'"
  else
    sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=no "$K3S_SSH_USER@$NODE_IP" \
      "echo $K3S_NODE_PASSWORD | sudo -S env K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -c 'curl -sfL -4 $K3S_INSTALL_URL | sh -'"
  fi
}
export -f do_join
export K3S_NODE_PASSWORD K3S_SSH_USER K3S_CP_HOST K3S_CP_IP K3S_INSTALL_URL K3S_URL K3S_TOKEN NODE_IP
run_with_spinner "K3s join" -- do_join

echo "=== 3.3 Label node ==="
if command -v kubectl &>/dev/null && [ -n "${KUBECONFIG}" ]; then
  kubectl label node "$NODE_HOSTNAME" node-role.kubernetes.io/worker=worker --overwrite
else
  ./scripts/ssh-node.sh "$K3S_CP_HOST" "echo $K3S_NODE_PASSWORD | sudo -S k3s kubectl label node $NODE_HOSTNAME node-role.kubernetes.io/worker=worker --overwrite"
fi

echo "=== 3.4 config/nodes and SSH config ==="
# Use INTERNAL-IP from API if available; else use NODE_IP we were given
INTERNAL_IP="$NODE_IP"
if command -v kubectl &>/dev/null && [ -n "${KUBECONFIG}" ]; then
  INTERNAL_IP=$(kubectl get node "$NODE_HOSTNAME" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null) || true
fi
[ -z "$INTERNAL_IP" ] && INTERNAL_IP="$NODE_IP"

NODES_FILE="$REPO_ROOT/config/nodes"
if [ -f "$NODES_FILE" ]; then
  if grep -q "^${NODE_HOSTNAME}[[:space:]]" "$NODES_FILE"; then
    sed -i "s/^${NODE_HOSTNAME}[[:space:]].*/${NODE_HOSTNAME} ${INTERNAL_IP}/" "$NODES_FILE"
  else
    echo "${NODE_HOSTNAME} ${INTERNAL_IP}" >> "$NODES_FILE"
  fi
  echo "Updated $NODES_FILE with $NODE_HOSTNAME $INTERNAL_IP"
fi

echo "Run ./scripts/ssh-config-from-nodes.sh and merge the block into ~/.ssh/config."
echo "Create or update nodes/${NODE_HOSTNAME}-<model>.md and nodes/roadmap.md (see runbook §3.4)."
