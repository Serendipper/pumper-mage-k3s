#!/usr/bin/env bash
# Render HAProxy config from config/nodes (gitignored) and apply ConfigMap + namespace for the ingress LB on modera.
# Prerequisites: Pi-hole web UI not on :80 (chart webServerPort 8080); ingress-nginx DaemonSet on all CP nodes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/config/defaults.env"
if [ -f "$ROOT/config/project.env" ]; then
  # shellcheck source=/dev/null
  source "$ROOT/config/project.env"
fi

NODES_FILE="$ROOT/config/nodes"
if [ ! -f "$NODES_FILE" ]; then
  echo "Missing $NODES_FILE — add hostname and LAN IP lines (see docs/agents.md)." >&2
  exit 1
fi

lookup_ip() {
  local host="$1"
  local ip
  ip="$(awk -v h="$host" '$1 == h { print $2; exit }' "$NODES_FILE")"
  if [ -z "$ip" ]; then
    return 1
  fi
  printf '%s' "$ip"
}

CP2_HOST="${K3S_CP2_HOST:-violet-citadel}"

DALARAN_IP="$(lookup_ip dalaran)" || true
if [ -z "${DALARAN_IP:-}" ]; then
  echo "No IP for dalaran in $NODES_FILE" >&2
  exit 1
fi

VIOLET_IP="$(lookup_ip "$CP2_HOST")" || true
if [ -z "${VIOLET_IP:-}" ]; then
  echo "Warning: no IP for secondary CP host \"$CP2_HOST\" in $NODES_FILE — HAProxy will use a single ingress backend (dalaran)." >&2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

{
  cat <<EOF
global
  log stdout format raw local0
  maxconn 4096

defaults
  log global
  mode http
  option httplog
  option dontlognull
  timeout connect 5s
  timeout client 50s
  timeout server 50s

frontend fe_http
  bind *:80
  acl is_pihole hdr(host) -i pihole.lan
  use_backend be_pihole if is_pihole
  default_backend be_ingress_http

backend be_pihole
  server local 127.0.0.1:8080 check inter 3s rise 2 fall 3

backend be_ingress_http
  balance roundrobin
  server cp1 ${DALARAN_IP}:80 check inter 3s rise 2 fall 3
EOF
  if [ -n "${VIOLET_IP:-}" ]; then
    echo "  server cp2 ${VIOLET_IP}:80 check inter 3s rise 2 fall 3"
  fi
  cat <<EOF

frontend fe_https
  mode tcp
  bind *:443
  default_backend be_ingress_tls

backend be_ingress_tls
  mode tcp
  balance roundrobin
  server cp1 ${DALARAN_IP}:443 check inter 3s rise 2 fall 3
EOF
  if [ -n "${VIOLET_IP:-}" ]; then
    echo "  server cp2 ${VIOLET_IP}:443 check inter 3s rise 2 fall 3"
  fi
} >"$TMP/haproxy.cfg"

kubectl apply -f "$ROOT/deploy/kustomize/base/networking/haproxy-ingress-lb/namespace.yaml"
kubectl -n networking create configmap haproxy-ingress-lb \
  --from-file=haproxy.cfg="$TMP/haproxy.cfg" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$ROOT/deploy/kustomize/base/networking/haproxy-ingress-lb/daemonset.yaml"

echo "Applied haproxy-ingress-lb (ConfigMap + DaemonSet). Backends: dalaran=${DALARAN_IP}${VIOLET_IP:+, ${CP2_HOST}=${VIOLET_IP}}."
