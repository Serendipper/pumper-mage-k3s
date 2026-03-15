#!/bin/bash
# Add grafana.lan → control plane IP in Pi-hole on medivh (or another host).
# Run from repo root when medivh is reachable. Uses config/defaults.env and config/project.env.
#
# Usage: ./scripts/setup-pihole-grafana-dns.sh [host]
#   host  default: medivh (must be in config/nodes or resolve)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$REPO_ROOT/config/project.env" ] && . "$REPO_ROOT/config/project.env"

HOST="${1:-medivh}"
GRAFANA_IP="${K3S_CP_IP:?Set K3S_CP_IP in config}"
USER="${K3S_SSH_USER:-serendipper}"
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
KNOWN_HOSTS="${K3S_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"

# Resolve host to IP from config/nodes
HOST_IP="$HOST"
NODES="$REPO_ROOT/config/nodes"
if [ -f "$NODES" ]; then
  while read -r line; do
    line="${line%%#*}"
    trim="${line%%[![:space:]]*}"
    line="${line#$trim}"
    [ -z "$line" ] && continue
    read -r n addr _ <<< "$line" || true
    if [ "$n" = "$HOST" ]; then
      HOST_IP="${addr%% *}"
      break
    fi
  done < "$NODES"
fi

echo "Target: $USER@$HOST_IP (host=$HOST)"
echo "Grafana DNS: grafana.lan -> $GRAFANA_IP"
echo ""

# Optional: sudo password for non-interactive run (from config/project.env)
SUDO_PW="${K3S_NODE_PASSWORD:-}"
[ -n "$SUDO_PW" ] && SUDO_CMD="echo '$SUDO_PW' | sudo -S" || SUDO_CMD="sudo"

# Run on remote: check Pi-hole, add dnsmasq record, restart
REMOTE_SCRIPT=$(cat << REMOTE
set -e
GRAFANA_IP="$GRAFANA_IP"
SUDO_CMD="$SUDO_CMD"
if ! command -v pihole &>/dev/null && ! systemctl is-active --quiet pihole-FTL 2>/dev/null; then
  echo "Pi-hole not found. Install with: curl -sSL https://install.pi-hole.net | bash"
  echo "Then re-run this script to add grafana.lan."
  exit 1
fi
# Pi-hole v6 does not load /etc/dnsmasq.d/ by default; enable it so our file is used
if pihole-FTL --config 2>/dev/null | grep -q "misc.etc_dnsmasq_d"; then
  \$SUDO_CMD pihole-FTL --config misc.etc_dnsmasq_d true 2>/dev/null || true
fi
CONF="/etc/dnsmasq.d/02-grafana-lan.conf"
echo "address=/grafana.lan/\$GRAFANA_IP" | \$SUDO_CMD tee "\$CONF"
echo "Restarting pihole-FTL..."
\$SUDO_CMD systemctl restart pihole-FTL
echo "Done. grafana.lan -> \$GRAFANA_IP (clients using this Pi-hole as DNS will resolve it)."
REMOTE
)

ssh -i "$KEY" \
  -o "UserKnownHostsFile=$KNOWN_HOSTS" \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  "$USER@$HOST_IP" "bash -s" <<< "$REMOTE_SCRIPT"
