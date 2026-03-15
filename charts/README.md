# Charts

- **homelab-showcase/** — Example chart demonstrating this project’s patterns (nodeSelector, local-path, ingress). Safe for public repo. Real values live in **config/helm-values/** (gitignored).

Upstream charts (kube-prometheus-stack, Loki, ingress-nginx) are used via Helm repos; their values live in **monitoring/** and **ingress/** (and overrides in **config/helm-values/**).
