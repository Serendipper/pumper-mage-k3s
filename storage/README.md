# NFS storage (TrueNAS)

Shared storage for the cluster via NFS exports on TrueNAS. Used for configs, backups, and (optionally) an existing media dataset.

## Kubernetes manifests (PVs, PVCs, media ingress)

**Canonical location:** `deploy/kustomize/base/storage/` (Plex, NFS PV/PVC, media Ingress, OpenClaw gateway, TrueNAS *arr Services). Apply **everything** first-party in one step:

```bash
kubectl apply -k deploy/kustomize/base
```

Details: **`deploy/kustomize/README.md`**. Helm charts (monitoring, ingress-nginx, Pi-hole, …) stay separate: `helm upgrade -f config/helm-values/...`.

## What we did

### 1. TrueNAS datasets (ZFS)

Created on **ssd_pool**:

| Dataset | Purpose | Quota |
|---------|---------|-------|
| `ssd_pool/k3s` | Parent container | none |
| `ssd_pool/k3s/configs` | Shared configs for K3s pods | 20 GiB |
| `ssd_pool/k3s/backups` | Backup target from cluster | 100 GiB (adjust to your space) |

**Dataset settings (all three):**

- **Type:** Filesystem  
- **Compression:** lz4  
- **atime:** off (in Advanced options)  
- **ZFS Deduplication:** off  
- **Sync:** Standard  

Quota only on the two children; parent has no quota.

**Media:** Use an existing media dataset on TrueNAS; add an NFS share for it when you want pods to use it.

### 2. NFS shares (TrueNAS)

Two shares, one per dataset. **Path** = dataset mount path (e.g. `/mnt/ssd_pool/k3s/configs`).

| Share | Path | Comment |
|-------|------|---------|
| configs | `/mnt/ssd_pool/k3s/configs` | k3s configs |
| backups | `/mnt/ssd_pool/k3s/backups` | k3s backups |

**Per-share settings:**

- **Allowed hosts:** Your LAN subnet (e.g. from config `K3S_SCAN_SUBNET` or match your network)  
- **Security:** sys  
- **Read only:** unchecked  
- **Maproot User:** root  
- **Maproot Group:** wheel  

Enable the NFS service (Services → NFS → Running).

### 3. Verification

From a cluster node (e.g. dalaran) with `nfs-common` installed:

```bash
sudo mkdir -p /tmp/mnt-configs /tmp/mnt-backups
# NAS host from config (K3S_DATASTORE_URL or your NFS server)
sudo mount -t nfs &lt;NAS_IP&gt;:/mnt/ssd_pool/k3s/configs /tmp/mnt-configs
sudo mount -t nfs &lt;NAS_IP&gt;:/mnt/ssd_pool/k3s/backups /tmp/mnt-backups
touch /tmp/mnt-configs/hello && touch /tmp/mnt-backups/hello
ls -la /tmp/mnt-configs /tmp/mnt-backups
sudo umount /tmp/mnt-configs /tmp/mnt-backups
```

Verified on dalaran (2025-03-14): both mounts and read/write succeeded.

### 4. K3s usage (PV/PVC)

The NFS exports are **not** created by the cluster. TrueNAS hosts them. To use them from pods:

- Define **PersistentVolume** objects that point at each NFS path (server from config / datastore host; path as above).
- Define **PersistentVolumeClaim**s that bind to those PVs (or use a StorageClass if you add an NFS provisioner later).
- Mount the PVC in pods via `volumes:` and `volumeMounts:`.

The kubelet on the node where the pod runs performs the NFS mount when the pod starts. No dynamic provisioning of the export itself — that stays on TrueNAS.

**Media / Plex on NFS:** see **`deploy/kustomize/base/storage/media-apps.yaml`** and apply the full first-party bundle with **`kubectl apply -k deploy/kustomize/base`**. For the **k3s/configs** and **k3s/backups** datasets above, add PV/PVC YAML under **`deploy/kustomize/base/storage/`** (or a Kustomize overlay) when you consume them from workloads.

## Reference

- **NAS IP:** From config (same host as K3s datastore in `K3S_DATASTORE_URL`; see `docs/agents.md`). Do not hardcode; use config/nodes or project.env.
- **NFS paths:** `/mnt/ssd_pool/k3s/configs`, `/mnt/ssd_pool/k3s/backups`
- **Nodes:** Ensure `nfs-common` is installed on any node that will run pods using these volumes (e.g. dalaran already has it).
