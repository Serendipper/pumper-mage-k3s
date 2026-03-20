# Current state

Last updated: 2026-03-20

## Media migration (TrueNAS → K3s)

**Scope**

- Migrate: Sonarr, Radarr, Plex  
- Skip: Jellyfin, Postgres (Postgres stays out of this migration; cluster DB usage unchanged)

**Status**

- Sonarr: running in `media` namespace.
- Radarr: running in `media` namespace.
- Plex: running in `media` namespace; config on persistent NFS-backed volume (not `emptyDir`).

**Manifests & paths**

- Workloads: `storage/media-apps.yaml`.
- Datasets: NFS static PV/PVC to TrueNAS exports (same layout as prior Docker bind mounts).

**Access (as of last check)**

- Plex: `http://192.168.1.152:32400`, `http://plex.lan:32400` (IPs/hostnames may drift — reconcile with `config/nodes` and live DNS).
- Ingress/TLS experiments are separate from config migration; do not drop persistent `/config` to fix URL or cert UX.

## Operational practices

- Prefer **local** `kubectl` / `helm` from a machine with `KUBECONFIG` set; use SSH to the control plane only as a fallback.
- **“Sync”** does not mean rsync; only run rsync when explicitly requested (and without `--delete` to framework12 per project rules).

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
