# Pi-hole

Runs [Pi-hole](https://pi-hole.net/) on a single node with **hostNetwork** (DNS on 53, admin on 80). LAN clients use that node’s IP as their resolver.

**DNS vs ports:** Pi-hole only supplies **A/CNAME → IP**. It does **not** encode ports. Ingress hostnames (`grafana.lan`, `dalaran.plex`, `dalaran.sonarr`, …) all resolve to the **same IP** as `dalaran.lan` (via `cname=...,dalaran.lan`). You open **`http://` those names on port 80**; **nginx Ingress** on the control plane routes by `Host` to Plex in-cluster or **proxies** Sonarr/Radarr to TrueNAS (`plex-ingress-dalaran.yaml`). To hit the NAS **directly** (not via ingress), use **`truenas` / `truenas.lan`** and the app’s real port in the URL.

## Install

1. Copy **`values.yaml`** → **`config/helm-values/pihole.yaml`** (see **config/README.md**), set password / timezone / upstream DNS as needed.
2. **`helm upgrade --install pihole ./charts/homelab-showcase/charts/pihole -f config/helm-values/pihole.yaml`**

## Values

| Value | Description |
|-------|-------------|
| `nodeName` | Kubernetes node hostname to schedule on |
| `customDnsmasqLines` | dnsmasq lines: **`address=/dalaran.lan/<ip>`** once; **`cname=app.lan,dalaran.lan`** for ingress apps so only the `dalaran.lan` line changes when the CP IP changes (see **docs/control-plane-ip-change.md**) |
| `upstreamDns`, `timezone`, `persistenceSize` | As usual |

## Uninstall

```bash
helm uninstall pihole
kubectl delete pvc pihole-data   # optional
```
