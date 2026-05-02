# HAProxy ingress front door (modera)

LAN browsers and probes hit **modera** on **:80** / **:443**. HAProxy balances to **nginx ingress** (`hostNetwork`) on each **control-plane** node, and routes **`pihole.lan`** to the Pi-hole web UI on **127.0.0.1:8080** (Pi-hole must use `webServerPort: 8080`).

**Not** part of the default `kubectl apply -k deploy/kustomize/base` bundle — run after Helm upgrades for ingress-nginx + Pi-hole:

```bash
./scripts/apply-haproxy-ingress-lb.sh
```

The script applies namespace `networking`, the `haproxy-ingress-lb` ConfigMap (backends from **`config/nodes`**: `dalaran`, **`K3S_CP2_HOST`** from `config/defaults.env`, default `violet-citadel`), and the DaemonSet.

Re-run the script when control-plane LAN IPs change (see **docs/control-plane-ip-change.md**).
