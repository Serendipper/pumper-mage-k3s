# Pi-hole

Runs [Pi-hole](https://pi-hole.net/) as a pod on a single node. Uses **hostNetwork** so DNS (port 53) and the admin UI (port 80) are bound directly to that node's IP; LAN clients use that IP as their DNS server.

## Prerequisites

- A worker node (the chart's `nodeName` value; default in values is the node used for Pi-hole). The chart uses `nodeSelector: kubernetes.io/hostname: <nodeName>`.
- Default StorageClass (e.g. K3s `local-path`) so the PVC can be provisioned on that node.

## Install

1. **Copy template → live values** (required; committed `values.yaml` is a template only — **config/README.md**):

   ```bash
   mkdir -p config/helm-values
   cp charts/homelab-showcase/charts/pihole/values.yaml config/helm-values/pihole.yaml
   # Edit config/helm-values/pihole.yaml: set webPassword or existingSecret, timezone, upstreamDns.
   ```

2. **Set a web password** (recommended). Either:

   - In values: `webPassword: "your-secure-password"` (e.g. in `config/helm-values/pihole.yaml`), or  
   - Create a Secret and use `existingSecret`:

     ```bash
     kubectl create secret generic pihole-web --from-literal=password='your-secure-password'
     ```

     Then in values: `existingSecret: { name: pihole-web, key: password }`.

3. **Install the chart**:

   ```bash
   helm upgrade --install pihole ./charts/homelab-showcase/charts/pihole -f config/helm-values/pihole.yaml
   ```

   If you use `--set` for a one-off fix, mirror the same fields into **`config/helm-values/pihole.yaml`** before you forget.

4. **Point clients at Pi-hole**:

   - The node running Pi-hole may need a **static IP** (e.g. `192.168.1.5`) so the router and LAN clients can use it as DNS. Use `scripts/set-node-static-ip.sh <hostname> <ip/cidr> [gateway]` to configure a node's wlan0 for a static address.
   - In your router or DHCP: set the DNS server to that node's IP.
   - Admin UI: open `http://<node-IP>` in a browser.

## Values

| Value | Description | Default |
|-------|-------------|---------|
| `nodeName` | Node to schedule on (hostname) | See values.yaml |
| `timezone` | TZ for Pi-hole | `UTC` |
| `webPassword` | Web UI password (creates a Secret if set) | `""` |
| `existingSecret` | `{ name: <secret>, key: <key> }` for WEBPASSWORD | `{}` |
| `persistenceSize` | PVC size for config | `1Gi` |
| `storageClass` | StorageClass for PVC (empty = default) | `""` |
| `upstreamDns` | Upstream DNS (semicolon-separated, Pi-hole v6) | `8.8.8.8;8.8.4.4` |
| `customDnsmasqLines` | Custom dnsmasq lines (e.g. `address=/grafana.lan/<control-plane-IP>`); applied via env on every pod start so they survive restarts | See values.yaml |

## Uninstall

```bash
helm uninstall pihole
# PVC is left behind; delete if desired:
kubectl delete pvc pihole-data
```
