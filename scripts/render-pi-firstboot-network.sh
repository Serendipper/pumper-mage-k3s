#!/bin/bash
# Generate Pi first-boot network config from config/project.env.
# Output: config/generated/pi-firstboot-network.yaml (gitignored).
# Use this file when staging first-boot on medivh (see downloads/README, sanitizing-sandbox).
# Run from repo root: ./scripts/render-pi-firstboot-network.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
ENV_FILE="$CONFIG_DIR/project.env"
OUT_DIR="$CONFIG_DIR/generated"
OUT_FILE="$OUT_DIR/pi-firstboot-network.yaml"

cd "$REPO_ROOT"
[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

if [ -z "${K3S_WIFI_SSID}" ]; then
  echo "Set K3S_WIFI_SSID in config/project.env or config/defaults.env." >&2
  exit 1
fi
if [ -z "${K3S_WIFI_PSK}" ]; then
  echo "Set K3S_WIFI_PSK in config/project.env (required for generated network config)." >&2
  exit 1
fi

# Escape single quotes in PSK for YAML single-quoted scalar
SAFE_PSK=$(echo "$K3S_WIFI_PSK" | sed "s/'/'\\\\''/g")
mkdir -p "$OUT_DIR"
cat > "$OUT_FILE" << EOF
# Raspberry Pi OS first-boot network (generated from config/project.env)
# K3s homelab: ./scripts/render-pi-firstboot-network.sh

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
  wifis:
    wlan0:
      dhcp4: true
      optional: false
      access-points:
        ${K3S_WIFI_SSID}:
          password: '${SAFE_PSK}'
      regulatory-domain: US
EOF

chmod 600 "$OUT_FILE"
echo "Wrote $OUT_FILE"
