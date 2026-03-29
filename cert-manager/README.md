# cert-manager + Let’s Encrypt (OpenClaw Ingress)

Adds **public-CA TLS** via [cert-manager](https://cert-manager.io/) and **Let’s Encrypt** HTTP-01, aligned with **`skills/ingress-nginx-setup/SKILL.md`** (`ingressClassName: nginx`).

**LAN-only / `.lan` only:** you **do not** need this bundle. Use **self-signed** `openclaw-tls` or a **private CA** ([openclaw reverse-proxy](../../../../openclaw/docs/reverse-proxy-k3s.md) §5–6.5). Let’s Encrypt **cannot** issue for private suffix names.

## Prerequisites

1. **cert-manager** installed (`kubectl get pods -n cert-manager`).
2. **ACME email** — edit **`deploy/kustomize/base/cert-manager/clusterissuer-letsencrypt-staging.yaml`** and **`.../clusterissuer-letsencrypt-prod.yaml`**: replace **`YOUR_EMAIL@YOUR_DOMAIN`** with an address you control (Let’s Encrypt expiration notices). **Reserved / documentation domains are rejected** — e.g. **`@example.com`**, **`@example.net`**, **`@example.org`** (`invalidContact` / `forbidden domain`). If you already applied with a bad address, delete **`letsencrypt-staging-account-key`** (or **`letsencrypt-prod-account-key`**) in **`cert-manager`**, fix **`spec.acme.email`**, and re-apply the ClusterIssuer so registration runs again.
3. **Public hostname (or DNS-01)** — HTTP-01 needs Let’s Encrypt to reach **`http://<your-public-hostname>/.well-known/acme-challenge/...`** from the **internet** on **port 80** (or use **DNS-01** — not in these files). **`openclaw.dalaran.lan`** is a **`.lan`** name: Let’s Encrypt **will not** issue for it (`rejectedIdentifier` / “does not end with a valid public suffix”). Use a **public DNS name** (CNAME to your ingress, etc.), **DNS-01** against a zone you control, or a **private CA** for LAN-only names ([openclaw reverse-proxy doc](../../../../openclaw/docs/reverse-proxy-k3s.md) §6.1).
4. **Ingress** — **`deploy/kustomize/base/storage/openclaw-external-gateway.yaml`** (or live **`openclaw`** Ingress) must keep **`ingressClassName: nginx`**. cert-manager will create temporary challenge Ingresses.

## Install cert-manager (once per cluster)

```bash
export CM_VER=v1.20.0   # bump from https://github.com/cert-manager/cert-manager/releases
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VER}/cert-manager.yaml"
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=180s
```

## Apply issuers + certificates

Manifests live under **`deploy/kustomize/base/cert-manager/`** and are part of the unified first-party apply:

```bash
# From repo root — applies cert-manager CRs together with storage/monitoring resources in the base
kubectl apply -k deploy/kustomize/base
```

To work on **staging** first, temporarily remove or comment out prod resources in **`deploy/kustomize/base/kustomization.yaml`**, or apply only the staging files:

```bash
kubectl apply -f deploy/kustomize/base/cert-manager/clusterissuer-letsencrypt-staging.yaml
kubectl apply -f deploy/kustomize/base/cert-manager/certificate-openclaw-staging.yaml
kubectl describe certificate -n default openclaw-dalaran-staging
```

When **`Ready=True`** on staging, add prod issuers/certificates to the base (or apply prod YAML) and re-run **`kubectl apply -k deploy/kustomize/base`**.

**OpenClaw backend host:** ensure **`gateway.controlUi.allowedOrigins`** still includes **`https://openclaw.dalaran.lan`** and **`https://openclaw.dalaran.lan:31935`** (or **:443** if you move off NodePort).

## Files (under `deploy/kustomize/base/cert-manager/`)

| File | Purpose |
|------|---------|
| `clusterissuer-letsencrypt-staging.yaml` | LE **staging** ClusterIssuer (HTTP-01, `nginx` class) — **included** in `kubectl apply -k deploy/kustomize/base` |
| `clusterissuer-letsencrypt-prod.yaml` | LE **production** ClusterIssuer — **not** in default Kustomize base; apply manually when you have a **public** DNS name |
| `certificate-openclaw-staging.yaml` | Certificate → **`openclaw-tls-staging`** (test) — in Kustomize base |
| `certificate-openclaw-prod.yaml` | Certificate → **`openclaw-tls`** — **not** in default base (`.lan` cannot use Let’s Encrypt); apply manually with a public `dnsName` |

After prod cert is **Ready**, point **`openclaw`** Ingress **`spec.tls[0].secretName`** at **`openclaw-tls`** (prod secret).

## Troubleshooting

| Symptom | Cause | What to do |
|--------|--------|------------|
| **`invalidContact` / `forbidden domain`** on ClusterIssuer | ACME **`email`** uses a reserved doc domain (`example.com`, `example.net`, `example.org`, …) | Fix **`spec.acme.email`**, **`kubectl delete secret -n cert-manager letsencrypt-staging-account-key`**, re-apply issuer |
| **`rejectedIdentifier` / valid public suffix** on Certificate / Order | **`dnsNames`** use **`.lan`** or another non-public suffix | Use a **public hostname**, **DNS-01** to a public zone, or **private CA** (not Let’s Encrypt) |

## References

- [cert-manager — HTTP-01](https://cert-manager.io/docs/configuration/acme/http01/)
- [openclaw reverse proxy](../../../../openclaw/docs/reverse-proxy-k3s.md)
