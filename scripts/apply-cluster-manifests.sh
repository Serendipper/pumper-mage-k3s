#!/usr/bin/env bash
# Apply first-party Kustomize base (cert-manager CRs, storage, ingress, OpenClaw gateway, optional Grafana CM).
# Helm releases are separate: helm upgrade -f config/helm-values/...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec kubectl apply -k "$ROOT/deploy/kustomize/base"
