#!/usr/bin/env bash
# Create deploy/kustomize/live/private/*.yaml from committed examples (gitignored dir).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRIV="$ROOT/deploy/kustomize/live/private"
mkdir -p "$PRIV"
if [ ! -f "$PRIV/media-pvs.yaml" ]; then
  cp "$ROOT/deploy/kustomize/base/storage/media-pvs.example.yaml" "$PRIV/media-pvs.yaml"
  echo "Created $PRIV/media-pvs.yaml — set NFS server and Plex hostPath."
fi
if [ ! -f "$PRIV/site.yaml" ]; then
  cp "$ROOT/deploy/kustomize/live/site.example.yaml" "$PRIV/site.yaml"
  echo "Created $PRIV/site.yaml — set OpenClaw, TrueNAS, and Plex probe IPs."
fi
echo "Done. Use ./scripts/apply-cluster-manifests.sh when ready."
