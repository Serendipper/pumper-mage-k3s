# Monitoring stack (Prometheus + Grafana)

Helm-based deployment of [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack): Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, and default dashboards.

**Procedure:** See `skills/monitoring-stack-setup/SKILL.md`.

| File | Purpose |
|------|---------|
| `helm-values.yaml` | Grafana Ingress (grafana.lan), **persistence** (local-path, 10Gi), Prometheus retention 15d + **persistence** (local-path, 20Gi), **Loki datasource**. |
| `loki-helm-values.yaml` | Loki monolithic + MinIO, local-path PVCs (30Gi Loki, MinIO default), pinned to dalaran. |
| `promtail-helm-values.yaml` | Promtail: push logs to Loki, local-path 1Gi for positions. |
| `grafana-datasource-loki.yaml` | Fallback ConfigMap for Loki datasource only if not using stack values. **Loki is provisioned from helm-values.yaml** (additionalDataSources). |

## Install (from control plane or with kubeconfig)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/helm-values.yaml
```

Optional: set Grafana admin password at install:

```bash
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/helm-values.yaml \
  --set grafana.adminPassword='your-secure-password'
```

## Access

- **Grafana:** http://grafana.lan (or http://&lt;ingress-IP&gt; with `Host: grafana.lan`). Login: `admin` / password from values (override at install; do not use default in production) or from `--set grafana.adminPassword=...` at install. To retrieve the password from the cluster: `kubectl -n monitoring get secret prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo`
- **Prometheus:** cluster-internal only (Grafana uses it as a datasource). To expose later, add an Ingress or port-forward.

## Access from LAN (grafana.lan)

So that **grafana.lan** resolves on your LAN (Windows, phones, etc.), use one of:

- **Pi-hole on medivh:** Run `./scripts/setup-pihole-grafana-dns.sh medivh` from the repo when medivh is reachable. It adds `grafana.lan` → control plane IP (from config) and restarts Pi-hole. **Important:** Clients must use **medivh’s IP as their DNS server** — get medivh’s IP from **config/nodes**; set the router’s DHCP DNS to that IP. Then on Windows run `ipconfig /flushdns` and try http://grafana.lan again.
- **Windows hosts file:** Add `<control-plane-IP>   grafana.lan` to `C:\Windows\System32\drivers\etc\hosts` (edit as Administrator). Control plane IP from **config/nodes** (key `K3S_CP_HOST`) or **config** `K3S_CP_IP`.
- **Other:** See README "What's Not Included" / Grafana for hosts-file and LAN DNS options.

## Loki and Promtail (logs)

- **Loki:** `helm repo add grafana https://grafana.github.io/helm-charts && helm install loki grafana/loki -n monitoring -f monitoring/loki-helm-values.yaml`
- **Promtail:** `helm install promtail grafana/promtail -n monitoring -f monitoring/promtail-helm-values.yaml` (after Loki is running).
- **Grafana:** Add Loki datasource: Connections → Data sources → Add data source → Loki, URL `http://loki-gateway`, Save. Or re-apply the stack with `helm-values.yaml` (includes `additionalDataSources` for Loki).

## Persistence (local-path)

Grafana, Prometheus, Loki, MinIO, and Promtail use **local-path** PVCs on dalaran. Ensure the control plane has enough free disk (see README storage notes).

## Prerequisites

- NGINX Ingress Controller (see `ingress/`) so the Grafana Ingress is served.
- Helm 3 and `kubectl` (e.g. on the control plane).
