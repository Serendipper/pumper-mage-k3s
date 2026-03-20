# K3s Homelab — Agent runbook (canonical)

Procedures and conventions for agents working in this repository. **System layout and design** live in [`docs/architecture.md`](architecture.md). **What is deployed and current policy** live in [`docs/state.md`](state.md).

## What this is

A K3s cluster on repurposed hardware (laptops, desktops, SBCs) with config-driven automation and skill-based procedures.

## Conventions

### OS

- Debian stable (headless).
- SSH server + standard utilities.
- Credentials from `config/defaults.env` + `config/project.env`.

### Hostnames

- Kirin Tor naming — see `README.md`.
- Primary control plane name: `dalaran`.

### Network

- WiFi SSID/PSK only in config files.
- Do not bake ad hoc LAN IPs into committed scripts; use `config/nodes` and env-driven values (see `docs/architecture.md`).

## SSH access

- From agent context: `./scripts/ssh-node.sh <hostname> '<command>'` so SSH behavior is stable across environments.

## Sync / rsync

- The word “sync” does **not** imply rsync.
- Run rsync only when the user explicitly asks.
- When rsync to framework12 is explicitly requested, do **not** use `--delete`.

## Config layout

| Path | Role |
|------|------|
| `config/defaults.env` | Non-secret defaults |
| `config/project.env` | Secrets / overrides (gitignored) |
| `config/nodes` | Hostname ↔ IP (gitignored) |
| `config/helm-values/` | Live Helm values (gitignored) |

## Node / IP discovery

Use `kubectl get nodes -o wide` for current internal IPs, then reconcile `config/nodes`.

## Skill routing

- `skills/control-plane-setup/SKILL.md`
- `skills/worker-node-setup/SKILL.md`
- `skills/hardware/*/SKILL.md`
- `skills/ingress-nginx-setup/SKILL.md`
- `skills/monitoring-stack-setup/SKILL.md`
- `skills/training-mode/SKILL.md`

Pi workers: `scripts/runbook-worker-pi.md`.

## Documentation rules

- Update `nodes/<hostname>-<model>.md` after deployment changes.
- Update inventory in `nodes/roadmap.md`.
- Keep `config/nodes` aligned with the cluster.
- Canonical docs under `docs/`: `agents.md`, `architecture.md`, `skills.md`, `state.md`.

**Per-node changelog structure**

1. Node details (hardware, serial, MACs, IP, role)
2. Hardware snapshot (CPU, memory, storage, battery, network, sensors)
3. Change history (dated phases: OS install, WiFi, OS prep, hardening, cluster join)
4. Remaining roadmap
5. Known limitations (if any)

When charts, paths, or procedures move, also update `charts/README.md`, `config/README.md`, `monitoring/README.md`, and `README.md` per the documentation audit list in those files.

## Agent guardrails

- Do not run destructive git commands (filter-repo, force-push to shared branches, etc.) unless the user explicitly requests them.
- Respect migrated workload state; do not reset app data or swap volumes to “fix” networking without explicit approval (see `docs/state.md`).
