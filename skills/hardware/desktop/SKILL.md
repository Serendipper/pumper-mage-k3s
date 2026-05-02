---
name: k3s-desktop-setup
description: Configure a desktop PC as a K3s worker node. Covers wired networking, Wake-on-LAN, BIOS boot order, and power recovery settings. Use when the target node is a desktop (no battery, no lid switch, wired ethernet).
---

# Desktop Setup for K3s

Desktops are simpler than laptops — no lid, no battery, no WiFi driver dance. The main concerns are reliable power-on and wired networking.

## What to Skip

These laptop-specific steps do NOT apply to desktops:
- WiFi driver installation and configuration
- Lid close behavior (`logind.conf`)
- Suspend/hibernate masking (desktops don't auto-suspend)
- Battery management (TLP)
- Fan control (desktop fans are BIOS-managed and adequate)
- Display-off service (no built-in display)

## 1. Wired Ethernet

Desktops use wired ethernet — verify it's up and has DHCP:

```bash
ip addr show
# Should show an interface (e.g., enp6s0) with an IPv4 address
```

No additional configuration needed unless the interface isn't auto-configured. If missing from `/etc/network/interfaces`:

```
allow-hotplug <iface>
iface <iface> inet dhcp
```

### 1a. Static IP on Debian (`/etc/network/interfaces`) — control planes and fixed LAN addresses

Use this when the node must keep a **predictable IPv4** (e.g. **secondary HA control plane**, or you are not using only a router DHCP reservation). **Do not** reuse **`scripts/set-node-static-ip.sh`** for this path — that script is **netplan + WiFi**; Debian headless nodes here typically use **ifupdown** and **wired** `en*` / `eth*` interfaces.

**Failure modes seen in the field (avoid these):**

- **Wrong interface name** in the stanza (`iface` line does not match the NIC that actually carries LAN traffic — confirm with `ip -br link` and `ip -4 route`).
- **Invalid or half-edited stanzas** (duplicate `iface` blocks for the same interface, or mixing `inet dhcp` and `inet static` without removing the old logic).
- **Rebooting to “apply”** before the new config is validated live — you can lose SSH on the wrong fix.

**Proven pattern (match your primary control plane node):** explicit **`address`**, **`netmask`**, **`gateway`**, **`dns-nameservers`**. Example shape (replace `<iface>` and addresses):

```
allow-hotplug <iface>
iface <iface> inet static
    address 198.51.100.7
    netmask 255.255.255.0
    gateway 198.51.100.1
    dns-nameservers 198.51.100.5 198.51.100.1
```
(RFC 5737 documentation prefixes — substitute your real LAN.)

**Validate before you reboot** (or at least before you consider the change safe):

1. Apply with `ifdown <iface> && ifup <iface>` **or** `systemctl restart networking` — use what matches the rest of the host’s networking docs; if unsure, prefer incremental `ifup`/`ifdown` over an immediate full reboot.
2. Check: `ip -4 addr show <iface>`, `ip route`, and `ping -c2 <gateway>`.
3. Confirm SSH still works from the operator path you care about.
4. Only then reboot if you still need to prove persistence across boot.

**Router DHCP reservation:** still configure a **DHCP reservation** for this MAC to the same IP if your LAN expects it — OS static config and router reservation should agree so nothing else grabs the address.

## 2. Wake-on-LAN

Enables remote power-on for headless desktops:

```bash
apt install -y ethtool
ethtool <iface> | grep Wake-on
# "Wake-on: d" means disabled, "g" means enabled
ethtool -s <iface> wol g
```

Persist across reboots via `/etc/systemd/network/50-wol.link`:

```ini
[Match]
MACAddress=<mac>

[Link]
WakeOnLan=magic
```

**BIOS requirements** (must be done manually):
- Enable "Wake on LAN" or "Power on by PCI-E/LAN"
- Disable "Deep Sleep Control" if present (Dell Optiplex has this)
- Set "After Power Loss" to "Last State" or "Power On" for unattended recovery

## 3. BIOS Boot Order

For unattended startup, ensure BIOS boots directly to the OS disk:
- Set the primary boot device to the OS disk (NVMe/SSD/HDD)
- Disable PXE/network boot (unless intentionally used)
- Disable boot menu timeout prompts

This requires physical access to the BIOS setup. Common keys:

| Vendor | BIOS Key | Boot Menu Key |
|--------|----------|---------------|
| Dell | F2 | F12 |
| HP | F10 | F9 |
| Lenovo | F1/F2 | F12 |
| ASUS | Del/F2 | F8 |
| Intel NUC | F2 | F10 |

## 4. Static DHCP Reservation (optional)

**Scope:** **Desktop / wired workers only.** This is **not** a cluster-wide requirement, **not** for laptops (they usually use automatic DHCP like other workers), and **must not** be copied into generic “every node” checklists as mandatory.

Since desktops stay in one place on wired ethernet, their IPs rarely change. A **fixed lease / reservation** on whatever runs **DHCP** on your LAN (often the **router** — not Pi-hole unless it is your DHCP server) is **optional**: it can reduce surprises if the lease pool shifts. If you skip it, use **automatic DHCP** and reconcile **`config/nodes`** with **`kubectl get nodes -o wide`** when the address changes — same as most workers.

Record the MAC address:
```bash
ip link show <iface> | grep ether
```

Configure the reservation on the router (varies by router — for Google Fiber, this is in the GFiber app or web UI).

## Example deployment (generic desktop)

Reference for a working desktop setup:
- Wired: interface and MAC from `ip link` (or config/nodes); use for WoL reservation.
- WoL: enabled via `ethtool` + `50-wol.link`
- BIOS: WoL enabled, Deep Sleep Control disabled (some Dell Optiplex have "Deep Sleep Control" to disable).
- Role: Control plane or worker; OS prep is identical.
