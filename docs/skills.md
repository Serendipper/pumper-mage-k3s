# Skills index

Procedural skills live under `skills/*/SKILL.md`. **Cluster layout** → `docs/architecture.md`. **Current workloads and migration status** → `docs/state.md`.

## Core cluster

- `skills/project-setup/SKILL.md` — project secrets and local config.
- `skills/agent-environment-setup/SKILL.md` — local tooling and kube access.
- `skills/control-plane-setup/SKILL.md` — K3s server.
- `skills/worker-node-setup/SKILL.md` — workers; dispatches hardware skills.

## Hardware

- `skills/hardware/laptop/SKILL.md` — dedicated laptop node.
- `skills/hardware/laptop-hybrid/SKILL.md` — part-time daily-driver node.
- `skills/hardware/desktop/SKILL.md` — desktop nodes.
- `skills/hardware/sbc/SKILL.md` — SBC / Pi.

## Platform

- `skills/ingress-nginx-setup/SKILL.md` — ingress.
- `skills/monitoring-stack-setup/SKILL.md` — Prometheus + Grafana.
- `storage/README.md` — NFS PV/PVC patterns.
- `docs/control-plane-ip-change.md` — when dalaran’s LAN IP changes (Pi-hole, kubeconfig, nodes file).

## Learning mode

- `skills/training-mode/SKILL.md` — non-executing walkthrough.
