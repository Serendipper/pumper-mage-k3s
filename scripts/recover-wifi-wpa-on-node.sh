#!/bin/bash
#
# Generic Debian headless recovery (any worker node — not hostname- or hardware-specific).
# Intended stack: wpasupplicant + dhcpcd (typical laptop WiFi from this repo’s install path).
# Run **on the node itself** (local console, tty, USB NIC, rescue), not from the operator machine over SSH.
#
# Use when: WiFi iface is DOWN, or wpa_supplicant is wedged after a bad wpa_cli experiment (e.g. incomplete
# `add_network` / `set_network` leaving extra ids 1+ while id 0 still holds the original install SSID).
#
# Copy this file to the node if the repo isn’t mounted (e.g. USB stick); behavior is the same in any cluster.
#
# Usage: sudo ./recover-wifi-wpa-on-node.sh [iface]
# Default iface: wlp2s0

set -euo pipefail

IFACE="${1:-wlp2s0}"
WPA="/sbin/wpa_cli"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo." >&2
  exit 1
fi

if [ ! -x "$WPA" ]; then
  echo "Missing $WPA (install wpasupplicant)." >&2
  exit 1
fi

ip link set "$IFACE" up

echo "=== networks before cleanup ==="
"$WPA" -i "$IFACE" list_networks || true

# Remove extra networks (failed experiments often leave id 1+).
for i in 5 4 3 2 1; do
  "$WPA" -i "$IFACE" remove_network "$i" 2>/dev/null || true
done

echo "=== select network 0 (original SSID from install) ==="
"$WPA" -i "$IFACE" list_networks || true
"$WPA" -i "$IFACE" select_network 0 2>/dev/null || true
"$WPA" -i "$IFACE" reconnect 2>/dev/null || true

"$WPA" -i "$IFACE" save_config 2>/dev/null || true

systemctl restart dhcpcd 2>/dev/null || true
systemctl restart "wpa_supplicant@${IFACE}.service" 2>/dev/null || systemctl restart wpa_supplicant.service 2>/dev/null || true

sleep 3
echo "=== link / address ==="
ip link show "$IFACE"
iw dev "$IFACE" link 2>/dev/null || true
ip -4 addr show "$IFACE"

echo "If still DOWN or no IP: journalctl -u wpa_supplicant -b --no-pager | tail -40"
