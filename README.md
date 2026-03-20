# K3s Homelab on Junk Drawer Hardware

*A [Kirin Tor](https://wowpedia.fandom.com/wiki/Kirin_Tor)-themed K3s cluster — because every mage council needs a tower, even if it's built from laptops.*

A fully autonomous K3s Kubernetes cluster built on whatever laptops, desktops, and single-board computers you have lying around. Plug it in, point an AI agent at it, and walk away.

## The Idea

Most homelab guides assume you're buying Raspberry Pis or rack servers. This project assumes you're raiding the closet — that 2012 MacBook with the bad battery, the ThinkPad from college, the Dell Optiplex from a corporate surplus sale. All of it becomes a Kubernetes cluster.

An AI coding agent (Cursor, Copilot, Windsurf, etc.) reads the runbook in this repo and handles the entire setup: OS prep, hardware detection, driver installation, power management, cluster join, and documentation. You install Debian, plug in ethernet, and hand off the IP address.

Every node is named after a mage of the [Kirin Tor](https://wowpedia.fandom.com/wiki/Kirin_Tor), the ruling mage order of Dalaran from World of Warcraft. The control plane is the city itself; the workers are its mages. See [Naming Convention](#naming-convention) below.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐
│  Control Plane  │◄────│  External DB     │
│  (desktop, wired)│     │  (PostgreSQL)    │
└────────┬────────┘     └──────────────────┘
         │
         │  K3s join token
         │
    ┌────┴────┬──────────┐
    │         │          │
 ┌──▼──┐  ┌──▼──┐  ┌────▼──┐
 │ old │  │ old │  │ old  │
 │laptop│  │ SBC │  │desktop│
 └─────┘  └─────┘  └──────┘
```

- **K3s** — lightweight Kubernetes, runs on anything with 512MB+ RAM
- **External PostgreSQL** — cluster state lives on a NAS, not the control plane
- **Flannel** — default CNI, works out of the box
- **Debian stable** — headless, minimal, same OS on every node

## What Hardware Works

Tested on:

| Machine | CPU | RAM | Role |
|---------|-----|-----|------|
| Dell Optiplex 3080 SFF | i5-10505 (6C/12T) | 16 GB | Control plane |
| MacBook Pro A1278 (2012) | i7-3520M (2C/4T) | 16 GB | Worker |
| Lenovo ThinkPad S3-S440 | i5-4210U (2C/4T) | 8 GB | Worker |
| Dell Latitude E5570 | i5-6200U (2C/4T) | 32 GB | Worker |
| Lenovo IdeaPad Z510 | i7-4700MQ (4C/8T) | 16 GB | Worker |
| Lenovo ThinkPad T480s | i5-8350U (4C/8T) | 24 GB | Worker |
| Raspberry Pi 5 | Cortex-A76 (4C/4T) | 8 GB | Worker |

Should also work on: Raspberry Pi 3/4, other ARM SBCs, any x86 machine that runs Debian.

## Repo Structure

```
├── AGENTS.md                        # Agent runbook — project context, conventions, credentials
├── config/                          # defaults.env, project.env.example; project.env & nodes (gitignored)
├── skills/
│   ├── control-plane-setup/         # Deploy the K3s server node
│   ├── worker-node-setup/           # Add a worker (auto-detects hardware class)
│   ├── hardware/
│   │   ├── laptop/                  # WiFi, lid, suspend, battery, fan hardening
│   │   │   └── wifi-drivers.md      # Broadcom/Intel/Realtek driver reference
│   │   ├── desktop/                 # Wake-on-LAN, BIOS, wired networking
│   │   └── sbc/                     # Raspberry Pi, ARM, boot media, low-RAM tuning
│   ├── ingress-nginx-setup/         # NGINX Ingress Controller (Helm)
│   ├── monitoring-stack-setup/      # Prometheus + Grafana (kube-prometheus-stack)
│   └── training-mode/               # Non-executing walkthrough for learning
├── ingress/                          # Ingress manifests + Helm values **templates**; live: config/helm-values/ingress-nginx.yaml
├── monitoring/                       # kube-prometheus-stack, Loki, Promtail values **templates**; live: config/helm-values/*.yaml
├── storage/                          # NFS storage notes + PV/PVC (TrueNAS exports); see storage/README.md
├── control-plane/
│   └── dalaran-3080sff.md          # Control plane hardware + change history
├── nodes/
│   ├── roadmap.md                   # Per-node checklist + cluster inventory
│   ├── aegwynn-a1278.md            # Worker changelogs (hostname-model)
│   ├── jaina-t480s.md
│   ├── modera-rpi5.md
│   └── ...                          # (antonidas, khadgar, rhonin, etc.)
└── charts/                          # homelab-showcase + pihole (see charts/README.md); live values in config/helm-values/
```

## Quick Start

### 1. Set up the control plane

Install Debian stable on a desktop (wired ethernet). Have an external PostgreSQL instance available (TrueNAS, a VM, Docker, whatever). Then tell your agent:

> "Set up the control plane on &lt;IP&gt;"

The agent reads `skills/control-plane-setup/SKILL.md` and handles OS prep, K3s server install, and datastore configuration.

### 2. Add worker nodes

Install Debian stable on a laptop/desktop/Pi. Plug in ethernet temporarily (just for the initial SSH). Then:

> "Set up khadgar at &lt;IP&gt; — it's a Lenovo IdeaPad Z510"

The agent reads `skills/worker-node-setup/SKILL.md`, detects the hardware class, dispatches to the right hardware sub-skill, joins the cluster, and writes the documentation.

### 3. Training mode

If you want to learn instead of having the agent do it:

> "Training mode — walk me through adding a worker node"

The agent switches to a non-executing mode: it explains every step, shows the commands, and waits for you to run them and paste the output.

## Agent Compatibility

This repo uses the `AGENTS.md` + `SKILL.md` open standard. It works with any AI coding agent that reads markdown context from the repo:

- **Cursor** — optional `.cursor/rules/*.mdc` in your working copy (gitignored); same content can point at `AGENTS.md` and `skills/`
- **GitHub Copilot** — reads `AGENTS.md` from repo root
- **Other agents** — point them at `AGENTS.md` and the `skills/` directory

## Laptop Considerations

Laptops make surprisingly good homelab nodes, but they need hardening:

- **Lid close** — must be set to "ignore" or the node drops from the cluster
- **Suspend/hibernate** — masked entirely
- **WiFi drivers** — Broadcom, Intel, Realtek all have different firmware packages
- **Battery** — charge thresholds via TLP prevent permanent-plug-in degradation (vendor-dependent)
- **Fan control** — some hardware exposes fan interfaces (MacBook, some ThinkPads), most don't
- **Display** — turned off via systemd service, saves power and backlight

All of this is automated in `skills/hardware/laptop/SKILL.md`.

## Naming Convention

All hostnames follow the [Kirin Tor](https://wowpedia.fandom.com/wiki/Kirin_Tor) — the council of archmagi that governs the floating city of Dalaran in World of Warcraft lore.

### Control Plane — Cities and Strongholds

The control plane is the seat of power. Name it after Dalaran itself, or its bases of operations through history.

| Hostname | What It Is | Use For |
|----------|-----------|---------|
| `dalaran` | The floating city of mages, capital of the Kirin Tor | **Primary control plane** |
| `violet-citadel` | The central tower of Dalaran, seat of the Council of Six | Secondary CP (HA) |
| `karazhan` | Medivh's tower, nexus of ley lines, ancient seat of the Guardian | Secondary CP (HA) |
| `violet-hold` | Dalaran's arcane prison | Secondary CP (HA) |
| `amber-ledge` | Kirin Tor outpost in Northrend (Borean Tundra) | Secondary CP (HA) |
| `violet-stand` | Forward base in Crystalsong Forest, beneath Dalaran | Secondary CP (HA) |
| `kirin-var` | Kirin Tor village in Netherstorm (Outland) | Secondary CP (HA) |

For a single control plane, use `dalaran`. If you build an HA setup with multiple control plane nodes, expand to the other strongholds in order of lore significance.

### Worker Nodes — Mages of the Kirin Tor

Workers are the mages who serve the council. Named after [members of the Kirin Tor](https://wowpedia.fandom.com/wiki/List_of_Kirin_Tor_mages), prioritized by lore significance.

#### Tier 1 — Leaders and Legends (use these first)

| Hostname | Who They Are | Lore Significance |
|----------|-------------|-------------------|
| `khadgar` | Current leader of the Council of Six, Archmage of Dalaran | The most powerful living mage; led the Kirin Tor through the Legion invasion |
| `antonidas` | Former leader of the Kirin Tor during the Second and Third Wars | Grand master who mentored Jaina; killed defending Dalaran from Arthas |
| `aegwynn` | Guardian of Tirisfal, Magna, Matriarch of Tirisfal | The most powerful Guardian in history; mother of Medivh |
| `medivh` | The Last Guardian of Tirisfal | Opened the Dark Portal; his fall and redemption shaped Azeroth's history |
| `jaina` | Jaina Proudmoore, former leader of the Kirin Tor | One of the most powerful mages alive; ruler of Dalaran during Mists/WoD eras |
| `rhonin` | Leader of the Kirin Tor, hero of the Nexus War | Sacrificed himself at Theramore to save the Alliance; Vereesa's husband |

#### Tier 2 — Council of Six and Senior Archmagi

| Hostname | Who They Are |
|----------|-------------|
| `kalecgos` | Blue dragon aspect in human form; Council of Six member |
| `modera` | Long-serving Council of Six member; one of the most enduring archmagi |
| `karlain` | Council of Six member |
| `vargoth` | Council of Six member; former master of Kirin'Var Village |
| `ansirem` | Archmage Ansirem Runeweaver; Council of Six member |
| `krasus` | Korialstrasz — a red dragon who served on the Council of Six in disguise |
| `aethas` | Leader of the Sunreavers; former Council member, expelled and later readmitted |
| `drenden` | Former Council of Six member |

#### Tier 3 — Notable Mages (when you run out of legends)

| Hostname | Who They Are |
|----------|-------------|
| `guzbah` | Scholar of demon lore; Khadgar's instructor |
| `ravandwyr` | Vargoth's apprentice; member of the Tirisgarde |
| `elandra` | Archmage who assisted Jaina in the Frozen Halls |
| `norlan` | Chief Artificer of the Kirin Tor |
| `sathera` | Friend of Antonidas; killed defending Dalaran from death knights |
| `kinndy` | Kinndy Sparkshine, Jaina's apprentice; killed at Theramore |

#### Avoid These (former members who betrayed the Kirin Tor)

| Name | Why Not |
|------|---------|
| `kel-thuzad` | Founded the Cult of the Damned, became a lich |
| `arugal` | Unleashed the worgen curse |
| `kael-thas` | Betrayed everyone, joined the Burning Legion |

*Full list: [List of Kirin Tor mages](https://wowpedia.fandom.com/wiki/List_of_Kirin_Tor_mages)*

## What's Not Included (Yet)

- Workload deployment (this repo is infrastructure only)
- **ServiceLB** (K3s built-in) — provides `type: LoadBalancer` for Services. Disabled here; HTTP(S) goes through NGINX Ingress (`ingress/`, `skills/ingress-nginx-setup/`). To expose raw TCP/UDP or use LoadBalancer services, re-enable by omitting `servicelb` from the `--disable` list in `skills/control-plane-setup/`.
- Storage provisioner beyond local-path — NFS exports on TrueNAS for configs/backups; see `storage/README.md`. Use static PVs/PVCs to mount them in pods.
- **Monitoring** — deployed via kube-prometheus-stack (Prometheus, Grafana, Alertmanager, node-exporter). Grafana: http://grafana.lan (login `admin` / password in values or from secret). See `monitoring/` and `skills/monitoring-stack-setup/`.
- Multi-control-plane HA

## Contributing

Found a hardware quirk? Set up a node type we haven't covered? PRs welcome — especially for:
- New WiFi chipset entries in `skills/hardware/laptop/wifi-drivers.md`
- SBC-specific boot and driver notes
- Fan control on hardware we haven't tested
- Battery threshold support for new vendors

## License

MIT
