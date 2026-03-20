# homelab-showcase

Example Helm chart that demonstrates patterns used in this K3s homelab. **For showcase only** — safe to commit to a public repo. Additional template charts (e.g. Pi-hole) live under **charts/** in this directory; install them separately from their paths.

## What this chart shows

| Pattern | Used in this project |
|--------|------------------------|
| **nodeSelector** `kubernetes.io/hostname: <control-plane>` | Grafana, Prometheus, Loki, NGINX Ingress (pinned to control plane for stable image pull / single entry point). |
| **local-path** PVC | Grafana, Prometheus, Loki, MinIO, Promtail (see `monitoring/`, `ingress/`). |
| **Ingress** (nginx, host-based) | Grafana at `grafana.lan`; see `config/helm-values/prometheus-stack.yaml`, `ingress/`. |

## Install (optional)

Real values for this project live in **config/helm-values/** (gitignored). To try the showcase with placeholders:

```bash
# With placeholder values (won't schedule until controlPlaneHostname is set to a real node)
helm install homelab-showcase ./charts/homelab-showcase -n default

# With real control plane hostname (e.g. dalaran)
helm install homelab-showcase ./charts/homelab-showcase -n default \
  --set controlPlaneHostname=dalaran \
  --set ingressHost=showcase.lan
```

## Real values

Live Helm values (this project’s actual `dalaran`, `grafana.lan`, sizes, etc.) are in **config/helm-values/** and are **not** committed. See **config/README.md**.
