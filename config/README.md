# Config layout

Cluster-related values live under **config/**; scripts and skills source these so nothing is hardcoded.

## Committed (safe for public repo)

| File / dir | Purpose |
|------------|---------|
| **defaults.env** | Non-secret defaults (SSH user, key path, CP hostname/IP, scan subnet, K3s URL/port). |
| **project.env.example** | Template for project.env; copy to project.env and fill in. |
| **README.md** | This file. |

Committed Helm **templates** and **example values** live in **monitoring/**, **ingress/**, and **charts/homelab-showcase/**.

## Gitignored (agent / maintainer only — do not publish)

| File / dir | Purpose |
|------------|---------|
| **project.env** | Secrets and overrides (password, WiFi PSK, datastore URL). |
| **nodes** | Hostname and IP, one per line; **gitignored**. Source of truth for all node and control-plane IPs; agent must read from here. Never hardcode IPs in the repo. |
| **generated/** | Generated files (e.g. Pi first-boot). |
| **helm-values/** | **Live Helm values** for this project. Copy from `monitoring/helm-values.yaml`, `ingress/helm-values-hostnetwork.yaml`, etc., then customize (real hostnames, sizes, passwords). Agent and maintainers use these for `helm upgrade`; they are not committed. |

## Using live Helm values

1. Create the directory (if missing): `mkdir -p config/helm-values`
2. Copy in the values you want to override, e.g.:
   - `cp monitoring/helm-values.yaml config/helm-values/prometheus-stack.yaml`
   - `cp ingress/helm-values-hostnetwork.yaml config/helm-values/ingress-nginx.yaml`
3. Edit the copies with your real hostnames, IPs, sizes. Use `helm upgrade ... -f config/helm-values/<file>.yaml` when applying.

The **charts/homelab-showcase** chart is an example of patterns only; its real values can also live in **config/helm-values/** if you install it.
