# K3s Homelab — Agent Runbook

## What This Is

A K3s Kubernetes cluster built on repurposed consumer hardware (laptops, desktops, SBCs). Designed for homelabbers and tech enthusiasts with leftover machines sitting around.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐
│  dalaran (CP)   │◄────│  External PG DB  │
│  <K3S_CP_IP>    │     │  <from config>    │
└────────┬────────┘     └──────────────────┘
         │  IPs from config/nodes (gitignored)
         │  join token
    ┌────┴────┬──────────┐
    │         │          │
 ┌──▼──┐  ┌──▼──┐  ┌────▼──┐
 │node1│  │node2│  │node N │
 └─────┘  └─────┘  └───────┘
  (mixed hardware around the house)
```

- **Control plane**: hostname `dalaran`; IP from **config/nodes** (key `K3S_CP_HOST`) or **config** `K3S_CP_IP`. Do not hardcode IPs.
- **Workers**: Laptops, desktops, SBCs — joined via K3s agent. Node IPs from **config/nodes** only.
- **Datastore**: From **config** `K3S_DATASTORE_URL` (host:port); do not hardcode
- **CNI**: Flannel (K3s default)
- **Disabled defaults**: traefik, servicelb. HTTP(S) → NGINX Ingress; ServiceLB (L4, `type: LoadBalancer`) is off unless re-enabled in control-plane-setup.

## Conventions

### OS
- **Debian stable** (currently Trixie/13), headless, amd64 netinst
- Software selection: SSH server + standard system utilities only
- User and password: set in **config/** (`K3S_SSH_USER`, `K3S_NODE_PASSWORD`)

### Hostnames
[Kirin Tor](https://wowpedia.fandom.com/wiki/Kirin_Tor) theme from World of Warcraft. See full naming convention in `README.md`.

**Control plane**: Named after Dalaran and Kirin Tor strongholds. Primary CP is always `dalaran`. HA secondaries use other bases: `violet-citadel`, `karazhan`, `violet-hold`, etc.

**Worker nodes**: Named after [members of the Kirin Tor](https://wowpedia.fandom.com/wiki/List_of_Kirin_Tor_mages), prioritized by lore significance. Use Tier 1 names first (Khadgar, Antonidas, Aegwynn, Medivh, Jaina, Rhonin), then Council of Six members, then notable mages.

Current assignments:

| Name | Who | Role |
|------|-----|------|
| `dalaran` | Capital of the Kirin Tor | Control plane |
| `aegwynn` | Guardian of Tirisfal | Worker |
| `rhonin` | Leader of the Kirin Tor, hero of the Nexus War | Worker |
| `antonidas` | Grand Master, killed defending Dalaran | Worker |
| `khadgar` | Current Archmage, leader of the Council of Six | Worker |
| `modera` | Council of Six | Worker (Pi 5) |

Next available (Tier 1): `medivh` (sandbox), `jaina`

### Network
- **WiFi**: SSID and PSK live only in **config/** (`K3S_WIFI_SSID`, `K3S_WIFI_PSK`). Prefer 2.4 GHz for nodes (range); 5 GHz often busy; 6 GHz for WiFi 6E/7 only.
- Ethernet is in a different room than node end locations. Initial OS install uses ethernet, then nodes switch to WiFi (or wired via switch if available).

### SSH Access
Project SSH key: `~/.ssh/k3s_ed25519` (ed25519, comment `k3s-homelab`). For **autonomous** agent runs (worker/control-plane setup, laptop WiFi, Pi first-boot), run **project-setup** once (`skills/project-setup/SKILL.md`): it creates `config/project.env` (gitignored) with SSH user/password, WiFi SSID/PSK, control-plane IP, and datastore URL so no secrets are hardcoded in skills.

```bash
# Preferred — key-based via SSH config (after agent-environment-setup)
ssh dalaran hostname
ssh khadgar hostname

# Fallback — password-based for nodes without the key yet (use config/project.env: K3S_NODE_PASSWORD, K3S_SSH_USER)
source config/defaults.env && source config/project.env
sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@<IP>" ...
```
- SSH config maps hostnames to IPs: `ssh <hostname>` just works (populate via `./scripts/ssh-config-from-nodes.sh >> ~/.ssh/config`).
- Jump host fallback: if a node has no IPv4, SSH via the control plane (hostname in **config**: `K3S_CP_HOST`).
- `sudo` uses the same password; source config and use `$K3S_NODE_PASSWORD` with `sudo -S`.

**Agent SSH (context-independent):** When the Cursor agent runs terminal commands, the process may have a different user/HOME. Use the wrapper so SSH uses the project key and known_hosts regardless of context:

```bash
./scripts/ssh-node.sh <hostname> '<command>'
```

The script reads **config/nodes** (hostname + IP, one per line; gitignored; agent maintains it) and **config/defaults.env** / **config/project.env** for key/user. **Do not hardcode IPs** — resolve from config/nodes or use K3S_CP_IP / K3S_SCAN_SUBNET from config. Override with env vars if needed.

### Config (config/)

All cluster-related values live under **config/**; nothing is hardcoded in scripts or skills.

| File | Purpose | Maintained by |
|------|---------|----------------|
| **defaults.env** | Non-secret defaults (SSH user, key path, WiFi SSID, CP hostname/IP, scan subnet, K3s URL/port/token path) | Committed; edit to change defaults |
| **project.env** | Secrets and overrides (password, WiFi PSK, datastore URL); gitignored | You (create from project.env.example) |
| **nodes** | Hostname and IP, one per line; **gitignored**. Source of truth for node and CP IPs; agent must read from here, never hardcode IPs. | Agent when nodes are added/removed |
| **generated/** | Generated files (e.g. Pi first-boot network from `render-pi-firstboot-network.sh`) | Scripts; gitignored |
| **helm-values/** | Live Helm values (project-specific); gitignored; not for public repo | Agent / maintainer; see config/README.md |

Scripts source `defaults.env` then `project.env`. See **skills/project-setup/SKILL.md** for first-time setup.

### Fully autonomous agent environment (recommended)

For a **fully autonomous** agent (as in the README), install the following in the environment where the agent runs (e.g. WSL, your laptop). One-shot commands: **skills/agent-environment-setup/SKILL.md** section "Full install (all-in-one)".

| What | Purpose |
|------|---------|
| **project-setup** | Run first: creates `config/project.env` (user, password, WiFi, CP IP, datastore). See `skills/project-setup/SKILL.md`. |
| **sshpass** | Password-based SSH before keys are deployed; used by skills and `deploy-keys-to-nodes.sh`. |
| **nmap** | Network scan to find nodes (`K3S_SCAN_SUBNET`); worker-setup and discovery. |
| **curl** | K3s install script, health checks; often present. |
| **jq** | Parse `kubectl -o json`, API output; useful for agent logic. |
| **helm** | Install/upgrade stack, ingress, Loki, etc. locally instead of via SSH. |
| **kubectl** | Cluster queries and apply; use with **KUBECONFIG** pointing at the cluster. |
| **KUBECONFIG** | Copy kubeconfig from control plane (replace 127.0.0.1 with `K3S_CP_IP`); see agent-environment-setup §7. |
| **SSH key + config** | Project key (`K3S_SSH_KEY`), `config/nodes`, `./scripts/ssh-config-from-nodes.sh` → `~/.ssh/config`. |
| **Network** | Agent host must reach cluster subnet (SSH to nodes; API at `K3S_CP_IP:6443` if using local kubectl). |

**When making cluster changes** (Helm upgrades, kubectl apply, node labels, etc.), the agent should **use local helm/kubectl if available** (helm and kubectl in PATH, KUBECONFIG set). If not, fall back to SSH to the control plane with `sudo k3s kubectl ...` and `sudo helm ...` (KUBECONFIG=/etc/rancher/k3s/k3s.yaml on the remote).

### Documentation
- **Per-node changelog**: `nodes/<hostname>-<model>.md` — hardware snapshot + full change history
- **Control plane changelog**: `control-plane/<hostname>-<model>.md`
- **Master inventory**: `nodes/roadmap.md` — per-node checklist and current inventory table
- Update both the node's changelog and the roadmap inventory after each deployment.

### Changelog Template
Each node changelog follows this structure:
1. Node Details table (hardware, serial, MACs, IP, role)
2. Hardware Snapshot (CPU, memory, storage, battery, network, sensors)
3. Change History (dated phases: OS install, WiFi, OS prep, hardening, cluster join)
4. Remaining Roadmap
5. Known Limitations (if any)

## Skills Directory

Agent skills live in `skills/`. Each subdirectory contains a `SKILL.md` with step-by-step procedures.

| Skill | Path | When to Use |
|-------|------|-------------|
| Project setup | `skills/project-setup/` | Configure this repo: username, password, SSH key path (config/project.env) |
| Agent environment setup | `skills/agent-environment-setup/` | One-time local setup: SSH keys, config, tools |
| Control plane setup | `skills/control-plane-setup/` | Deploying or rebuilding the K3s server node |
| Ingress (NGINX) | `skills/ingress-nginx-setup/` | Install NGINX Ingress Controller; artifacts in `ingress/` |
| Monitoring (Prometheus/Grafana) | `skills/monitoring-stack-setup/` | kube-prometheus-stack; Grafana at grafana.lan; artifacts in `monitoring/` |
| NFS storage | `storage/README.md` | TrueNAS NFS exports (configs, backups); static PVs/PVCs for pods |
| Worker node setup | `skills/worker-node-setup/` | Adding a new worker to the cluster |
| Laptop hardening | `skills/hardware/laptop/` | WiFi, lid, suspend, battery, fan, display for laptop nodes |
| Laptop hybrid | `skills/hardware/laptop-hybrid/` | Daily-driver laptop as part-time node; non-Debian distros (Fedora, Arch, etc.) |
| Desktop setup | `skills/hardware/desktop/` | WoL, BIOS, wired networking for desktop nodes |
| SBC setup | `skills/hardware/sbc/` | Raspberry Pi, ARM boards, boot media |
| Sanitizing sandbox | `skills/sanitizing-sandbox/` | Pi as USB stick sanitization station (USB SSD boot, wipe workflow) |
| Training mode | `skills/training-mode/` | User wants to learn — switch to non-executing walkthrough |

The worker node skill auto-detects hardware class and dispatches to the appropriate hardware sub-skill.

## Key Cluster Details

| Detail | Where |
|--------|--------|
| K3s URL | `https://${K3S_CP_IP}:${K3S_API_PORT}` (config/defaults.env, project.env) |
| Node token path | config/defaults.env: `K3S_NODE_TOKEN_PATH`; CP hostname: `K3S_CP_HOST` |
| Datastore URL | config/project.env: `K3S_DATASTORE_URL` |
| Node list | config/nodes (hostname IP per line) |
| K3s version | v1.34.5+k3s1 (documented in control-plane changelog) |
| Container runtime | containerd 2.1.5-k3s1 |
| Kernel | 6.12.74+deb13+1-amd64 |
