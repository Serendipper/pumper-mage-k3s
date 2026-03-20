---
name: project-setup
description: One-time configuration of this repo: SSH user, node password, key path, WiFi SSID/PSK, control-plane IP, datastore URL. Creates config/project.env (gitignored) so scripts and skills run autonomously without hardcoded secrets. Run this before agent-environment-setup when setting up the project on a new machine.
---

# Project Setup

Configure the K3s homelab project once per clone/machine. All cluster-related values live under **config/**; scripts and skills source these files so nothing is hardcoded. This skill creates **config/project.env** (gitignored) for secrets and overrides; **config/defaults.env** (committed) holds non-secret defaults; **config/nodes** is maintained by the agent. CP hostname is **K3S_CP_HOST** in config. See `docs/agents.md` "Config Layout" for the full layout.

## When to use

- First time cloning the repo on a new machine
- Changing the node user, password, or SSH key path for this project
- Setting up so the Cursor agent (or any script) can use consistent credentials without hardcoding them in skills

## 1. Create project config

**Option A — Interactive (first time)**

From the repo root, run the setup script. It prompts for each value; press Enter to accept the default (in brackets).

```bash
./scripts/setup-project.sh
```

Defaults come from **config/defaults.env** when present. Prompts: SSH user, key path, known_hosts path, node password (optional; hidden), Wi‑Fi SSID, Wi‑Fi PSK (optional; hidden), control-plane IP, datastore URL (optional). If `config/project.env` already exists, the script asks before overwriting. When done, go to **Next step** (section 4).

**Option B — Manual (copy and edit)**

From the repo root:

```bash
cp config/project.env.example config/project.env
```

Edit `config/project.env` and set at least:

| Variable | Purpose | Example |
|----------|---------|--------|
| `K3S_SSH_USER` | SSH user on all nodes | `serendipper` (placeholder; set your user in project.env) |
| `K3S_SSH_KEY` | Path to project SSH private key | `~/.ssh/k3s_ed25519` |
| `K3S_SSH_KNOWN_HOSTS` | known_hosts file (for agent context) | `~/.ssh/known_hosts` |
| `K3S_NODE_PASSWORD` | Node login + sudo password (for sshpass / sudo -S) | Required for autonomous setup |
| `K3S_WIFI_SSID` | Wi‑Fi network name for nodes (first-boot, wpa_supplicant) | Set in config/defaults.env or project.env |
| `K3S_WIFI_PSK` | Wi‑Fi password for nodes | Set in config/project.env (required for first-boot and laptop WiFi) |
| `K3S_CP_IP` | Control plane IP (join URL, jump host) | Set in config/defaults.env or project.env |
| `K3S_DATASTORE_URL` | PostgreSQL connection string (control plane only) | `postgres://user:pass@host:port/k3s` |

Paths like `~/.ssh/k3s_ed25519` are expanded by the shell when scripts source the file; ensure the key path exists after running **agent-environment-setup** (or point to an existing key). The interactive script sets `chmod 600` for you.

## 2. Restrict permissions (manual only)

If you created the file manually (Option B), restrict permissions:

```bash
chmod 600 config/project.env
```

## 3. What uses this config

- **scripts/ssh-node.sh** — reads **config/nodes** (hostname IP per line); sources **config/defaults.env** then **config/project.env** for key/user/known_hosts.
- **scripts/ssh-config-from-nodes.sh** — prints SSH config from config/nodes for appending to ~/.ssh/config.
- **scripts/deploy-keys-to-nodes.sh** — deploys key to all hosts in config/nodes using config/project.env.
- **skills/agent-environment-setup** — deploy keys using `K3S_NODE_PASSWORD`, `K3S_SSH_USER`, `K3S_SSH_KEY`.
- **skills/worker-node-setup** — SSH, jump host, and join URL use `K3S_NODE_PASSWORD`, `K3S_SSH_USER`, `K3S_CP_IP`.
- **skills/control-plane-setup** — PostgreSQL and K3s config use `K3S_DATASTORE_URL`.
- **skills/hardware/laptop** — WiFi uses `K3S_WIFI_SSID`, `K3S_WIFI_PSK`.

Environment variables still override: e.g. `K3S_SSH_USER=other ./scripts/ssh-node.sh dalaran hostname`.

### Generated files from project config

- **Pi first-boot network:** Run `./scripts/render-pi-firstboot-network.sh` to generate `config/generated/pi-firstboot-network.yaml` from `K3S_WIFI_SSID` and `K3S_WIFI_PSK`. Use that file as cloud-init `network-config` when preconfiguring Pi first-boot (see `skills/sanitizing-sandbox/SKILL.md` § Pi OS image and staging). Regenerate after changing WiFi in `config/project.env`.

## 4. Next step

Run **agent-environment-setup** to generate the project SSH key (if needed), install sshpass/nmap, and configure SSH config. When that skill tells you to deploy keys with sshpass, use:

```bash
source config/project.env
sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@<ip>" "mkdir -p ~/.ssh ..."
```

(If `K3S_NODE_PASSWORD` is empty, set it in `config/project.env` or pass the password explicitly.)

## Conventions (reference)

Default values match **docs/agents.md**:

- User: from `K3S_SSH_USER` in config (e.g. serendipper as placeholder; set your user in project.env), password: per your OS install (set in `K3S_NODE_PASSWORD`)
- SSH key: `~/.ssh/k3s_ed25519` (comment `k3s-homelab`)
- Wi‑Fi: `K3S_WIFI_SSID` and `K3S_WIFI_PSK` in config (defaults.env / project.env)
