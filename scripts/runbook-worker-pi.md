# Runbook: Add a Raspberry Pi as a K3s worker

**For agents:** This is the **only** runbook for adding a Pi (or Debian arm64 SBC) as a worker. Use it for **any** Pi node: set `NODE_HOSTNAME` and `NODE_IP` (e.g. modera, medivh, or a new name). Do **not** create node-specific runbooks. This procedure matches how **modera** was set up; see `nodes/modera-rpi5.md` for the reference changelog.

---

## Prerequisites (check before starting)

Nothing is assumed. Verify all of the following.

### Repo and config

- This repo is cloned and you can `cd` to its root (e.g. `/path/to/k3s`).
- **config/defaults.env** exists (committed). **config/project.env** exists (create from `config/project.env.example`; it is gitignored).
- Required variables are set (see table below). Scripts source `defaults.env` then `project.env`.

### Config variables used by this runbook

| Variable | Where | Used in |
|----------|--------|---------|
| **K3S_SSH_USER** | defaults.env or project.env | SSH to Pi, token fetch, join |
| **K3S_NODE_PASSWORD** | project.env (required) | sshpass to Pi, sudo on Pi, token fetch if no key to CP |
| **K3S_SSH_KEY** | defaults.env or project.env | Deploy key to Pi (path to private key on *this* machine) |
| **K3S_WIFI_SSID** | project.env | Phase 1 only: render-pi-firstboot-network.sh |
| **K3S_WIFI_PSK** | project.env | Phase 1 only: render-pi-firstboot-network.sh |
| **K3S_CP_HOST** | defaults.env (e.g. dalaran) | Token fetch: `ssh $K3S_SSH_USER@$K3S_CP_HOST` |
| **K3S_CP_IP** | project.env or resolve from config/nodes | Join URL, token fetch if using IP |
| **K3S_API_PORT** | defaults.env (6443) | Join URL |
| **K3S_NODE_TOKEN_PATH** | defaults.env | Token fetch from CP |
| **K3S_INSTALL_URL** | defaults.env (https://get.k3s.io) | Join command |
| **K3S_SCAN_SUBNET** | project.env (e.g. 192.168.1.0/24) | Finding Pi IP after first boot |

For **staged first-boot (Phase 1)** you must have: **K3S_WIFI_SSID**, **K3S_WIFI_PSK**, **K3S_NODE_PASSWORD**, **K3S_SSH_USER**.  
For **Phase 2 and 3** you must have: **K3S_SSH_USER**, **K3S_NODE_PASSWORD**, **K3S_CP_HOST**, **K3S_CP_IP**, **K3S_API_PORT**, **K3S_NODE_TOKEN_PATH**, **K3S_INSTALL_URL**.

### Tools on the machine running this runbook

- **sshpass** — password-based SSH until the key is deployed to the Pi.
- **nmap** — for scanning the subnet to find the Pi’s IP (or use `./scripts/scan-network.sh`; it uses `--host-timeout 30s` so slow hosts are not skipped).
- **SSH access to the control plane** — to fetch the join token you must run `ssh $K3S_SSH_USER@$K3S_CP_HOST "cat $K3S_NODE_TOKEN_PATH"`. So either: (1) key-based SSH to the CP is already set up (e.g. `config/nodes` has the CP, you ran `./scripts/ssh-config-from-nodes.sh`, and you have the project key), or (2) use `sshpass -p "$K3S_NODE_PASSWORD" ssh $K3S_SSH_USER@$K3S_CP_IP "cat $K3S_NODE_TOKEN_PATH"`.
- **Project SSH key** — the key at **K3S_SSH_KEY** (or `~/.ssh/k3s_ed25519`) must exist on *this* machine so we can deploy its public half to the Pi in Phase 3.1.

### Staged first-boot only (Phase 1)

- A USB stick (or SD card) to write the Pi OS image to, and a way to mount its partitions (e.g. on Linux: mount the first partition as vfat for boot, the second as ext4 for root).
- The **Raspberry Pi OS Lite 64-bit** image. See **Image URL and checksum** in Phase 1.2.
- The Pi must be able to join your WiFi (or ethernet); WiFi credentials come from **config/project.env** via the generated network config.

---

## Overview

Two paths:

1. **Staged first-boot (recommended)** — Write Pi OS image to USB, add cloud-init network + user-data and hostname, and enable SSH. Pi boots with SSH, hostname, and WiFi already set. Then do OS prep and join. Same as modera.
2. **Already imaged / manual** — Pi is already running (e.g. you used Imager with SSH + hostname). Skip to **Phase 2: OS prep** and use the Pi’s current IP.

Variables you need in both paths:

- **NODE_HOSTNAME** — Kirin Tor hostname (e.g. `modera`, `medivh`). See **docs/agents.md** for naming.
- **NODE_IP** — Pi’s IP after first boot (from DHCP or scan). Update after reboot if it changes.

**Scripts:** **scripts/pi-worker-os-prep.sh** and **scripts/pi-worker-join.sh** run Phase 2 and Phase 3 for a given `NODE_HOSTNAME` and `NODE_IP`. The join script has no internal timeout (allow ≥10 min if you run it under a wrapper). Long-running steps show a spinner and elapsed time (see **scripts/lib/spinner.sh**).

---

## Phase 1: Staged first-boot (recommended — same as modera)

Do this on a machine that can write to a USB stick (e.g. medivh sandbox, or your laptop). Repo root and **config/project.env** with WiFi and user/password are required.

### 1.1 Generate first-boot configs

From repo root:

```bash
cd /path/to/k3s
source config/defaults.env && source config/project.env

./scripts/render-pi-firstboot-network.sh
# → config/generated/pi-firstboot-network.yaml (requires K3S_WIFI_SSID, K3S_WIFI_PSK)

./scripts/render-pi-firstboot-userdata.sh <NODE_HOSTNAME>
# → config/generated/pi-firstboot-userdata.yaml (hostname + SSH user + password; requires K3S_NODE_PASSWORD, K3S_SSH_USER)
```

Example: for medivh run `./scripts/render-pi-firstboot-userdata.sh medivh`.

### 1.2 Image and write to USB

- **Image:** Raspberry Pi OS Lite 64-bit (Trixie). Use the same image as in **skills/sanitizing-sandbox/SKILL.md** § Pi OS image and staging:
  - **URL:** https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz
  - **Verify:** In the same directory as the downloaded file there should be `2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256`. Run:  
    `sha256sum -c 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256`
- **Write whole disk** (replace `sdX` with the actual USB device; wrong device will destroy data):

```bash
xzcat /path/to/2025-12-04-raspios-trixie-arm64-lite.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 1.3 Apply first-boot config to the USB

- **Boot partition:** Mount the USB’s **boot** partition (usually the first partition, vfat). On Linux it may appear as `/dev/sdX1`. Then:
  - Copy `config/generated/pi-firstboot-network.yaml` → **`<mount>/network-config`** (exact filename; cloud-init reads it).
  - Copy `config/generated/pi-firstboot-userdata.yaml` → **`<mount>/user-data`** (exact filename).
  - **Enable SSH:** Create an empty file **`<mount>/ssh`**. Raspberry Pi OS enables the SSH server on first boot when this file exists. The user-data sets the user and password; the `ssh` file ensures the server is running.
- **Root partition:** Mount the USB’s **root** partition (usually the second partition, ext4). Then:
  - Write the hostname to **`etc/hostname`**: contents exactly **`<NODE_HOSTNAME>`** (e.g. `modera`).
  - In **`etc/hosts`**, ensure the line for 127.0.1.1 is **`127.0.1.1 <NODE_HOSTNAME>`** (e.g. `127.0.1.1 modera`). Add or replace as needed.
- Unmount both partitions. Plug the USB into the Pi and boot. The Pi will come up with SSH enabled, hostname set, and WiFi (if configured) set.

### 1.4 Find the Pi’s IP and set variables

After first boot (wait 1–2 minutes), discover the Pi’s IP:

```bash
cd /path/to/k3s
source config/defaults.env && source config/project.env
./scripts/scan-network.sh
# Or, if running nmap manually: nmap -Pn -p 22 "$K3S_SCAN_SUBNET" --host-timeout 30s
# Match by hostname (e.g. modera.lan, medivh.lan) or by device type.
```

Then set variables (use the IP you found):

```bash
source config/defaults.env && source config/project.env
NODE_HOSTNAME=modera   # or medivh, etc.
NODE_IP=192.168.1.217 # use the IP you found
```

---

## Phase 2: OS prep (same for staged or already-imaged Pi)

Run from repo root. Requires SSH to the Pi (password is fine; key deploy is in Phase 3).

```bash
cd /path/to/k3s
source config/defaults.env && source config/project.env
# Set NODE_HOSTNAME and NODE_IP if not already set.
```

### 2.1 SSH test

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$K3S_SSH_USER@$NODE_IP" "hostname; uname -m"
# Expect: NODE_HOSTNAME, aarch64
```

If hostname is wrong (e.g. still `raspberrypi`):

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S hostnamectl set-hostname $NODE_HOSTNAME"
```

### 2.2 Non-free repos and update

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S bash -c 'sed -i \"s/main non-free-firmware/main contrib non-free non-free-firmware/g\" /etc/apt/sources.list && apt update && apt upgrade -y'"
```

If you get “package not found” or the sed doesn’t change the file, the sources line may differ (e.g. only `main`). On the Pi run `cat /etc/apt/sources.list` and ensure the main line includes `contrib non-free` (and `non-free-firmware` if present). Edit manually if needed, then `apt update && apt upgrade -y`.

### 2.3 Cgroups (Pi cmdline.txt)

Append cgroup args to the boot cmdline. Pi OS may use `/boot/firmware/cmdline.txt` or `/boot/cmdline.txt`:

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S bash -c '
  for f in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
    [ -f \"\$f\" ] && ! grep -q cgroup_enable \"\$f\" && sed -i \"s/\$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/\" \"\$f\"
  done
'"
```

### 2.4 iptables-legacy and curl

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S bash -c 'apt install -y iptables curl && update-alternatives --set iptables /usr/sbin/iptables-legacy && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy'"
```

### 2.5 Reboot (required for cgroups)

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S reboot"
```

Wait 1–2 minutes. If DHCP gave the Pi a new IP, run the scan again and set **NODE_IP** to the new value before Phase 3.

---

## Phase 3: Join cluster

### 3.1 Verify cgroups and deploy SSH key

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@$NODE_IP" "cat /proc/cmdline | grep cgroup"
# Should show: cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```

Deploy the project key so `scripts/ssh-node.sh` and key-based SSH work. The key must exist on *this* machine at **K3S_SSH_KEY** or `~/.ssh/k3s_ed25519`:

```bash
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
[ -f "$KEY.pub" ] && sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=no "$K3S_SSH_USER@$NODE_IP" \
  "mkdir -p ~/.ssh; chmod 700 ~/.ssh; echo '$(cat "$KEY.pub")' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
```

### 3.2 Get join token and join

You must be able to reach the control plane. Either use key-based SSH (if you have the project key and CP in your SSH config) or use sshpass:

```bash
# Option A: key-based (if ssh $K3S_CP_HOST works)
K3S_TOKEN=$(ssh "$K3S_SSH_USER@$K3S_CP_HOST" "cat $K3S_NODE_TOKEN_PATH")

# Option B: password-based
# K3S_TOKEN=$(sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$K3S_CP_IP" "cat $K3S_NODE_TOKEN_PATH")
```

Then join (run on the Pi via SSH):

```bash
K3S_URL="https://${K3S_CP_IP}:${K3S_API_PORT}"
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$NODE_IP" "curl -sfL -4 $K3S_INSTALL_URL | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sudo sh -"
```

**Pi download slowness:** Pi over Wi‑Fi can take 5–10 minutes to download the ~68 MB binary from GitHub. Use `curl -4` to force IPv4. Do not interrupt the SSH session. No script in this repo runs the join (it is manual/copy‑paste); if you automate this step elsewhere, use a timeout of at least 10 minutes for the join command.

If the key was deployed in 3.1 you can use:
`ssh "$K3S_SSH_USER@$NODE_IP" "curl -sfL -4 $K3S_INSTALL_URL | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sudo sh -"`

### 3.3 Label and verify

```bash
kubectl label node $NODE_HOSTNAME node-role.kubernetes.io/worker=worker
# Or from a machine without kubectl: ./scripts/ssh-node.sh dalaran "sudo k3s kubectl label node $NODE_HOSTNAME node-role.kubernetes.io/worker=worker"

kubectl get nodes -o wide
# NODE_HOSTNAME should be Ready, role worker. Note INTERNAL-IP — that is the source of truth for config/nodes.
```

### 3.4 Update config and docs

- **config/nodes:** Add or update one line: **`NODE_HOSTNAME <IP>`** using the **INTERNAL-IP** from `kubectl get nodes -o wide` (not the IP you used for SSH if it changed).
- **SSH config:** Run `./scripts/ssh-config-from-nodes.sh` and merge the printed block into your `~/.ssh/config` (or replace the existing K3s block).
- **Node changelog:** Create or update **nodes/<NODE_HOSTNAME>-<model>.md** (e.g. `nodes/medivh-pi5.md`) from the template in **docs/agents.md** (Node Details, Hardware Snapshot, Change History, Remaining Roadmap, Known Limitations). Use output from the Pi: `lscpu`, `free -h`, `lsblk`, `ip link`, `cat /proc/device-tree/model`.
- **nodes/roadmap.md:** Update the inventory table.

### Optional after join

- **Static IP:** To give the Pi a fixed IP (e.g. on WiFi), see **scripts/set-node-static-ip.sh**. Example: `./scripts/set-node-static-ip.sh modera 192.168.1.5/24`. Then update **config/nodes** and run `./scripts/ssh-config-from-nodes.sh`.
- **Power check (Pi):** On the Pi run `vcgencmd get_throttled` — `0x0` means no undervoltage/throttling.
- **Boot media:** For long-term use, prefer USB SSD over SD or USB stick; see **skills/hardware/sbc/SKILL.md**.

---

## If you didn’t use staged first-boot

You imaged the Pi some other way (e.g. Raspberry Pi Imager). Then:

1. **SSH must be enabled** or the runbook can’t connect. In Raspberry Pi Imager: click the gear (⚙) before writing → enable SSH, set user and password to match **K3S_SSH_USER** / **K3S_NODE_PASSWORD** in config, set hostname to **NODE_HOSTNAME**. If the image is already written and you have console: `sudo raspi-config` → Interface Options → SSH → Enable (or `sudo systemctl enable --now ssh`).
2. Boot the Pi, find its IP (run `./scripts/scan-network.sh` or nmap), set **NODE_HOSTNAME** and **NODE_IP**.
3. Start at **Phase 2: OS prep** (2.1 SSH test). If hostname wasn’t set in Imager, fix it in 2.1.

---

## Troubleshooting

| Problem | Likely cause | Fix |
|--------|----------------|-----|
| SSH refused / timeout | SSH not enabled or wrong IP | Staged: check boot partition has `user-data`, `network-config`, and empty `ssh` file. Imager: enable SSH in gear; confirm IP with `./scripts/scan-network.sh`. |
| Wrong hostname | First-boot not applied or Imager not set | Set in 2.1: `hostnamectl set-hostname $NODE_HOSTNAME`. |
| Package not found | Missing or different apt sources | On Pi check `cat /etc/apt/sources.list`; ensure line has `contrib non-free`. Edit if needed, then `apt update && apt upgrade -y`. |
| Can’t fetch token | No SSH to control plane | Use sshpass to CP: `K3S_TOKEN=$(sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$K3S_CP_IP" "cat $K3S_NODE_TOKEN_PATH")`. Ensure **K3S_CP_IP** is set and CP is reachable. |
| Node NotReady | K3s agent or network | On Pi: `systemctl status k3s-agent`; check connectivity to control plane (ping **K3S_CP_IP**). |
| Port 22 filtered after K3s | iptables | On Pi: `sudo iptables -F` (or debug rules). |
