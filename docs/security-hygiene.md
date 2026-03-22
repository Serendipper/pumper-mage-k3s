# Security hygiene (secrets + what may appear in git)

## Tooling

| Mechanism | Purpose |
|-----------|---------|
| **Gitleaks** | Scans commits for accidental **secrets** (API keys, tokens, private keys, many provider-specific patterns). Config: **`.gitleaks.toml`**. |
| **pre-commit** | Runs Gitleaks **before each commit** (local). Config: **`.pre-commit-config.yaml`**. |
| **GitHub Action** | Runs the **Gitleaks CLI** on **push/PR** to `main` (`.github/workflows/gitleaks.yml`) — downloads the official release binary (no third-party Action that requires an org license). |

### One-time setup (maintainer machine)

```bash
pip install pre-commit   # or: dnf install pre-commit / brew install pre-commit
cd /path/to/pumper-mage-k3s
pre-commit install
```

Smoke-test the whole tree:

```bash
pre-commit run --all-files
```

Manual run without pre-commit (requires [Gitleaks](https://github.com/gitleaks/gitleaks) installed):

```bash
gitleaks git -v
```

### When Gitleaks reports a false positive

1. Confirm it is **not** a real secret (rotate anything real immediately; do not allowlist real leaks).
2. Add a **narrow** `[[allowlist]]` entry to **`.gitleaks.toml`** (path or regex) with a **description** of why it is safe.
3. Re-run **`pre-commit run --all-files`**.

We are **not** using `detect-secrets` in addition to Gitleaks — one scanner keeps noise down. You can add it later if needed.

## Policy: LAN IPs, hostnames, and “identifying” infra

- **Gitleaks does not** treat RFC1918 IPs (`192.168.x.x`, `10.x`, etc.) or hostnames as credentials by default. They can still **fingerprint** your homelab if the repo is **public**.
- **Prefer** gitignored sources for **operator-specific** truth: **`config/nodes`**, **`config/project.env`**, **`config/helm-values/`** (see **`config/README.md`**).
- **Committed** YAML under **`deploy/kustomize/`**, chart **templates**, and **docs** may still contain **example** LAN IPs and cluster hostnames so the repo stays operable as a template — that is an intentional tradeoff for this project.

If you need a **fully sanitized** public fork, maintain a branch or fork that strips or replaces addresses (no automated tool in-repo for that yet).

## Never commit

- **`config/project.env`**, **`config/nodes`**, **`config/helm-values/`** — already **gitignored**; see **`docs/agents.md`**.
