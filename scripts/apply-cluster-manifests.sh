#!/usr/bin/env bash
# Apply first-party Kustomize: live overlay when deploy/kustomize/live/private/ has PV + site patches; else base only.
# Helm releases are separate: helm upgrade -f config/helm-values/...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRIV="$ROOT/deploy/kustomize/live/private"
if [ -f "$PRIV/media-pvs.yaml" ] && [ -f "$PRIV/site.yaml" ]; then
  exec kubectl apply -k "$ROOT/deploy/kustomize/live"
fi
exec kubectl apply -k "$ROOT/deploy/kustomize/base"
