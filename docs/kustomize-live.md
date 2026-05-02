# Gitignored live Kustomize (`deploy/kustomize/live/private/`)

Published manifests under **`deploy/kustomize/base`** use **RFC 5737 / TEST-NET placeholders** for site-specific LAN IPs and **omit PersistentVolumes** (immutable NFS / hostPath). Kustomize **only** allows `resources` and `patches` from paths **under** the overlay directory, so live files must live in **`deploy/kustomize/live/private/`** (gitignored), not under **`config/`**.

The overlay **`deploy/kustomize/live`** builds:

1. **`../base`** — safe to push to GitHub  
2. **`private/media-pvs.yaml`** — real `PersistentVolume` specs  
3. **`patches` → `private/site.yaml`** — Endpoints (OpenClaw, TrueNAS *arr) and Plex `Probe` URL

## After clone

```bash
./scripts/init-kustomize-live.sh
```

Copies **`media-pvs.example.yaml`** and **`site.example.yaml`** into **`private/`** when missing. Edit NFS server, Plex `hostPath`, and LAN IPs before applying to a real cluster.

## Apply

```bash
./scripts/apply-cluster-manifests.sh
```

Uses **`kubectl apply -k deploy/kustomize/live`** when **both** `private/media-pvs.yaml` and `private/site.yaml` exist; otherwise **`kubectl apply -k deploy/kustomize/base`** only.

## Publishing to GitHub

**`.gitignore`** includes **`deploy/kustomize/live/private/`**. Committed templates: **`deploy/kustomize/base/storage/media-pvs.example.yaml`**, **`deploy/kustomize/live/site.example.yaml`**.

## Extending

Add patch documents to **`private/site.yaml`** or extra files under **`private/`** and reference them in **`deploy/kustomize/live/kustomization.yaml`**.
