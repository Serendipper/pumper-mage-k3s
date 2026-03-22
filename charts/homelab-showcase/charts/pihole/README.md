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
   - **Per-machine:** each host must use Pi-hole as its DNS resolver, or names in `customDnsmasqLines` (e.g. `truenas`) will not resolve — `ssh user@truenas` will fail with “Could not resolve hostname” if the client still uses Google DNS / router forwarding that bypasses Pi-hole.
   - **Verify:** `dig @<pihole-ip> truenas +short` should return the IP you configured.
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
| `upstreamDns` | Upstream DNS (semicolon-separated, Pi-hole v6) | Google + `1.1.1.1` — see values.yaml |
| `customDnsmasqLines` | Static `address=/<host>.lan/<IP>` lines (keep aligned with **config/nodes**); init copies to `02-custom-lan.conf` on the PVC | See values.yaml |
| `clusterDnsSync` | Sidecar (`dns-sync`) lists **Nodes**, writes `03-k8s-nodes.conf` on the shared PVC, reloads Pi-hole when internal IPs change; requires RBAC on `nodes` | `enabled: true` — see values.yaml |

**clusterDnsSync** uses `shareProcessNamespace: true` so the sidecar can run `chroot /proc/<pihole-FTL-pid>/root pihole restartdns` after updating dnsmasq snippets. Cluster node names resolve as `<node>.<localDomain>` (default `lan`); `03-k8s-nodes.conf` overrides static lines in `02-custom-lan.conf` for the same hostname when the API reports a new IP.

Disable with `clusterDnsSync.enabled: false` if you do not want the sidecar or in-cluster RBAC.

## Uninstall

```bash
helm uninstall pihole
# PVC is left behind; delete if desired:
kubectl delete pvc pihole-data
```
