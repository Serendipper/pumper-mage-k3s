# Pi-hole

Runs [Pi-hole](https://pi-hole.net/) on a single node with **hostNetwork** (DNS on 53; web UI on **`webServerPort`**, default **8080**, so **HAProxy** on the same node can bind **:80** for ingress + **`pihole.lan`**). LAN clients use that node’s IP as their resolver.

**DNS vs ports:** Pi-hole only supplies **A records** via **`address=/name/ip`** (no CNAME chaining in this chart). **`dalaran`** / **`dalaran.lan`** should stay the **real** control-plane IP; ingress hostnames (**`grafana.lan`**, **`dalaran.plex`**, …) point at **modera** when using **`scripts/apply-haproxy-ingress-lb.sh`**. You open **`http://` those names on port 80**; **HAProxy** → **nginx Ingress** routes by `Host` (see **`ingress/README.md`**). To hit the NAS **directly** (not via ingress), use **`truenas` / `truenas.lan`** and the app’s real port in the URL.

## Install

1. Copy **`values.yaml`** → **`config/helm-values/pihole.yaml`** (see **config/README.md**), set password / timezone / upstream DNS as needed.
2. **`helm upgrade --install pihole ./charts/homelab-showcase/charts/pihole -f config/helm-values/pihole.yaml`**

## Values

| Value | Description |
|-------|-------------|
| `nodeName` | Kubernetes node hostname to schedule on |
| `webServerPort` | Pi-hole web UI port on the node (default **8080** when HAProxy owns **:80** on modera) |
| `customDnsmasqLines` | **`address=/hostname/<ip>`** per LAN name; with HAProxy, ingress-related names use **modera**’s IP — see **docs/control-plane-ip-change.md** |
| `upstreamDns`, `timezone`, `persistenceSize` | As usual |

## Uninstall

```bash
helm uninstall pihole
kubectl delete pvc pihole-data   # optional
```
