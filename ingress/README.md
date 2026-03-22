# Ingress (NGINX)

Artifacts for the NGINX Ingress Controller on this cluster. Traefik and servicelb are disabled; ingress-nginx is installed via Helm.

**Convention:** **`ingress/helm-values-hostnetwork.yaml`** is a **template**. **Live** values: **`config/helm-values/ingress-nginx.yaml`** (gitignored). Full mapping: **config/README.md**.

**Procedure:** See `skills/ingress-nginx-setup/SKILL.md`.

**Control plane IP vs Ingress:** HTTP `Ingress` rules use **hostnames** (`dalaran.plex`, `openclaw.dalaran.lan`, …). They do **not** embed the control-plane IP. Clients reach nginx on **dalaran** because **Pi-hole** (or LAN DNS) maps those names to the **node IP** where **ingress-nginx** runs (`hostNetwork` + `nodeSelector` to **`dalaran`**). When that IP changes, fix **Pi-hole** Helm values and **`kubectl apply`** any updated Kustomize YAML — see **`docs/agents.md`** § *“Update dalaran” / control plane IP or ingress DNS*.

| File | Purpose |
|------|---------|
| `helm-values-hostnetwork.yaml` | **Template** — copy to `config/helm-values/ingress-nginx.yaml`, set `controller.nodeSelector` to your CP hostname. |
| `demo-ingress.yaml` | Example Ingress for the echoserver smoke test; host `demo.lan`. |

Install (from control plane or with kubeconfig):

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace \
  -f config/helm-values/ingress-nginx.yaml
```

For a one-off bootstrap without the repo on disk, you can use `--set` / `--set-json` for `nodeSelector` (still copy the result into **`config/helm-values/ingress-nginx.yaml`** afterward so upgrades stay consistent).
