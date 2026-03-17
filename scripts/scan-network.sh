#!/bin/bash
# Discover devices on the LAN: union of (1) hosts that respond on port 22 and
# (2) hosts that have a reverse-DNS/mDNS name. Output: one line per device, "IP name" or "IP —".
#
# Run from repo root. Uses K3S_SCAN_SUBNET from config (default 192.168.1.0/24).
# Requires: nmap, getent (libc), avahi-resolve (optional but recommended).
#
# Why --host-timeout 30s: without it, slow or filtered hosts are skipped and you miss devices
# (e.g. hosts that don't answer ping or are slow to respond on port 22).

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
[ -f "config/defaults.env" ] && . config/defaults.env
[ -f "config/project.env" ] && . config/project.env

SUBNET="${K3S_SCAN_SUBNET:-192.168.1.0/24}"
TMPD=$(mktemp -d)
trap "rm -rf '$TMPD'" EXIT

# 1) IPs that responded on port 22 (open or closed) = something is there
nmap -Pn -p 22 "$SUBNET" --host-timeout 30s -oG - 2>/dev/null \
  | grep "Host:" | grep "Ports:" \
  | sed 's/.*Host: \([0-9.]*\).*Ports: \([^\t]*\).*/\1 \2/' \
  | awk '$2 ~ /open|closed/ {print $1}' \
  | sort -u -t. -k4 -n \
  > "$TMPD/responded.txt"

# 2) IPs that have a reverse-DNS or mDNS name (getent then avahi)
# Derive range from subnet (simple case: 192.168.1.0/24 → 1-254)
if [[ "$SUBNET" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.0/24$ ]]; then
  base="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  for i in $(seq 1 254); do
    ip=$base.$i
    name=$(getent hosts "$ip" 2>/dev/null | awk '{print $2}' | head -1)
    [ -z "$name" ] && name=$(avahi-resolve -a "$ip" 2>/dev/null | awk '{print $2}')
    [ -n "$name" ] && echo "$ip"
  done | sort -u -t. -k4 -n > "$TMPD/have_name.txt"
else
  touch "$TMPD/have_name.txt"
fi

# 3) Union = every device (responded on port 22 OR has a name)
cat "$TMPD/responded.txt" "$TMPD/have_name.txt" | sort -u -t. -k4 -n > "$TMPD/devices.txt"

# 4) For each device IP, get name (getent then avahi) or —
while read -r ip; do
  name=$(getent hosts "$ip" 2>/dev/null | awk '{print $2}' | head -1)
  [ -z "$name" ] && name=$(avahi-resolve -a "$ip" 2>/dev/null | awk '{print $2}')
  [ -z "$name" ] && name="—"
  echo "$ip $name"
done < "$TMPD/devices.txt"
