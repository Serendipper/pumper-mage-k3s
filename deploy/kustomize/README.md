# First-party cluster manifests (Kustomize)

**Single workflow** for YAML maintained in-repo (not upstream Helm charts):

```bash
./scripts/apply-cluster-manifests.sh
```

Uses **`deploy/kustomize/live`** when **`deploy/kustomize/live/private/media-pvs.yaml`** and **`private/site.yaml`** exist (gitignored); otherwise **`deploy/kustomize/base`** only. See **`docs/kustomize-live.md`**, **`./scripts/init-kustomize-live.sh`**.

For a raw apply without the live overlay:

```bash
kubectl apply -k deploy/kustomize/base
```

## Layout

| Path under `deploy/kustomize/base/` | Contents |
|-------------------------------------|----------|
| `cert-manager/` | LE **staging** ClusterIssuer + OpenClaw **staging** Certificate (install **cert-manager** controller first). **Prod** issuer + cert YAML files stay in-repo for copy/paste when you have a **public** `dnsName`; they are **not** in the default base (`.lan` will not work with Let’s Encrypt). |
| `storage/` | `media` namespace, PVCs, Plex, Ingress, TrueNAS *arr + OpenClaw (placeholder IPs in base); live PVs in **`deploy/kustomize/live/private/media-pvs.yaml`** |
| `monitoring/` | Grafana Loki datasource ConfigMap (optional fallback); **Node CPU Temps** dashboard (`node-cpu-temps.json` + `configMapGenerator`); Plex blackbox probe (`plex-probe.yaml`) via HAProxy on **modera** |
| `live/` | **Overlay** (base + **`private/`** gitignored PV + site patches) — see **`docs/kustomize-live.md`** |
| `networking/haproxy-ingress-lb/` | HAProxy DaemonSet (optional) — apply with **`./scripts/apply-haproxy-ingress-lb.sh`** |

**Not included:** Helm releases (ingress-nginx, kube-prometheus-stack, Loki, Pi-hole, …) — use **`helm upgrade -f config/helm-values/...`**. **Not included:** `ingress/demo-ingress.yaml` (smoke test only).

## Prerequisites

1. **cert-manager** controller if you apply ACME issuers/certificates (`kubectl get pods -n cert-manager`).
2. **ClusterIssuer** YAML still contains **`YOUR_EMAIL@YOUR_DOMAIN`** placeholders until you edit files under **`deploy/kustomize/base/cert-manager/`** and re-apply.

## Overlays (optional)

Add `deploy/kustomize/overlays/<name>/kustomization.yaml` with `resources: [../../base]` and patches; apply with `kubectl apply -k deploy/kustomize/overlays/<name>`.
