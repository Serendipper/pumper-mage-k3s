#!/bin/bash
# Generate Pi first-boot cloud-init user-data from config (hostname + SSH user + password hash).
# Output: config/generated/pi-firstboot-userdata.yaml (gitignored).
# Run from repo root: ./scripts/render-pi-firstboot-userdata.sh [hostname]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
ENV_FILE="$CONFIG_DIR/project.env"
OUT_DIR="$CONFIG_DIR/generated"
OUT_FILE="$OUT_DIR/pi-firstboot-userdata.yaml"

HOSTNAME="${1:-newrpi}"

cd "$REPO_ROOT"
[ -f "$REPO_ROOT/config/defaults.env" ] && . "$REPO_ROOT/config/defaults.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

if [ -z "${K3S_NODE_PASSWORD}" ]; then
  echo "Set K3S_NODE_PASSWORD in config/project.env (used for first-boot SSH login)." >&2
  exit 1
fi

USER="${K3S_SSH_USER:-serendipper}"
HASH=$(echo -n "$K3S_NODE_PASSWORD" | openssl passwd -6 -stdin)
mkdir -p "$OUT_DIR"
cat > "$OUT_FILE" << EOF
#cloud-config
# K3s homelab first-boot (generated): user $USER, hostname $HOSTNAME

hostname: $HOSTNAME

ssh_pwauth: true

users:
  - name: $USER
    gecos: K3s Homelab
    groups: [adm, sudo]
    lock_passwd: false
    passwd: $HASH
    shell: /bin/bash

package_update: true
package_upgrade: false
EOF

chmod 600 "$OUT_FILE"
echo "Wrote $OUT_FILE (hostname=$HOSTNAME)"
