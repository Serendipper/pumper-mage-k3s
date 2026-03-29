# Current state

Last updated: 2026-03-28

## Media migration (TrueNAS → K3s)

**Scope**

- Original migration included Sonarr, Radarr, Plex; **Sonarr and Radarr are decommissioned** from the cluster (workloads + PVs removed; on-disk config under `media-config-import/{sonarr,radarr}` may remain). **Rationale:** those apps are happiest managing libraries and download paths **directly on the NAS** (native paths, permissions, and tooling); wrapping them in Kubernetes/NFS PVCs was an awkward fit compared to running them on TrueNAS, a VM, or another host with real filesystem access to the datasets.
- Skip: Jellyfin, Postgres (Postgres stays out of this migration; cluster DB usage unchanged)

**Status**

- Plex: running in `media` namespace; **config on local hostPath on dalaran** (SQLite-safe); **media library** (and any paths you add) over **NFS** to TrueNAS. In practice Plex is **read-heavy** on library content, which sits well with an NFS mount; it is not the same workload as downloaders/indexers that rename, move, and hardlink all day on the dataset.

**Manifests & paths**

- Workloads: `deploy/kustomize/base/storage/media-apps.yaml` (apply via **`kubectl apply -k deploy/kustomize/base`**).
- **Config PVs:** `hostPath` → `/home/serendipper/media-config-import/plex` on **dalaran** (imported via rsync from TrueNAS; private local runbook under `scripts/private-truenas/TRUENAS_PUSH_CONFIG_TO_DALARAN.md`). Legacy Sonarr/Radarr dirs are optional leftovers.
- **NFS:** `pv-media-library` / `media-library` → Plex `/data` (read-mostly). `pv-media-downloads` / `media-downloads` still defined in the namespace (leftover from when *arr ran here); Plex does not mount it.

**Access (as of last check)**

- **Ingress (port 80):** `http://dalaran.plex`, `http://dalaran.sonarr`, `http://dalaran.radarr` — Pi-hole resolves these hosts to the **ingress** IP (control plane); nginx routes by `Host` to Plex in-cluster or to Sonarr/Radarr on TrueNAS via Service+Endpoints (`deploy/kustomize/base/storage/plex-ingress-dalaran.yaml`, `deploy/kustomize/base/storage/truenas-arr-external-services.yaml`). **Direct NAS** (SMB/UI): `truenas` / `truenas.lan` → NAS LAN IP in Pi-hole (see **`config/nodes`** for **truenas**).
- **TrueNAS *arr ports:** `deploy/kustomize/base/storage/truenas-arr-external-services.yaml` defaults to **30113** / **30025** (old K3s hostNetwork ports). If TrueNAS publishes different ports, edit Endpoints + Service port + Ingress backend there.
- **OpenClaw (off-cluster):** `http://openclaw.dalaran.lan` — nginx Ingress on dalaran reverse-proxies to the **OpenClaw backend host** (LAN IP + port in `deploy/kustomize/base/storage/openclaw-external-gateway.yaml`; placeholder in-repo). Allow the ingress path on that host’s firewall (see `openclaw/docs/reverse-proxy-k3s.md`). Token auth on the gateway still applies.
- Direct node port (if needed): `http://192.168.1.6:32400` (Plex), etc. Reconcile with `config/nodes`.
- Ingress/TLS experiments are separate from config migration; do not drop persistent `/config` to fix URL or cert UX.

## Operational practices

- Prefer **local** `kubectl` / `helm` from a machine with `KUBECONFIG` set; use SSH to the control plane only as a fallback. Kubeconfig should point the API at **`https://dalaran.lan:6443`** ( **`K3S_CP_API_HOST`** in **config/defaults.env**); see **skills/agent-environment-setup**.
- **Worker LAN (2026-03):** Laptops use **Ethernet as primary**; **Wi‑Fi remains configured** as backup. **`kubectl get nodes -o wide`** INTERNAL-IP should track the primary interface; if a node falls back to Wi‑Fi, reconcile **`config/nodes`** and per-node changelogs with the live address.
- **Control plane LAN IP changes:** **`docs/control-plane-ip-change.md`** (Pi-hole static `address=` lines for **`dalaran`**, **`dalaran.lan`**, and ingress names; **`config/nodes`**, kubeconfig).
- **“Sync”** does not mean rsync; only run rsync when explicitly requested (and without `--delete` to a named maintenance host per project rules).

## Recent changes / lessons

- A temporary Plex `emptyDir` config was used during troubleshooting and **reverted** — it wipes state and is not a long-term fix.
- Plex `/config` must remain on the persistent PVC for migrated libraries and claims.
- HTTPS / hostname / cert trust are orthogonal to whether migrated `Preferences.xml` and DB paths are intact.

## Open items

- Final TLS strategy for trusted HTTPS on LAN (install CA / internal CA vs self-signed acceptance vs HTTP on trusted LAN).
- Optional: short runbook for media URLs, ingress names, and rollback.

## Guardrails (current policy)

- Preserve migrated app config and data unless the user explicitly asks for a reset or blank install.
- Live Helm values live in `config/helm-values/`; committed YAML in chart dirs are templates only.
- Avoid destructive git operations (e.g. history rewrite) unless explicitly requested.
