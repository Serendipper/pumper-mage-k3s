# Ingress (NGINX)

Artifacts for the NGINX Ingress Controller on this cluster. Traefik and servicelb are disabled; ingress-nginx is installed via Helm.

**Procedure:** See `skills/ingress-nginx-setup/SKILL.md`.

| File | Purpose |
|------|---------|
| `helm-values-hostnetwork.yaml` | Helm values for controller with hostNetwork on the control plane (single entry point on 80/443). |
| `demo-ingress.yaml` | Example Ingress for the echoserver smoke test; host `demo.lan`. |

Install (from control plane or with kubeconfig). Use `K3S_CP_HOST` from config for the nodeSelector value:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.hostPort.enabled=true \
  --set controller.kind=DaemonSet \
  --set-json controller.nodeSelector='{"kubernetes.io/hostname":"YOUR_CP_HOST"}'
```

Or install from the values file and override the hostname:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace \
  -f ingress/helm-values-hostnetwork.yaml \
  --set-json controller.nodeSelector='{"kubernetes.io/hostname":"YOUR_CP_HOST"}'
```
