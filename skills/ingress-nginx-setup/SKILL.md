---
name: ingress-nginx-setup
description: Install and configure NGINX Ingress Controller on the K3s cluster via Helm. Use after the control plane and workers are running; traefik and servicelb should be disabled.
---

# NGINX Ingress Controller Setup

K3s ships with Traefik disabled in this project. This skill installs the [ingress-nginx](https://github.com/kubernetes/ingress-nginx) controller via Helm so you can use Ingress resources to route HTTP/HTTPS traffic to Services.

## Prerequisites

- Cluster is up; you can run `kubectl get nodes` (from the control plane or with kubeconfig).
- Helm 3 installed where you run `helm` (control plane or your laptop with kubeconfig).

## 1. Install Helm (if needed)

On the control plane (or wherever you run kubectl):

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Or from Debian: `apt install helm` (may be older).

## 2. Add the ingress-nginx Helm repo

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

## 3. Install the controller

**Recommended:** copy **`ingress/helm-values-hostnetwork.yaml`** to **`config/helm-values/ingress-nginx.yaml`**, set `controller.nodeSelector` to your **`K3S_CP_HOST`**, then install from the **live** file only (see **config/README.md** § *Helm: templates vs live values*).

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f config/helm-values/ingress-nginx.yaml
```

Artifacts (values **template**, example Ingress) live in **ingress/**. HTTP/HTTPS to that node’s IP hit the controller.

**Option B — NodePort**  
Controller is exposed via a NodePort (e.g. 30080/30443). No hostNetwork; you use `http://<any-node-ip>:30080`.

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443
```

## 4. Wait for the controller to be ready

```bash
kubectl -n ingress-nginx get pods -w
```

Ctrl+C when the controller pod is `Running` and `READY` 1/1.

## 5. Smoke test with a simple Ingress

Create a tiny app and an Ingress that points at it:

```bash
kubectl create deployment demo --image=registry.k8s.io/e2e-test-images/echoserver:2.5 --port=8080
kubectl expose deployment demo --port=80 --target-port=8080
```

Then an Ingress (adjust host if you use a real DNS name):

```yaml
# demo-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: demo.lan
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo
            port:
              number: 80
```

Apply and test:

```bash
kubectl apply -f demo-ingress.yaml
# From a machine that can reach the control plane IP:
curl -H "Host: demo.lan" http://<CONTROL_PLANE_IP>/
# Or add to /etc/hosts: <CONTROL_PLANE_IP> demo.lan  then open http://demo.lan in a browser
```

## 6. (Optional) TLS

For HTTPS you’ll need certificates. Common options:

- **cert-manager** — issues certs from Let’s Encrypt or a private CA; add a ClusterIssuer and annotate the Ingress.
- **Manual certs** — create a TLS secret and reference it in the Ingress (`spec.tls`).

Not covered in this skill; see [ingress-nginx TLS](https://kubernetes.github.io/ingress-nginx/user-guide/tls/) and cert-manager docs.

## Summary

| Choice | Access |
|--------|--------|
| hostNetwork (live values in `config/helm-values/ingress-nginx.yaml`) | `http://<ingress-node-ip>/` (ports 80/443) |
| NodePort | `http://<any-node-ip>:30080/` |

After this, create Ingress resources for your apps with `ingressClassName: nginx` and route by host/path.
