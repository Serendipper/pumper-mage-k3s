# Charts

All committed charts and chart **values YAML** elsewhere in the repo (**monitoring/**, **ingress/**) are **templates** only — safe for public repo. **Every** Helm install/upgrade uses **`-f config/helm-values/<file>.yaml`** (gitignored). Template → live filename mapping: **config/README.md** § *Helm: templates vs live values*.

- **homelab-showcase/** — Showcase chart template. Live: `config/helm-values/homelab-showcase.yaml` (copy from `charts/homelab-showcase/values.yaml` if you use it).
- **homelab-showcase/charts/pihole/** — Pi-hole template. Live: `config/helm-values/pihole.yaml`. Install: `helm upgrade --install pihole ./charts/homelab-showcase/charts/pihole -f config/helm-values/pihole.yaml`

Upstream charts (kube-prometheus-stack, Loki, Promtail, ingress-nginx) install from Helm repos; their templates sit under **monitoring/** and **ingress/**; **live** files are **`config/helm-values/prometheus-stack.yaml`**, **`loki.yaml`**, **`promtail.yaml`**, **`ingress-nginx.yaml`**.
