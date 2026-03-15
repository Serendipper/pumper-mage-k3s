---
name: k3s-control-plane-setup
description: Deploy or rebuild the K3s control plane server node with external PostgreSQL datastore. Use when setting up the control plane, initializing the cluster, or recovering from a control plane failure.
---

# K3s Control Plane Setup

## Prerequisites

- Debian stable installed (headless, SSH-only). See `AGENTS.md` for OS conventions.
- External PostgreSQL accessible; URL in **config/project.env** (`K3S_DATASTORE_URL`) or **config/defaults.env**.
- Node is on wired ethernet with a known IP.

## Procedure

### 1. OS Prep

Same as worker nodes — see `skills/worker-node-setup/SKILL.md` for details. Summary:

```bash
apt update && apt upgrade -y

sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"/' /etc/default/grub
update-grub
reboot

apt install -y iptables
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

apt install -y curl
```

### 2. PostgreSQL Connectivity

Source config and verify PostgreSQL (datastore URL in **config/project.env** or **config/defaults.env**):

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
apt install -y postgresql-client
psql "${K3S_DATASTORE_URL}" -c "SELECT 1;"
```

Set `K3S_DATASTORE_URL` in **config/project.env** if not set. If connection fails: check DB app is running, port exposed, credentials match.

### 3. K3s Config

Create `/etc/rancher/k3s/config.yaml` from config (no hardcoded URL):

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
# K3S_DATASTORE_URL must be set in config/project.env for control plane
cat << EOF | sudo tee /etc/rancher/k3s/config.yaml
write-kubeconfig-mode: "0644"
datastore-endpoint: "${K3S_DATASTORE_URL}"
disable:
  - servicelb
  - traefik
EOF
```

Adjust `disable` list based on what the user wants. Current decisions:
- **traefik** disabled — custom ingress controller planned
- **servicelb** disabled — custom load balancer planned

### 4. Install K3s Server

```bash
source config/defaults.env
curl -sfL "$K3S_INSTALL_URL" | sh -
```

This reads `config.yaml` automatically. Wait for the install to complete.

### 5. Verify

```bash
k3s kubectl get nodes
# Should show: <hostname>  Ready  control-plane  ...

k3s kubectl get pods -A
# Expected system pods: coredns, local-path-provisioner, metrics-server
# traefik and servicelb should NOT appear
```

### 6. Extract Join Token

Worker nodes need this to join. Path is in **config/defaults.env** (`K3S_NODE_TOKEN_PATH`):

```bash
cat /var/lib/rancher/k3s/server/node-token
```

Save this value — it's used in the worker node join command.

### 7. Wake-on-LAN (desktop only)

If the CP is a desktop that should be remotely power-on-able:

```bash
apt install -y ethtool
ethtool -s <iface> wol g
```

Persist via `/etc/systemd/network/50-wol.link`:

```ini
[Match]
MACAddress=<mac>

[Link]
WakeOnLan=magic
```

Also enable WoL in BIOS and disable Deep Sleep Control if present.

### 8. Hardware Snapshot + Documentation

Run hardware snapshot commands (see `skills/worker-node-setup/SKILL.md` snapshot section) and create `control-plane/<hostname>-<model>.md` following the template in `AGENTS.md`.

## Recovery

If the control plane needs rebuilding:

1. The cluster state lives in PostgreSQL, not on the CP node itself.
2. Reinstall OS, repeat this procedure with the same `config.yaml`.
3. K3s will reconnect to the existing datastore and resume.
4. Workers may need to be restarted (`systemctl restart k3s-agent`) to reconnect.

## Known Decisions

- No mDNS/Avahi — conflicts with CoreDNS. Use static DHCP + hosts file.
- Single control plane node (not HA) — acceptable for homelab.
