# First-party cluster manifests (Kustomize)

**Single workflow** for YAML maintained in-repo (not upstream Helm charts):

```bash
kubectl apply -k deploy/kustomize/base
```

Or:

```bash
./scripts/apply-cluster-manifests.sh
```

## Layout

| Path under `deploy/kustomize/base/` | Contents |
|-------------------------------------|----------|
| `cert-manager/` | LE **staging** ClusterIssuer + OpenClaw **staging** Certificate (install **cert-manager** controller first). **Prod** issuer + cert YAML files stay in-repo for copy/paste when you have a **public** `dnsName`; they are **not** in the default base (`.lan` will not work with Let’s Encrypt). |
| `storage/` | `media` namespace, NFS PV/PVC, Plex, media Ingress, TrueNAS *arr external Services/Endpoints, OpenClaw gateway |
| `monitoring/` | Grafana Loki datasource ConfigMap (optional fallback); **Node CPU Temps** dashboard (`node-cpu-temps.json` + `configMapGenerator`) |

**Not included:** Helm releases (ingress-nginx, kube-prometheus-stack, Loki, Pi-hole, …) — use **`helm upgrade -f config/helm-values/...`**. **Not included:** `ingress/demo-ingress.yaml` (smoke test only).

## Prerequisites

1. **cert-manager** controller if you apply ACME issuers/certificates (`kubectl get pods -n cert-manager`).
2. **ClusterIssuer** YAML still contains **`YOUR_EMAIL@YOUR_DOMAIN`** placeholders until you edit files under **`deploy/kustomize/base/cert-manager/`** and re-apply.

## Overlays (optional)

Add `deploy/kustomize/overlays/<name>/kustomization.yaml` with `resources: [../../base]` and patches; apply with `kubectl apply -k deploy/kustomize/overlays/<name>`.
