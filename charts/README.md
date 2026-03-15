# Charts

All committed charts here are **templates** — safe for public repo. Real values live in **config/helm-values/** (gitignored).

- **homelab-showcase/** — Main showcase chart: minimal echo app demonstrating nodeSelector, local-path, ingress.
- **homelab-showcase/charts/pihole/** — Pi-hole template (hostNetwork, single-node, custom DNS). Install with: `helm upgrade --install pihole ./charts/homelab-showcase/charts/pihole -f config/helm-values/pihole.yaml`

Upstream charts (kube-prometheus-stack, Loki, ingress-nginx) are used via Helm repos; their values live in **monitoring/** and **ingress/** (and overrides in **config/helm-values/**).
