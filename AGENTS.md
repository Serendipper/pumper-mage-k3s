# AGENTS Compatibility Pointer

Canonical runbook content now lives in:

- `docs/agents.md`

**TrueNAS:** never SSH there (`ssh-node.sh`, `ssh`, `sshpass`, etc.). Not a cluster node; see `docs/agents.md` (SSH access) and `.cursor/rules/truenas-no-ssh.mdc`.

This file is intentionally minimal and kept only for compatibility with tools that still look for `AGENTS.md` at repo root.
