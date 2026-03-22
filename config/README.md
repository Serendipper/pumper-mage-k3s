# Config layout

Cluster-related values live under **config/**; scripts and skills source these so nothing is hardcoded.

## Committed (safe for public repo)

| File / dir | Purpose |
|------------|---------|
| **defaults.env** | Non-secret defaults (SSH user, key path, CP hostname/IP, **`K3S_CP_API_HOST`** for kubectl kubeconfig, scan subnet, K3s URL/port). |
| **project.env.example** | Template for project.env; copy to project.env and fill in. |
| **README.md** | This file. |

## Helm: templates vs live values

**Rule:** Every Helm release in this project uses **committed YAML only as a template** (safe to publish). **Live** values — real hostnames, nodeSelectors, passwords, DNS lines, sizes — live only under **`config/helm-values/`** (gitignored). Install and upgrade always use **`-f config/helm-values/<file>.yaml`** (after copying from the template once).

| Live file (gitignored) | Copy / start from (committed template) |
|------------------------|----------------------------------------|
| `config/helm-values/prometheus-stack.yaml` | `monitoring/helm-values.yaml` |
| `config/helm-values/loki.yaml` | `monitoring/loki-helm-values.yaml` |
| `config/helm-values/promtail.yaml` | `monitoring/promtail-helm-values.yaml` |
| `config/helm-values/ingress-nginx.yaml` | `ingress/helm-values-hostnetwork.yaml` |
| `config/helm-values/pihole.yaml` | `charts/homelab-showcase/charts/pihole/values.yaml` |
| `config/helm-values/homelab-showcase.yaml` | `charts/homelab-showcase/values.yaml` (if you install the umbrella chart) |

**Not Helm values:** `deploy/kustomize/base/monitoring/grafana-datasource-loki.yaml` is an optional raw **ConfigMap** fallback; prefer provisioning Loki via `additionalDataSources` in **`config/helm-values/prometheus-stack.yaml`**. It ships in the Kustomize base (`kubectl apply -k deploy/kustomize/base`); remove it from **`deploy/kustomize/base/kustomization.yaml`** if you only use Helm provisioning.

Committed Helm **templates** and **example values** live in **monitoring/**, **ingress/**, and **charts/homelab-showcase/** (including **charts/homelab-showcase/charts/pihole/**).

## First-party manifests (Kustomize, not Helm)

Static cluster YAML (cert-manager `ClusterIssuer` / `Certificate`, media PV/PVC, ingress, external gateways, optional Grafana ConfigMap) lives under **`deploy/kustomize/base/`**. Apply with **`kubectl apply -k deploy/kustomize/base`** (or **`./scripts/apply-cluster-manifests.sh`**). See **`deploy/kustomize/README.md`**. This is separate from Helm: upstream apps still use **`helm upgrade -f config/helm-values/...`**.

## Gitignored (agent / maintainer only — do not publish)

| File / dir | Purpose |
|------------|---------|
| **project.env** | Secrets and overrides (password, WiFi PSK, datastore URL). |
| **nodes** | Hostname and IP, one per line; **gitignored**. Source of truth for all node and control-plane IPs; agent must read from here. Never hardcode IPs in the repo. After board/media swaps or to reconcile IPs: `kubectl get nodes -o wide` and update **nodes** from INTERNAL-IP. |
| **generated/** | Generated files (e.g. Pi first-boot). |
| **helm-values/** | **Live Helm values** for every chart (see table above). Agent and maintainers use **only** these files with `helm install` / `helm upgrade -f ...`; they are not committed. |

## Using live Helm values

1. Create the directory (if missing): `mkdir -p config/helm-values`
2. Copy each template you use into the matching **live** filename (see **Helm: templates vs live values** table above).
3. Edit with real hostnames, `nodeSelector` hostnames, passwords, DNS lines, PVC sizes. For **kube-prometheus-stack**, keep **Grafana and Prometheus** pinned to the **control plane** unless you use shared storage (see **monitoring/README.md** § Design).
4. Always **`helm install` / `helm upgrade` with `-f config/helm-values/<file>.yaml`**. Do not point Helm at committed template paths for production installs — templates use placeholder hostnames/passwords and drift from your cluster.

**Grafana admin user/password:** only in **`config/helm-values/prometheus-stack.yaml`**. **`monitoring/helm-values.yaml`** stays a template (`OVERRIDE_AT_INSTALL` or similar).

Chart-specific commands (paths, release names): **charts/README.md**, **monitoring/README.md**, **ingress/README.md**.
