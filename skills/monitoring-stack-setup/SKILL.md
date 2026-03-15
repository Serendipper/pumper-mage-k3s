---
name: monitoring-stack-setup
description: Install Prometheus + Grafana (kube-prometheus-stack) on the K3s cluster via Helm. Use after ingress-nginx is running so Grafana is reachable via Ingress.
---

# Monitoring stack (Prometheus + Grafana) setup

Installs [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack): Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, and default dashboards. Grafana is exposed via the existing NGINX Ingress (host `grafana.lan`).

## Prerequisites

- Cluster is up; NGINX Ingress Controller is installed (`ingress/`, `skills/ingress-nginx-setup/`).
- Helm 3 and kubectl on the control plane (or wherever you run with kubeconfig).

## 1. Install Helm (if needed)

On the control plane:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Or: `sudo apt install helm` (Debian).

## 2. Add Helm repo and install

From the repo root (so `monitoring/helm-values.yaml` is available), or copy the values file to the node first.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/helm-values.yaml
```

Optional: set Grafana admin password at install (recommended):

```bash
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/helm-values.yaml \
  --set grafana.adminPassword='your-secure-password'
```

If running from a machine that doesn't have the repo (e.g. only on the CP), copy the values file to the CP then run the same `helm install` with `-f /path/to/helm-values.yaml`.

## 3. Wait for pods

```bash
kubectl -n monitoring get pods -w
```

Wait until the stack pods are Running (Prometheus, Grafana, node-exporter, kube-state-metrics, etc.). Ctrl+C when satisfied.

## 4. Access Grafana

- URL: http://grafana.lan (or http://&lt;control-plane-IP&gt; with header `Host: grafana.lan` if you don't have DNS).
- Login: `admin` / password from values or the one you set with `--set grafana.adminPassword=...`.

Prometheus is used by Grafana as a datasource; it is not exposed by default. To expose it, add an Ingress or use `kubectl port-forward`.

## 5. Persistence (local-path) and Loki

The repo values enable **Grafana** and **Prometheus** persistence (local-path) and add a **Loki** datasource. If the stack was installed without these, upgrade:

```bash
helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring/helm-values.yaml
```

If a previous upgrade is stuck (`pending-upgrade`), rollback then re-upgrade:

```bash
helm rollback prometheus-stack 2 -n monitoring
# wait for rollback to complete, then:
helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring/helm-values.yaml
```

**Loki (logs):** `helm repo add grafana https://grafana.github.io/helm-charts`, then install Loki and Promtail per **monitoring/README.md** (Loki + Promtail section). In Grafana, add the Loki datasource: Connections → Data sources → Add data source → Loki, URL `http://loki-gateway`, Save.

## Artifacts

- **monitoring/helm-values.yaml** — Grafana Ingress (grafana.lan), persistence (local-path), Prometheus retention + persistence, Loki datasource.
- **monitoring/loki-helm-values.yaml** — Loki monolithic + MinIO, local-path PVCs.
- **monitoring/promtail-helm-values.yaml** — Promtail → Loki, persistence for positions.
- **monitoring/README.md** — Quick reference and install commands.
