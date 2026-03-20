---
name: agent-environment-setup
description: One-time setup for the agent's local environment before deploying K3s nodes. Generates project SSH keys, configures SSH config, installs local tools, and deploys keys to nodes. Use when starting fresh or onboarding a new machine to manage the cluster.
---

# Agent Environment Setup

One-time setup on the machine where the agent runs (e.g., WSL, a management laptop). This creates the SSH infrastructure that all other skills depend on. All node lists and defaults come from **config/** (see `skills/project-setup/SKILL.md`).

## Prerequisites

- The agent runs on a Linux-like environment (WSL, native Linux, macOS)
- At least one node is reachable via `sshpass` + password for initial key deployment
- **Recommended:** Run **project-setup** first (`skills/project-setup/SKILL.md`) so `config/project.env` has username, password, and key path. Scripts source `config/defaults.env` then `config/project.env`.

## 1. Generate Project SSH Key

Create a dedicated ed25519 key. Key path comes from `config/defaults.env` (`K3S_SSH_KEY`) or `config/project.env`:

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
ssh-keygen -t ed25519 -f "$KEY" -N "" -C "k3s-homelab"
```

If the key already exists, skip this step.

## 2. Install Local Tools

```bash
# Debian/Ubuntu
sudo apt install -y sshpass nmap curl jq

# macOS
brew install hudochenkov/sshpass/sshpass nmap curl jq
```

- `sshpass` — initial password-based SSH before keys are deployed
- `nmap` — network scanning; subnet is in `config/defaults.env` (`K3S_SCAN_SUBNET`), e.g. `nmap -sn $K3S_SCAN_SUBNET`
- `curl` — K3s install script, health checks
- `jq` — parse `kubectl -o json` and API output; useful for autonomous agent logic

## 3. SSH Config

Generate entries from **config/nodes** and append to `~/.ssh/config`:

```bash
./scripts/ssh-config-from-nodes.sh >> ~/.ssh/config
chmod 600 ~/.ssh/config
```

The script reads `config/nodes` (hostname + IP per line) and `config/defaults.env` / `config/project.env` for user and key path. No hardcoded host list.

## 4. Deploy Public Key to a Node

For a single node (after OS install, before key is deployed), source config and use its IP from **config/nodes**:

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
KEY="${K3S_SSH_KEY:-$HOME/.ssh/k3s_ed25519}"
PUBKEY=$(cat "${KEY}.pub")
sshpass -p "${K3S_NODE_PASSWORD}" ssh -o StrictHostKeyChecking=accept-new "${K3S_SSH_USER}@<ip>" \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

Ensure `K3S_NODE_PASSWORD` and `K3S_SSH_USER` are set in `config/project.env`.

### Batch Deploy to All Nodes

From repo root (reads **config/nodes** and **config/project.env**):

```bash
./scripts/deploy-keys-to-nodes.sh
```

Requires `K3S_NODE_PASSWORD` and `K3S_SSH_KEY` in `config/project.env`.

## 5. Verify

```bash
./scripts/ssh-node.sh <hostname> hostname
# or, if SSH config is populated: ssh <hostname> hostname
```

Use any hostname from **config/nodes**.

## 6. Add New Node

1. Add one line to **config/nodes**: `hostname IP`
2. Append SSH config: `./scripts/ssh-config-from-nodes.sh >> ~/.ssh/config` (or replace the K3s block with fresh output)
3. Deploy key: run the single-node command above with the new IP, or run `./scripts/deploy-keys-to-nodes.sh` to deploy to all (including the new one)

## 7. Cluster access (helm / kubectl) — recommended

Installing helm and kubectl locally and pointing them at the cluster lets the agent run cluster commands (e.g. `helm upgrade`, `kubectl get nodes`) without SSHing to the control plane. Do this on the same machine where the agent runs.

**Install tools:**

```bash
# Debian/Ubuntu
sudo apt install -y helm kubectl

# Or get latest helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Get kubeconfig from the control plane:**

On the control plane, the kubeconfig is `/etc/rancher/k3s/k3s.yaml`. Copy it to this machine and replace `127.0.0.1` with the control plane IP so the API server is reachable. Use **config** `K3S_CP_IP` or resolve from **config/nodes** by `K3S_CP_HOST`; do not hardcode IPs.

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
ssh "$K3S_CP_HOST" "sudo cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/$K3S_CP_IP/g" > ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config
# Optional: make it default for your user
echo 'export KUBECONFIG=~/.kube/k3s-config' >> ~/.bashrc
```

**Verify:**

```bash
kubectl get nodes
helm list -A
```

Once this is done, the agent will use local helm/kubectl for cluster changes when available (see `docs/agents.md`).

## 8. Full install (all-in-one)

Run from repo root. **Prerequisite:** **project-setup** done (`config/project.env` exists with `K3S_SSH_USER`, `K3S_NODE_PASSWORD`, `K3S_CP_IP`, `K3S_CP_HOST`). Control plane must be reachable (SSH) for the kubeconfig step.

**Debian / Ubuntu / WSL:**

```bash
# 1. Install all tools
sudo apt update
sudo apt install -y sshpass nmap curl jq helm kubectl

# 2. Kubeconfig (replace 127.0.0.1 with CP IP so API is reachable)
source config/defaults.env && [ -f config/project.env ] && source config/project.env
mkdir -p ~/.kube
P="$K3S_NODE_PASSWORD"
sshpass -p "$P" ssh -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@$K3S_CP_IP" "echo $P | sudo -S cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/${K3S_CP_IP}/g" > ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config
echo 'export KUBECONFIG=~/.kube/k3s-config' >> ~/.bashrc

# 3. Verify cluster access
kubectl get nodes
helm list -A
```

**macOS:**

```bash
# 1. Install all tools
brew install hudochenkov/sshpass/sshpass nmap curl jq
brew install helm kubectl

# 2. Kubeconfig
source config/defaults.env && [ -f config/project.env ] && source config/project.env
mkdir -p ~/.kube
P="$K3S_NODE_PASSWORD"
sshpass -p "$P" ssh -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@$K3S_CP_IP" "echo $P | sudo -S cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/${K3S_CP_IP}/g" > ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config
echo 'export KUBECONFIG=~/.kube/k3s-config' >> ~/.bashrc

# 3. Verify
kubectl get nodes
helm list -A
```

Then: generate SSH key (§1) if needed, run `./scripts/ssh-config-from-nodes.sh >> ~/.ssh/config`, and deploy keys (§4) to nodes. Ensure the agent host has **network access** to the cluster subnet (SSH to nodes; API at `$K3S_CP_IP:6443` for kubectl/helm).

## Integration with Other Skills

Once this setup is complete, other skills use `./scripts/ssh-node.sh <hostname> '<cmd>'` (reads **config/nodes** and config) or `ssh <hostname>` if your SSH config is populated. All credentials and defaults come from **config/**.

When adding a new node to the cluster, the agent should:
1. Add the node to **config/nodes**
2. Deploy the key (single-node or batch script)
3. Optionally append SSH config via `ssh-config-from-nodes.sh`
