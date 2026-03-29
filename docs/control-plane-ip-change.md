# Control plane LAN IP changed (dalaran)

Use this checklist when **dalaran** (or whatever hosts the API / ingress) gets a **new IPv4** on the LAN.

1. **`config/nodes`** — Update the `dalaran` line to the new address (gitignored).

2. **Pi-hole** — In **`charts/.../pihole/values.yaml`** (and live **`config/helm-values/pihole.yaml`**), update **every** **`address=/.../<ip>`** line that pointed at the **old** control-plane / ingress IP — e.g. **`dalaran`** (short name), **`dalaran.lan`**, **`dalaran.plex`**, **`grafana.lan`**, **`openclaw.dalaran.lan`**, **`dalaran.sonarr`**, **`dalaran.radarr`**, etc. Hosts that are **not** on dalaran (e.g. **`truenas`**, extra static names for an operator laptop) stay unchanged unless their IPs moved.

3. **Deploy Pi-hole** — From repo root, with a working kubeconfig:
   `helm upgrade --install pihole ./charts/homelab-showcase/charts/pihole -f config/helm-values/pihole.yaml`
   (or `-f charts/.../values.yaml` if you have no live overlay).

4. **Kubeconfig API URL** — **`config/defaults.env`** (`K3S_CP_API_HOST`) and the local **`server:`** in `~/.kube/config*` should still reach the API (hostname or new IP). If the TLS SAN on k3s does not include the new IP, add it and restart k3s on the server, or use a name that is already in the cert.

5. **Comments** — Grep the repo for the old IP (e.g. `192.168.1.x`) and update **comments** in YAML you care about (`deploy/kustomize/base/storage/*`, node docs, etc.).

6. **Node changelog** — **`control-plane/dalaran-*.md`** if you track IP history there.

After Pi-hole picks up the new values, **`dig @<pihole-node-ip> dalaran`** and **`dig @<pihole-node-ip> dalaran.lan`** should return the new control-plane IP.
