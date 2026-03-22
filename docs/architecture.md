# System Architecture

## Topology & configuration sources

- **Control plane:** hostname `dalaran` (see `config/defaults.env` / `K3S_CP_HOST`).
- **Node inventory:** source of truth is `config/nodes` (hostname + IP per line; gitignored, agent-maintained).
- **Datastore:** external PostgreSQL via `K3S_DATASTORE_URL` in `config/project.env` — not in-cluster.
- **CNI:** Flannel (K3s default).
- **Ingress:** NGINX (`ingress-nginx`), host-based routing on the LAN.
- **Helm values:**
  - Committed YAML under `monitoring/`, `ingress/`, `charts/` = **templates only** (safe to commit).
  - Live per-cluster values = `config/helm-values/` (gitignored).
- **First-party manifests (not Helm):** canonical YAML under `deploy/kustomize/base/` (Kustomize); apply with **`kubectl apply -k deploy/kustomize/base`** (see `deploy/kustomize/README.md`). `storage/` holds operational **documentation** for TrueNAS/NFS; do not assume PV manifests still live there.

## Infrastructure layer

- K3s on mixed repurposed hardware; external datastore for API persistence.
- Persistent data:
  - `local-path` (and similar) for many in-cluster components.
  - Static NFS-backed PV/PVC for datasets hosted on TrueNAS.

## Application layer

- **`monitoring` namespace:** Prometheus, Grafana, and related stack.
- **`media` namespace:** Plex; NFS for the media library (mostly reads). Sonarr/Radarr are not in-cluster — they need direct NAS-side file management and heavy churn on paths, which fits poorly behind generic NFS PVCs in K3s.
- **Platform:** standard K3s namespaces (`kube-system`, `ingress-nginx`, etc.).

## Key design decisions

- **External PostgreSQL for K3s:** cluster state survives control-plane disk issues and matches a homelab “DB elsewhere” pattern.
- **Template vs live Helm values:** committed files stay generic; secrets and cluster-specific overrides live in `config/helm-values/`.
- **Static NFS PV/PVC for media:** reuse existing TrueNAS paths and app config trees without copying data into cluster volumes.
- **hostNetwork for some LAN apps:** minimizes NAT/port-mapping complexity for selected homelab services.

## Integration patterns

- Ingress hostnames for LAN-facing apps (`grafana.lan`, `dalaran`, etc.).
- TrueNAS NFS exports consumed as static PV/PVC from the cluster.
- App migration: align UIDs, mount paths, and runtime IDs; roll out one workload at a time; verify before cutover.

## Constraints

- Homelab hardware and budget; LAN-first, limited external dependencies.
- TrueNAS-held data must stay consistent during migration (no silent “blank app” installs unless requested).
- **No hardcoded IPs** in committed automation — resolve from `config/nodes`, `K3S_CP_IP`, or `K3S_SCAN_SUBNET` as documented in `docs/agents.md`. Local **kubectl** kubeconfig uses **`K3S_CP_API_HOST`** (e.g. `dalaran.lan`), not the raw control-plane IP.
- Operational safety: avoid accidental destructive syncs or history rewrites without explicit intent.
