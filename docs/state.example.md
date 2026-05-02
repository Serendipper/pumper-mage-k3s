# Current state (example / template)

**Public repo:** this file is **`docs/state.example.md`**. Copy it to **`docs/state.md`** for your operator-maintained, site-specific state (`docs/state.md` is **gitignored** — see **`.gitignore`**). Do not commit live LAN details, emails, or session UUIDs to a public fork; keep them in local **`docs/state.md`** only.

Last updated: 2026-05-02 (template revision)

## Scope

This file is **operational state + dated lessons**, not a transcript archive. **Chat summaries and coverage** (after **Recent changes / lessons**) can list whether each support thread is reflected in lessons (**Yes** / **Partial** / **No**). **No** means the work was one-off, personal desktop, or never rolled into a dated lesson — not that it did not happen. *(The table below uses placeholder UUID rows; maintain your real index only in local **`docs/state.md`** if desired.)*

## Media migration (TrueNAS → K3s)

**Scope**

- Original migration included Sonarr, Radarr, Plex; **Sonarr and Radarr are decommissioned** from the cluster (workloads + PVs removed; on-disk config under `media-config-import/{sonarr,radarr}` may remain). **Rationale:** those apps are happiest managing libraries and download paths **directly on the NAS** (native paths, permissions, and tooling); wrapping them in Kubernetes/NFS PVCs was an awkward fit compared to running them on TrueNAS, a VM, or another host with real filesystem access to the datasets.
- Skip: Jellyfin, Postgres (Postgres stays out of this migration; cluster DB usage unchanged)

**Status**

- Plex: running in `media` namespace; **config on local hostPath on dalaran** (SQLite-safe); **media library** (and any paths you add) over **NFS** to TrueNAS. In practice Plex is **read-heavy** on library content, which sits well with an NFS mount; it is not the same workload as downloaders/indexers that rename, move, and hardlink all day on the dataset.

**Manifests & paths**

- Workloads: `deploy/kustomize/base/storage/media-apps.yaml` (apply via **`kubectl apply -k deploy/kustomize/base`** or **`./scripts/apply-cluster-manifests.sh`**).
- NFS export / mount patterns (not the live PV YAML): **`storage/README.md`**.
- **Config PVs:** `hostPath` → `/home/serendipper/media-config-import/plex` on **dalaran** in **committed** Kustomize (**placeholder** user; live `hostPath` on the node may differ — **`docs/agents.md`**, *Placeholders vs live paths*). Imported via rsync from TrueNAS; private runbook `scripts/private-truenas/TRUENAS_PUSH_CONFIG_TO_DALARAN.md`. Legacy Sonarr/Radarr dirs are optional leftovers.
- **NFS:** `pv-media-library` / `media-library` → Plex `/data` (read-mostly). `pv-media-downloads` / `media-downloads` still defined in the namespace (leftover from when *arr ran here); Plex does not mount it.

**Access (as of last check)**

- **Ingress (port 80):** `http://dalaran.plex`, `http://dalaran.sonarr`, `http://dalaran.radarr`, `http://grafana.lan`, … — Pi-hole **`address=`** lines for these **ingress hostnames** should point at **modera** (HAProxy on **:80** / **:443**), which balances to **nginx** (`hostNetwork`) on each **control-plane** node; nginx routes by `Host` to Plex in-cluster or to Sonarr/Radarr on TrueNAS via Service+Endpoints (`deploy/kustomize/base/storage/plex-ingress-dalaran.yaml`, `deploy/kustomize/base/storage/truenas-arr-external-services.yaml`). **`dalaran`** / **`dalaran.lan`** in DNS stay the **real** control-plane IP (API/SSH identity), not the browser entry IP for those apps. Apply **`./scripts/apply-haproxy-ingress-lb.sh`** when CP LAN IPs used as HAProxy backends change. **Direct NAS** (SMB/UI): `truenas` / `truenas.lan` → NAS LAN IP in Pi-hole static DNS (live **`config/helm-values/pihole.yaml`** or chart values); **not** in **`config/nodes`** — TrueNAS is not an SSH target for agents (**`docs/agents.md`**). Canonical local source for NAS IP: `config/helm-values/pihole.yaml` `customDnsmasqLines` (`address=/truenas/...` and `address=/truenas.lan/...`).
- **TrueNAS *arr ports:** `deploy/kustomize/base/storage/truenas-arr-external-services.yaml` defaults to **30113** / **30025** (old K3s hostNetwork ports). If TrueNAS publishes different ports, edit Endpoints + Service port + Ingress backend there.
- **OpenClaw (off-cluster):** `http://openclaw.dalaran.lan` — nginx Ingress on dalaran reverse-proxies to the **OpenClaw backend host** (LAN IP + port in `deploy/kustomize/base/storage/openclaw-external-gateway.yaml`; placeholder in-repo). Allow the ingress path on that host’s firewall (see `openclaw/docs/reverse-proxy-k3s.md`). Token auth on the gateway still applies.
- Direct node port (if needed): `http://<control-plane-LAN-IP>:32400` (Plex), etc. Reconcile with **`config/nodes`** (gitignored).
- Ingress/TLS experiments are separate from config migration; do not drop persistent `/config` to fix URL or cert UX.

## Operational practices

- Prefer **local** `kubectl` / `helm` from a machine with `KUBECONFIG` set; use SSH to the control plane only as a fallback. Kubeconfig should point the API at **`https://dalaran.lan:6443`** ( **`K3S_CP_API_HOST`** in **config/defaults.env**); see **skills/agent-environment-setup**. **HTTP** ingress for LAN names is documented as **HAProxy on modera → nginx on each control-plane node** — **`ingress/README.md`**, **`scripts/apply-haproxy-ingress-lb.sh`**.
- **Worker LAN (2026-03):** Laptops use **Ethernet as primary**; **Wi‑Fi remains configured** as backup. **`kubectl get nodes -o wide`** INTERNAL-IP should track the primary interface; if a node falls back to Wi‑Fi, reconcile **`config/nodes`** and per-node changelogs with the live address.
- **Control plane LAN IP changes:** **`docs/control-plane-ip-change.md`** (Pi-hole static `address=` lines for **`dalaran`**, **`dalaran.lan`**, and ingress names; **`config/nodes`**, kubeconfig).
- **“Sync”** does not mean rsync; only run rsync when explicitly requested (and without `--delete` to a named maintenance host per project rules).
- **GitOps:** First-party cluster YAML (Kustomize under **`deploy/kustomize/base/`**, including optional Grafana dashboard JSON in **`deploy/kustomize/base/monitoring/`**) is the source of truth in git. **Any** live change via **`kubectl`** / **`helm`** must be reflected in committed docs and/or manifests (**`docs/agents.md`** — *Cluster changes: commit sources and document applies*). Live Helm values stay in gitignored **`config/helm-values/`** but follow committed templates under **`monitoring/`**, **`ingress/`**, **`charts/`**, etc. (**`config/README.md`**). **Site-specific PVs and LAN IP patches** that must not be published: gitignored **`deploy/kustomize/live/private/`** overlay (**`docs/kustomize-live.md`**); new clones run **`./scripts/init-kustomize-live.sh`** then edit **`private/*.yaml`**; **`./scripts/apply-cluster-manifests.sh`** applies **`deploy/kustomize/live`** when **`private/media-pvs.yaml`** and **`private/site.yaml`** both exist; otherwise **`deploy/kustomize/base`** only.
- **Monitoring:** Prometheus + Grafana (**kube-prometheus-stack**), typically Loki + Promtail when installed; Grafana at **`grafana.lan`**. Optional **send-only** Postfix **`smtp-relay`** in **`monitoring`** (Kustomize: **`deploy/kustomize/base/monitoring/smtp-relay.yaml`**) for outbound mail; configure **`smtp-relay-config`** + Secret **`smtp-relay-upstream`**, then point Grafana at **`smtp-relay.monitoring.svc.cluster.local:587`** per **`monitoring/README.md`**. Procedures: **`monitoring/README.md`**, **`skills/monitoring-stack-setup/SKILL.md`**. Dashboards and datasources may be provisioned by Helm **or** checked-in under **`deploy/kustomize/base/monitoring/`** (Grafana sidecar label **`grafana_dashboard: "1"`**).
- **TLS / cert-manager:** The default Kustomize base may include **Let’s Encrypt staging** issuers / OpenClaw **staging** certificates (**`deploy/kustomize/base/cert-manager/`**); production TLS and LAN trust are still an open design item (see **Open items**).

## Cluster snapshot (verify with live API; not a substitute for `kubectl` / `helm`)

**Example snapshot shape** (replace with **`kubectl` / `helm list`** from your cluster; do not commit real INTERNAL-IP rows to a public fork): **Helm** — `ingress-nginx`, `pihole`, `prometheus-stack`, `loki`, `promtail`. **Ingress** — `grafana.lan`, `*.plex`, OpenClaw hostname, demo app. **Pi-hole** on your DNS node. **Workers** — reconcile **`kubectl get nodes -o wide`** with **`config/nodes`** (gitignored) and optional per-node notes under **`nodes/`** (gitignored). **Monitoring** pods are often spread across nodes — **`kubectl get pods -n monitoring -o wide`**.

## Recent changes / lessons

- **2026-05-02 (session review — docs only):** Consolidated chat-session outcomes into this file: HA ingress path (HAProxy + multi-CP nginx), live Kustomize overlay, Apr–May node upgrades/NIC incident, secondary CP (**violet-citadel**) bring-up context.
- **2026-04-28 — 2026-05 (HA HTTP front door + publishable base):**
  - **Ingress:** nginx **DaemonSet** on **all** control-plane nodes (chart template **`ingress/helm-values-hostnetwork.yaml`** → live **`config/helm-values/ingress-nginx.yaml`**); **HAProxy** on **modera** fronts **:80** / **:443** to those nodes; **`K3S_CP2_HOST`** (default **`violet-citadel`**) in **`config/defaults.env`** for HAProxy backends. Run **`./scripts/apply-haproxy-ingress-lb.sh`** after ingress/Pi-hole Helm changes or CP IP changes.
  - **Pi-hole chart:** **`webServerPort: 8080`** so HAProxy can own **:80** on modera; **`customDnsmasqLines`** in committed template point ingress names at **modera**’s IP (see **`charts/homelab-showcase/charts/pihole/README.md`**).
  - **Monitoring:** Plex blackbox probe targets the **HAProxy** entry (same path browsers use), not the raw CP IP — **`deploy/kustomize/base/monitoring/plex-probe.yaml`**.
  - **Kustomize:** **`deploy/kustomize/base`** keeps placeholders / no live PVs; real **`PersistentVolume`** specs and site patches live under **`deploy/kustomize/live/private/`** (gitignored). **`docs/kustomize-live.md`**, **`./scripts/init-kustomize-live.sh`**. “New clones” means **fresh git clones** of this repo — run the init script once, edit **`private/`**, then apply; not required on every pull if **`private/`** already exists.
- **2026-04-29 — 2026-05-01 (nodes):** Rolling **OS/kernel** upgrades on reachable nodes (CVE/kernel motivation); **`config/nodes`** and node notes reconciled with **`kubectl get nodes -o wide`**; **ansirem** was the expected unreachable exception in-session. Post-reboot on **dalaran**, **Ethernet** came up **down** / **no IPv4** (interface naming vs **`eth0`**); fixed with persistent net config — treat as a reminder to verify NIC names after major kernel updates. Similar check on **violet-citadel** (same hardware class). **`linux-image-*` “kept back”** on Debian/Ubuntu usually means a phased or dependency-held kernel metapackage; use **`apt full-upgrade`** / explicit install if you need that specific kernel jump.
- **2026-04-29 (secondary control plane):** Second HA server joined; DHCP reservation on your LAN; onboarding may surface **enp*** / **eth*** naming — align with **`skills/control-plane-setup`** and your primary CP patterns for Ethernet-on-LAN.
- **2026-04-29 (Grafana / HA discussion):** Grafana **SQLite** on a single replica’s storage is **not** safe for multiple replicas; **HA** Grafana generally needs a **shared DB** (e.g. Postgres) or a single replica. Pointing Grafana at an external DB on **TrueNAS** was discussed; not tracked here as completed — confirm live **`config/helm-values/prometheus-stack.yaml`** and pod spec if you proceed.
- **2026-04-26 (storage / control-plane host):** Recurring **dalaran** instability and disk I/O errors documented in **`docs/incidents/2026-04-26-dalaran-control-plane-flap.md`** (mitigated by reboot at the time; root cause not fully confirmed).
- **2026-04-26 (external dalaran outage checker on Clawbot):**
  - Added Clawbot watchdog files in-repo: `scripts/clawbot/check-dalaran.sh`, `scripts/clawbot/clawbot-dalaran-check.service`, and `scripts/clawbot/clawbot-dalaran-check.timer`.
  - Optional external checker on an off-cluster host: hit **`https://<control-plane-IP>:6443/healthz`** directly (no Grafana dependency); responses `200`/`401`/`403` treated as API reachable. Configure **`K3S_CP_HEALTHCHECK_URL`** in **`scripts/clawbot/check-dalaran.sh`** / systemd.
  - Notifications now post straight to OpenClaw hook path `http://127.0.0.1:18789/hooks/agent` using the local OpenClaw hook token, so Discord delivery can continue even when monitoring on `dalaran` is down.
  - Initial `dalaran.lan` target failed on Clawbot DNS resolution; checker now uses control-plane IP to avoid DNS coupling.
- **2026-04-25 (alerts + email hardening):**
  - **Grafana SMTP** via your provider (e.g. Resend) with a domain-authenticated From address (live values in gitignored **`config/helm-values/prometheus-stack.yaml`**; secret **`grafana-smtp`**). Verify with a test notification to an address you control.
  - Added in-repo **Plex blackbox probe** manifests: `deploy/kustomize/base/monitoring/plex-probe.yaml` and wired into `deploy/kustomize/base/kustomization.yaml`. Probe runs from inside cluster via `blackbox-exporter` pinned to **dalaran**, targeting Plex through the dalaran ingress path.
  - Added Grafana-managed alert rules (created via Grafana provisioning API) in folder/group `homelab` / `homelab-probes`, now routed to contact point `openclaw-discord-dm` (OpenClaw webhook):
    - `[CRITICAL] Plex Down (via dalaran probe)` (`probe_success < 1`, for 2m)
    - `[WARNING] Plex Probe Flapping (via dalaran)` (`changes(probe_success[10m]) > 3`, for 5m)
    - `[CRITICAL] Node Temperature > 90C` (filtered `node_hwmon_temp_celsius`, for 5m)
    - `[CRITICAL] Node Temp >90% of Critical` (`temp / temp_crit > 0.9`, for 5m)
  - Node critical temperature telemetry currently reports mixed hardware limits (`node_hwmon_temp_crit_celsius`): mostly 100C, with 105C and 120C on specific nodes; normalized threshold alerts were added to account for this.
  - OpenClaw gateway runs **off-cluster**; document LAN IP in gitignored **`nodes/`** if you use it. Cluster bridge Endpoints (`deploy/kustomize/base/storage/openclaw-external-gateway.yaml`) use **RFC 5737 TEST-NET** in-repo; override with **`deploy/kustomize/live/private/site.yaml`** for real LAN IPs.
  - OpenClaw webhook ingress was enabled on `harmllm` (`hooks.enabled: true`, `hooks.path: /hooks`) with a dedicated hook token (distinct from gateway auth), and Grafana webhook receiver `openclaw-discord-dm` now posts alert payloads to `http://openclaw-gateway.default.svc.cluster.local:18789/hooks/agent` for Discord delivery via your paired DM route.
- **Note:** these alert rules are currently Grafana API-managed state (not yet committed as file-based alert provisioning). Keep this documented until/if they are moved into repo-managed provisioning.
- **2026-04-25:** In-cluster **send-only** Postfix relay **`smtp-relay`** (Deployment/Service/ConfigMap in **`deploy/kustomize/base/monitoring/smtp-relay.yaml`**). Outbound smarthost + Secret **`smtp-relay-upstream`** are still required; see **`monitoring/README.md`**. Merge **`monitoring/helm-values.yaml`** Grafana SMTP changes into gitignored **`config/helm-values/prometheus-stack.yaml`** and **`helm upgrade`**.
- **`krasus`:** Earlier **`wpa_cli`** mis-try **2026-04-04**; **USB Ethernet** recovery; WiFi aligned to **`K3S_WIFI_SSID`** **2026-04-05** (**`skills/hardware/laptop/SKILL.md`** §2 / §2a). **`nodes/krasus-surface-pro-4.md`**.
- A temporary Plex `emptyDir` config was used during troubleshooting and **reverted** — it wipes state and is not a long-term fix.
- Plex `/config` must remain on the persistent PVC for migrated libraries and claims.
- HTTPS / hostname / cert trust are orthogonal to whether migrated `Preferences.xml` and DB paths are intact.

## Chat summaries and coverage (vs Recent changes / lessons)

**Legend:** **Yes** / **Partial** / **No** as in a full `state.md` — see meaning in **Scope** above.

If you use Cursor (or similar) and want a **session-by-session** map to **Recent changes**, maintain the full table only in **local gitignored `docs/state.md`**. Public clones ship this template without real chat UUIDs. Example shape:

| UUID (example) | Summary | In Recent changes / lessons? |
|----------------|---------|----------------------------|
| `00000000-0000-0000-0000-000000000001` | Example: HA ingress / HAProxy work. | **Yes** — dated bullet **2026-04-28 — 2026-05** (if applicable to your fork). |
| `00000000-0000-0000-0000-000000000002` | Example: one-off desktop troubleshooting. | **No** |

## Open items

- Final TLS strategy for trusted HTTPS on LAN (install CA / internal CA vs self-signed acceptance vs HTTP on trusted LAN).
- **kubectl API** on a **single** hostname (**`K3S_CP_API_HOST`**, e.g. **`dalaran.lan`**) does not by itself fail over to the second server if the primary CP is down; for automatic API failover add a **stable endpoint** (VIP, **:6443** load balancer, or break-glass second `server:` in kubeconfig). HTTP HA via HAProxy does not replace this.
- Optional: short runbook for media URLs, ingress names, and rollback.
- Grafana: confirm whether an **external DB** is in use before scaling replicas or assuming HA; SQLite-backed single pod is the common homelab default.
- Periodically reconcile this file with **`helm list -A`**, **`kubectl get ns`**, and **`nodes/roadmap.md`** so “current state” stays accurate (chart upgrades, new workers, retired workloads).

## Guardrails (current policy)

- Preserve migrated app config and data unless the user explicitly asks for a reset or blank install.
- Live Helm values live in `config/helm-values/`; committed YAML in chart dirs are templates only.
- Avoid destructive git operations (e.g. history rewrite) unless explicitly requested.
- Do not leave operational behavior **only** on the cluster: commit first-party manifests and document applies (**`docs/agents.md`**).
