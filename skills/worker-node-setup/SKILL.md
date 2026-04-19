---
name: k3s-worker-node-setup
description: Add a new worker node to the K3s cluster. Handles OS prep, hardware detection, hardware-specific hardening dispatch, cluster join, and documentation. Use when the user provides an IP or hostname for a new node to set up.
---

# K3s Worker Node Setup

## Overview

Autonomous procedure to take a freshly-installed Debian machine from SSH-accessible to fully joined K3s worker. The agent detects hardware class and dispatches to the appropriate hardware sub-skill.

## Inputs

The user provides:
- **IP address** of the node (ethernet, from initial install)
- **Hostname** (Warcraft theme — see `docs/agents.md`)
- **Hardware description** (e.g., "ThinkPad T480", "Raspberry Pi 4")

## Procedure

### 1. Establish SSH

Source **config/defaults.env** and **config/project.env** so credentials and control-plane IP are set (required for autonomous runs). Ensure `K3S_NODE_PASSWORD` is set.

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@<IP>" "hostname"
```

If unreachable via IPv4, try jump host through control plane:

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
sshpass -p "$K3S_NODE_PASSWORD" ssh -J "$K3S_SSH_USER@$K3S_CP_IP" "$K3S_SSH_USER@<IPv6>" "hostname"
```

May need to install `sshpass` on the control plane first if using jump host.

### 2. Detect Hardware Class

```bash
# Check for battery (laptop indicator)
ls /sys/class/power_supply/BAT* 2>/dev/null

# Check for lid switch
cat /proc/acpi/button/lid/*/state 2>/dev/null

# Check architecture
uname -m

# Full hardware ID
dmidecode -s system-product-name
dmidecode -s chassis-type
```

Decision:
- Battery or lid present → **laptop** → read `skills/hardware/laptop/SKILL.md`
- x86_64, no battery, wired → **desktop** → read `skills/hardware/desktop/SKILL.md`
- `aarch64` / `armv7l` → **SBC** → read `skills/hardware/sbc/SKILL.md`

### 3. Enable Non-Free Repos

```bash
sed -i 's/main non-free-firmware/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
apt update
```

### 4. System Update

```bash
apt update && apt upgrade -y
```

### 5. GRUB Cgroups

```bash
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"/' /etc/default/grub
update-grub
```

Reboot is needed but defer until after all config to minimize reboots.

### 6. iptables-legacy Pivot

```bash
apt install -y iptables
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

### 7. Install curl

```bash
apt install -y curl
```

### 8. Hardware-Specific Hardening

Dispatch based on detection in step 2:
- **Laptop (dedicated)**: Follow `skills/hardware/laptop/SKILL.md` (WiFi **including mandatory §2a verification**, lid, suspend, display, battery, fan)
- **Laptop (hybrid / daily driver)**: Follow `skills/hardware/laptop-hybrid/SKILL.md` (non-Debian OK, no headless hardening, cordon/drain workflow)
- **Desktop**: Follow `skills/hardware/desktop/SKILL.md` (WoL, BIOS)
- **SBC**: Follow `skills/hardware/sbc/SKILL.md` (boot media, ARM quirks)

Do NOT suggest hybrid mode. Only use it if the user explicitly says the laptop is their daily driver or asks about part-time nodes. Dedicated hardware is always preferred.

**Laptops (WiFi):** Do not proceed past hardware hardening until **`skills/hardware/laptop/SKILL.md` §2a** is satisfied: **current SSID must match `K3S_WIFI_SSID`** from sourced config (unless you are explicitly in the temporary-SSID path in laptop §2 and will switch back), plus IPv4 on the WiFi interface and **`ping -I <wifi-iface> <K3S_CP_IP>`**. “Already online” or “SSH works” is **not** a substitute for that check — see laptop §2 opening paragraphs.

### 9. Reboot

If cgroups were modified (step 5), reboot now:
```bash
reboot
```

Wait for the node to come back. If it switched to WiFi, it may have a new IP — check DHCP or scan (subnet from **config/defaults.env**: `K3S_SCAN_SUBNET`):
```bash
source config/defaults.env
nmap -sn "$K3S_SCAN_SUBNET"
```

**Laptop + WiFi:** After the node is reachable again, **re-run laptop §2a** over SSH (same three checks). Ethernet may be unplugged; use the IP that answers SSH. If WiFi fails post-reboot, fix it before cluster join.

### 10. Hardware Snapshot

After reboot, capture hardware details:

```bash
lscpu | head -20
free -h
lsblk -o NAME,SIZE,TYPE,MODEL
dmidecode -s system-serial-number
dmidecode -s system-product-name
ip link show
sensors
```

For laptops, also:
```bash
cat /sys/class/power_supply/BAT*/type
cat /sys/class/power_supply/BAT*/capacity
cat /sys/class/power_supply/BAT*/status
cat /sys/class/power_supply/BAT*/energy_full
cat /sys/class/power_supply/BAT*/energy_full_design
cat /sys/class/power_supply/BAT*/cycle_count
```

### 11. Join Cluster

Source config and retrieve the token from the control plane (`K3S_CP_HOST` and `K3S_NODE_TOKEN_PATH` from config):

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
ssh "$K3S_SSH_USER@$K3S_CP_HOST" "cat $K3S_NODE_TOKEN_PATH"
```

Join (run on the new node via SSH; use token from above). K3s URL and install script from config:

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
# Always source defaults.env first so K3S_API_PORT (e.g. 6443) is set — do not build K3S_URL from project.env alone.
K3S_URL="https://${K3S_CP_IP}:${K3S_API_PORT}"
curl -sfL "$K3S_INSTALL_URL" | K3S_URL="$K3S_URL" K3S_TOKEN=<token> sh -
```

Non-interactive installs must wrap the installer in `sudo` with a password on stdin once (see recent `vargoth` bring-up): e.g. `echo "$K3S_NODE_PASSWORD" | sudo -S env K3S_URL=... K3S_TOKEN=... sh -c 'curl -sfL ... | sh -'`.

### 12. Deploy project SSH key to the new node

**`./scripts/ssh-node.sh`** uses the project key (`K3S_SSH_KEY`); it does not use password auth. After bootstrap you have only used **`sshpass`** to this host — deploy the public key **before** any step that calls **`./scripts/ssh-node.sh <hostname>`** toward **this** worker.

1. Ensure **`config/nodes`** contains one line: **`<hostname> <IP>`** (same **INTERNAL-IP** you will reconcile with `kubectl`; required for `ssh-node.sh` to resolve the host by name).
2. Install the key — see **`skills/agent-environment-setup/SKILL.md`** → **Deploy Public Key to a Node** (append to `authorized_keys` via `sshpass`, or **`ssh-copy-id`** after sourcing config; example: `KEY="${K3S_SSH_KEY/#\~/$HOME}"` then `ssh-copy-id -i "$KEY.pub" "$K3S_SSH_USER@<IP>"` with **`sshpass`** if needed).

Skip only if this node already had the project key (e.g. reimage of an existing listed host).

### 13. Label Node

From the control plane (`K3S_CP_HOST` from config), e.g. `./scripts/ssh-node.sh $K3S_CP_HOST 'sudo k3s kubectl label node <hostname> node-role.kubernetes.io/worker=worker'`. If **`sudo`** on the CP requires a password in non-interactive SSH, use **`echo "$K3S_NODE_PASSWORD" | sudo -S`** before **`k3s kubectl`** (see **`docs/agents.md`**).

### 14. Verify

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
# From CP or any host with kubeconfig:
k3s kubectl get nodes -o wide
# New node should show: Ready, role worker
```

Reconcile **`config/nodes`** with the **INTERNAL-IP** column for every node (see `docs/agents.md`). Then **test SSH** from the repo using the project key:

```bash
./scripts/ssh-node.sh <hostname> 'hostname'
```

**Laptop + WiFi:** If the node is often WiFi-only, confirm `./scripts/ssh-node.sh` reaches the same IP `kubectl` reports (or the IP you intentionally keep in `config/nodes` after reconciliation).

### 15. Documentation

Create `nodes/<hostname>-<model>.md` following the changelog template in `docs/agents.md`. Include:
1. Node Details table
2. Hardware Snapshot
3. Change History (all phases performed)
4. Remaining Roadmap (DHCP: automatic is normal; reconcile `config/nodes` when IP changes; optional fixed lease on the DHCP server if you want)
5. Known Limitations (if any)

Update the inventory table in `nodes/roadmap.md`.

Ensure the new node stays in **config/nodes** (one line: `hostname IP`) so `scripts/ssh-node.sh` and agent-environment-setup batch deploy can reach it (it should already be there from step **12**).

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `ssh-node.sh` to the new worker hangs or never returns | Project key not in `authorized_keys` on that host yet | Run step **12** (`skills/agent-environment-setup` — deploy public key) before **`ssh-node.sh`** |
| SSH times out | Wrong IP, node asleep, firewall | Check IP, verify power, scan network |
| No IPv4 on ethernet | DHCP issue | Use IPv6 via control plane (K3S_CP_HOST) as jump host |
| Package not found | Missing apt repos | Add `contrib non-free non-free-firmware` |
| WiFi doesn't come up after reboot | Driver issue | See `skills/hardware/laptop/wifi-drivers.md` |
| Node on wrong SSID / “WiFi works” but not `K3S_WIFI_SSID` | Skipped laptop §2 / §2a | Check `iw dev <iface> link` or `nmcli`; apply laptop §2 and verify §2a before join |
| Node shows NotReady | K3s agent not running or network issue | `systemctl status k3s-agent`, check flannel |
| Port 22 filtered after K3s install | iptables rules conflict | Flush rules locally: `iptables -F` |
