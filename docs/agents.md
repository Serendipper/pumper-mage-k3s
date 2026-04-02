# K3s Homelab — Agent runbook (canonical)

Procedures and conventions for agents working in this repository. **System layout and design** live in [`docs/architecture.md`](architecture.md). **What is deployed and current policy** live in [`docs/state.md`](state.md).

## What this is

A K3s cluster on repurposed hardware (laptops, desktops, SBCs) with config-driven automation and skill-based procedures. The **subject of this repository** is the **cluster and its LAN integrations** (ingress, storage, monitoring, DNS names), not any single personal workstation.

**Operators** (people maintaining the homelab) use whatever machine they have — a maintenance laptop, a desktop with `kubectl`, a browser for UIs — for DNS checks, Pi-hole, `kubectl`/`helm`, optional SSH to hosts **they** administer, and TrueNAS UI or **human** SSH to the NAS when needed. That is normal and expected.

**Agents** (Cursor automation following this repo) are different: they use **`ssh-node.sh`** only for **cluster nodes and hosts listed in `config/nodes` for that purpose**, and **do not** automate SSH to TrueNAS (see **TrueNAS — never SSH** below). Do not conflate “someone on the LAN fixed DNS / used SSH to the NAS” with “the agent should do the same.”

## Agent role (implementation vs. narration)

- **Deliverable:** changes in **this repository** (charts, Kustomize, scripts, docs) and, where rules and access allow, **commands run** toward the cluster or nodes. The point is not to produce a tutorial for the project owner to execute in place of that work.
- **Responses:** after implementing something, summarize **what changed in git**, **why**, and any **hard boundary** (e.g. live Helm values gitignored, kubeconfig only on an operator machine)—**without** closing with second-person homework (“what you do”, numbered “you apply / you edit”) as if that were the outcome. Neutral operational detail belongs in **`docs/`** and chart READMEs, not as a substitute for committed changes.
- **In-repo READMEs** may use imperative steps for **any** operator cloning the repo; that is not the same as the agent **delegating** cluster steps back to the user after a task.

## Conventions

### Secrets and scanning

- Do not commit **`config/project.env`**, **`config/nodes`**, or **`config/helm-values/`** — they are gitignored.
- Before pushing sensitive edits, run **`pre-commit run --all-files`** (see **`docs/security-hygiene.md`**) so **Gitleaks** can catch accidental secrets.

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

### LAN DNS / Pi-hole (when “name doesn’t resolve” on an operator machine)

- **`dig @<pihole-ip> name`** only proves Pi-hole answers if queried directly. It does **not** prove the workstation’s normal resolver path uses Pi-hole.
- To test **this machine’s** DNS path, use **`dig name`** (no `@`) and **`getent hosts name`** (goes through **systemd-resolved** / stub on typical Fedora setups).
- If Pi-hole is correct (kubectl/Helm, or `dig @pihole` OK) but **default** lookup fails or is stale: **action first** — **`resolvectl flush-caches`**, then cycle the active connection (**`nmcli connection down <name> && nmcli connection up <name>`** on the Wi‑Fi/Ethernet profile; **`sudo`** may be required in some sessions). Re-check with **`dig name`** / **`getent`**. Avoid long DNS theory before that.
- **Do not** claim “no client renew needed” after Pi-hole edits. The **server** may be fine while **this machine’s** resolver stack still has **stale routes or cache**; a **connection cycle** (DHCP renew) plus **flush** has fixed real cases where default `dig` was wrong despite Pi-hole being correct.

#### Operator workstation — Wi‑Fi DHCP renew (this machine, Fedora / NetworkManager)

When the user asks to **renew DHCP** or **bounce Wi‑Fi** and expects the link to **drop and reconnect**, run **only** this (no `reapply` / no alternate flows unless they ask). **Do not** hardcode Wi‑Fi profile names or SSIDs in commands you paste into the repo — resolve the active Wi‑Fi **connection** name at runtime:

```bash
WF=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1;exit}')
nmcli connection down "$WF" && nmcli connection up "$WF"
```

- **Do not** substitute `nmcli device reapply` on the wireless interface for this request; that does not do the same full down/up cycle.
- If activation warns about missing PSK, NetworkManager usually still reconnects from saved secrets; if it fails, run **`nmcli connection up "$WF" --ask`** in a real terminal (requires a TTY).

## SSH access

### TrueNAS — never SSH

**Never** open an SSH session to TrueNAS from agent automation — not **`ssh-node.sh`**, not **`ssh`**, not **`sshpass`**. TrueNAS is a storage appliance, not a cluster node. Do not put **`truenas`** in **`config/nodes`**. LAN address / DNS: Pi-hole and **`docs/state.md`**.

### Cluster nodes and operator hosts

- From agent context: **`./scripts/ssh-node.sh <hostname> '<command>'`** (run from repo root). The script sources **`config/defaults.env`** then **`config/project.env`**, so key path and **`K3S_SSH_USER`** match this machine — including the override in gitignored **`project.env`**.
- **`config/defaults.env`** uses **`serendipper`** only as a **placeholder** for fresh clones. Do **not** assume that username when hand-writing `ssh user@IP`; use **`ssh-node.sh`** or set **`K3S_SSH_USER`** explicitly.

### Non-interactive remote access (read this before any `ssh` to a node)

The agent has **no TTY**: it cannot type an SSH password or a **sudo** password on the remote. **`ssh-node.sh`** is for **key-based** sessions.

- **Password SSH to a node:** use **`sshpass -p "$K3S_NODE_PASSWORD"`** (from **`config/project.env`** after `set -a` / `source`).
- **Remote command needs `sudo`:** same SSH session must still be non-interactive — use **`echo "$K3S_NODE_PASSWORD" | sudo -S <cmd>`** on the **remote** side (project convention: login password = sudo password on nodes). **Do not** run plain **`ssh … 'sudo …'`** and expect it to work from Cursor.
- **Pattern:** `sshpass -p "$K3S_NODE_PASSWORD" ssh … "echo \"$K3S_NODE_PASSWORD\" | sudo -S …"` — see examples below.

Do not hand-wave with “run this on the node” when the agent can run it with **`sshpass`** + **`sudo -S`** per this section.

### Password SSH and non-interactive `sudo` on nodes

When keys are not deployed yet (or you need password SSH), use **`sshpass`** with **`K3S_NODE_PASSWORD`** from **`config/project.env`** (see **`skills/agent-environment-setup/SKILL.md`**, **`scripts/runbook-worker-pi.md`**). Example:

```bash
set -a && source config/defaults.env 2>/dev/null; source config/project.env && set +a
sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "${K3S_SSH_USER}@${IP}" 'echo OK'
```

For **remote** commands that need **`sudo`** without a TTY, pipe the same password (**project convention:** login user password = sudo password on nodes):

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "${K3S_SSH_USER}@${IP}" "echo \"$K3S_NODE_PASSWORD\" | sudo -S some-command"
```

### Local `sudo` from the agent (Cursor / non-interactive host)

Commands the agent runs on **this** workstation may still fail with *“a terminal is required to read the password”* if they use **`sudo`** and your account is not passwordless-sudo. That is separate from cluster nodes: **do not assume** the agent can wipe disks or run **`mkfs`** locally without you running the command in a real terminal — or use **`sshpass`** + **`sudo -S`** only when the target is a **remote** host you can reach with **`K3S_NODE_PASSWORD`** as above.

## Sync / rsync

- The word “sync” does **not** imply rsync.
- Run rsync only when the user explicitly asks.
- When rsync to a **named maintenance / operator machine** is explicitly requested, do **not** use `--delete`.

## Config layout

| Path | Role |
|------|------|
| `config/defaults.env` | Non-secret defaults (incl. **`K3S_CP_API_HOST`** → `dalaran.lan` for local kubeconfig `server:` URL) |
| `config/project.env` | Secrets / overrides (gitignored) |
| `config/nodes` | Hostname ↔ IP for **cluster nodes and operator hosts you SSH to** (gitignored). **Exclude** TrueNAS and other appliances you do not automate over SSH. |
| `config/helm-values/` | Live Helm values (gitignored) |

## Node / IP discovery

Use `kubectl get nodes -o wide` for current internal IPs, then reconcile `config/nodes`.

### Control plane LAN IP

When **dalaran’s** (or the ingress/API host’s) **LAN address** changes, follow **`docs/control-plane-ip-change.md`** (Pi-hole static lines, **`config/nodes`**, kubeconfig, comments).

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

- **Do not SSH to TrueNAS** as part of routine automation; it is not in **`config/nodes`** for that purpose (see **SSH access** above).
- Do not run destructive git commands (filter-repo, force-push to shared branches, etc.) unless the user explicitly requests them.
- Respect migrated workload state; do not reset app data or swap volumes to “fix” networking without explicit approval (see `docs/state.md`).
- **Remote node commands:** the agent cannot use interactive **SSH** or **sudo** passwords. Use **`sshpass`** + **`sudo -S`** per **§ SSH access** — do not repeatedly rediscover this by failing `ssh`/`sudo` from the agent.
