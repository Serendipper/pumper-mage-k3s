#!/bin/bash
# Phase 2: OS prep for a Pi (or Debian arm64 SBC) before joining the cluster.
# Run from repo root. Requires sshpass and config (defaults.env, project.env).
# See scripts/runbook-worker-pi.md for full procedure.
#
# Usage: ./scripts/pi-worker-os-prep.sh <NODE_HOSTNAME> <NODE_IP>
# Example: ./scripts/pi-worker-os-prep.sh medivh 192.168.1.50

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

if [ -z "$K3S_NODE_PASSWORD" ] || [ -z "$K3S_SSH_USER" ]; then
  echo "Set K3S_NODE_PASSWORD and K3S_SSH_USER in config/project.env" >&2
  exit 1
fi

if ! command -v sshpass &>/dev/null; then
  echo "Install sshpass (e.g. dnf install sshpass or apt install sshpass)" >&2
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
SUDO_CMD="echo \"$K3S_NODE_PASSWORD\" | sudo -S"

echo "=== 2.1 SSH test ==="
sshpass -p "$K3S_NODE_PASSWORD" ssh $SSH_OPTS "$K3S_SSH_USER@$NODE_IP" "hostname; uname -m"

echo "=== 2.2 Non-free repos and update ==="
run_with_spinner "Non-free repos and apt upgrade" -- sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "$SUDO_CMD bash -c 'sed -i \"s/main non-free-firmware/main contrib non-free non-free-firmware/g\" /etc/apt/sources.list && apt update && apt upgrade -y'"

echo "=== 2.3 Cgroups (cmdline.txt) ==="
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "$SUDO_CMD bash -c '
  for f in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
    [ -f \"\$f\" ] && ! grep -q cgroup_enable \"\$f\" && sed -i \"s/\$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/\" \"\$f\"
  done
'"

echo "=== 2.4 iptables-legacy and curl ==="
run_with_spinner "iptables-legacy and curl" -- sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "$SUDO_CMD bash -c 'apt install -y iptables curl && update-alternatives --set iptables /usr/sbin/iptables-legacy && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy'"

echo "=== 2.5 Deploy SSH key ==="
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
if [ -f "$KEY.pub" ]; then
  sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=no "$K3S_SSH_USER@$NODE_IP" \
    "mkdir -p ~/.ssh; chmod 700 ~/.ssh; echo '$(cat "$KEY.pub")' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
  echo "Key deployed."
else
  echo "Warning: $KEY.pub not found; skipping key deploy. Join script will use password." >&2
fi

echo "=== 2.6 Reboot ==="
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "$SUDO_CMD reboot" || true

echo "Done. Wait 1–2 minutes for reboot, then run pi-worker-join.sh with the same NODE_HOSTNAME and NODE_IP (re-scan if DHCP changed the IP)."
