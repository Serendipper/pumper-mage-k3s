# Monitoring stack (Prometheus + Grafana)

Helm-based deployment of [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack): Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, and default dashboards.

**Convention:** Everything under **`monitoring/`** that feeds Helm (or optional raw manifests) is a **committed template**. **Live** values live only in **`config/helm-values/`** (gitignored). Mapping and workflow: **config/README.md** § *Helm: templates vs live values*.

**Procedure:** See `skills/monitoring-stack-setup/SKILL.md`.

| Committed (template) | Live (gitignored) — use with `helm -f` |
|------------------------|----------------------------------------|
| `helm-values.yaml` | `config/helm-values/prometheus-stack.yaml` — Grafana auth, Ingress (`grafana.lan`), persistence, Prometheus, Loki datasource |
| `loki-helm-values.yaml` | `config/helm-values/loki.yaml` |
| `promtail-helm-values.yaml` | `config/helm-values/promtail.yaml` |
| `grafana-datasource-loki.yaml` | Prefer **`additionalDataSources`** in `prometheus-stack.yaml`; this ConfigMap is an optional fallback only (see **config/README.md**) |

## Install (from control plane or with kubeconfig)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f config/helm-values/prometheus-stack.yaml
```

## Access

- **Grafana:** http://grafana.lan (or http://&lt;ingress-IP&gt; with `Host: grafana.lan`). Login: credentials in **`config/helm-values/prometheus-stack.yaml`** (`grafana.adminUser` / `grafana.adminPassword`); from the cluster: `kubectl -n monitoring get secret prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo`. Where values live: **config/README.md**.
- **Prometheus:** cluster-internal only (Grafana uses it as a datasource). To expose later, add an Ingress or port-forward.

## Access from LAN (grafana.lan)

So that **grafana.lan** resolves on your LAN (Windows, phones, etc.), use one of:

- **Pi-hole (cluster, modera):** Custom DNS (e.g. `grafana.lan` → control plane) is set in the chart via `customDnsmasqLines` in **config/helm-values/pihole.yaml**. Install/upgrade: **charts/README.md**. Clients use the Pi-hole node's IP (modera) as their DNS server — set router DHCP DNS to that IP (from **config/nodes**).  
- **Bare-metal Pi-hole** (e.g. on another host): Run `./scripts/setup-pihole-grafana-dns.sh <host>` from the repo when that host is reachable. It adds `grafana.lan` → control plane IP. Clients use that host's IP as their DNS server.
- **Windows hosts file:** Add `&lt;control-plane-IP&gt;   grafana.lan` to `C:\Windows\System32\drivers\etc\hosts` (edit as Administrator). Control plane IP from **config/nodes** (key `K3S_CP_HOST`) or **config** `K3S_CP_IP`.
- **Other:** See README "What's Not Included" / Grafana for hosts-file and LAN DNS options.

## Loki and Promtail (logs)

- **Loki:** `helm repo add grafana https://grafana.github.io/helm-charts && helm install loki grafana/loki -n monitoring -f config/helm-values/loki.yaml`
- **Promtail:** `helm install promtail grafana/promtail -n monitoring -f config/helm-values/promtail.yaml` (after Loki is running). Upgrade the same way with `-f config/helm-values/promtail.yaml`.
- **Grafana:** Add Loki datasource: Connections → Data sources → Add data source → Loki, URL `http://loki-gateway`, Save. Or re-apply the stack with `config/helm-values/prometheus-stack.yaml` (includes `additionalDataSources` for Loki).

## Design: Grafana, Prometheus, and `local-path`

**`local-path` + ReadWriteOnce** means each PVC’s data lives on **one node** for the life of that volume. The Prometheus pod **must** schedule on **that same node**, or it stays **Pending** — Grafana then shows datasource errors.

**Preferred homelab layout (this repo’s values):** pin **both Grafana and Prometheus** to the **control plane** (`dalaran`, from **config/nodes** / `K3S_CP_HOST`):

- **One place for metrics disk** — easier to plan free space on the CP.
- **Grafana → Prometheus stays on-host** — no cross-node pod traffic for the default Prometheus datasource (avoids whole classes of “works from one node, flaky from another” CNI issues).
- **Workers stay optional** for scrape targets (node-exporter, etc.); they don’t host the TSDB.

**What went wrong with “pin Prometheus to khadgar”:** that was a **workaround** for **Pending**: the Prometheus PVC had already bound on `khadgar` (first schedule or an old `nodeSelector`), so the pod had to match the volume. It **does not** mean a worker laptop is a good home for the TSDB — it couples dashboards to that node’s network and uptime.

**Better than re-pinning to a random worker:**

1. **Green field or willing to drop TSDB history:** set `prometheus.prometheusSpec.nodeSelector` to **`dalaran`** in **`config/helm-values/prometheus-stack.yaml`** (template: `monitoring/helm-values.yaml`), delete the old Prometheus **STS pod + PVC**, then `helm upgrade` so a **new** PVC is provisioned on `dalaran`. **This wipes Prometheus data** unless you snapshot/restore off-cluster.
2. **Keep history:** back up Prometheus TSDB (or accept loss), then same as (1), or move to **NFS / shared storage** (see **`storage/README.md`**) so the workload is not welded to one worker’s disk.

**Loki stack:** Grafana, Loki, MinIO, and Promtail in this project are pinned to **`dalaran`** in the **live** values under **`config/helm-values/`** (templates under **`monitoring/`**) — same “stable node + local disk” idea.

## Persistence (local-path)

Ensure **`dalaran`** has enough free disk for Grafana + Prometheus PVCs (sizes in **your** `config/helm-values/prometheus-stack.yaml`). Loki / Promtail PVC sizes live in **`config/helm-values/loki.yaml`** and **`promtail.yaml`**.

## Prerequisites

- NGINX Ingress Controller (see `ingress/`) so the Grafana Ingress is served.
- Helm 3 and `kubectl` (e.g. on the control plane).
