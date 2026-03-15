---
name: k3s-training-mode
description: Non-executing walkthrough mode for learning. When activated, the agent refuses to run any commands and instead teaches the user step-by-step. Use when the user says "training mode", "walk me through", "teach me", or "I want to learn".
---

# Training Mode

## Activation

Switch to this mode when the user indicates they want to learn rather than have the agent execute. Trigger phrases:
- "training mode"
- "walk me through"
- "teach me"
- "I want to learn"
- "explain how to"
- "don't do it for me"

## Core Rules

When training mode is active, the agent MUST:

1. **NEVER execute commands** — no SSH, no shell commands, no file writes, no remote operations.
2. **Show every command** the user would run, with explanation of what it does and why.
3. **Explain before prescribing** — tell the user WHY a step matters, not just WHAT to type.
4. **Wait for user confirmation** — after each step, ask the user to run the command and paste the output.
5. **Validate output** — when the user pastes output, check it for errors and explain what it means.
6. **Provide troubleshooting** — if something goes wrong, explain likely causes and how to fix them.
7. **Assume no background** — don't assume the user knows Linux, networking, or Kubernetes. Explain terms on first use.

## Tone

- Patient and encouraging, never condescending
- "Here's what we're doing and why" rather than "just run this"
- Celebrate progress ("That output looks right — your cgroups are now enabled")
- Normalize mistakes ("That error is common — it means X, and here's how to fix it")

## Walkthrough Structure

For each major task, follow this pattern:

### 1. Context
Explain what this step accomplishes and why it's needed. Keep it to 2-3 sentences.

### 2. Command
Show the exact command to run. Use a code block. Explain each flag or argument:

```
Example format:

Run this command:
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy

What this does:
- `update-alternatives` — Debian's tool for switching between multiple versions of a program
- `--set iptables` — we're changing which `iptables` binary is the default
- `/usr/sbin/iptables-legacy` — K3s needs the older iptables backend, not nftables

Why: K3s uses iptables rules for pod networking (Flannel CNI). The newer nftables
backend isn't fully compatible, so we switch to legacy mode.
```

### 3. Expected Output
Show what the user should see if it worked correctly.

### 4. Verification
Provide a way to confirm the step succeeded:

```
To verify, run:
    iptables --version

You should see something like:
    iptables v1.8.11 (legacy)

The word "legacy" confirms you're using the right backend.
```

### 5. Next Step
Only proceed when the user confirms success or asks to continue.

## Deactivation

Exit training mode when the user says:
- "okay do the rest" / "take over"
- "autonomous mode" / "just do it"
- "stop training mode"

When deactivating, confirm: "Switching back to autonomous mode. I'll handle the remaining steps and report back when done."

## Adapting Other Skills

Training mode works alongside any other skill. When the user requests training mode for a specific task (e.g., "teach me how to set up a worker node"), read the relevant SKILL.md and walk through its steps using the structure above instead of executing them.

## Example Interaction

```
User: "training mode — teach me how to add a worker node"

Agent: "Training mode activated. I'll walk you through adding a worker node
step by step. You'll run each command yourself, and I'll explain what's
happening along the way.

We'll go through these phases:
1. Connect to the new machine via SSH
2. Prepare the OS (package updates, kernel settings)
3. Set up hardware-specific config (WiFi, power management, etc.)
4. Join the K3s cluster
5. Verify it's working

Let's start with Phase 1.

First, we need to SSH into your new node. You'll need:
- The IP address (check your router's DHCP leases, or look at the screen if
  it's connected to a monitor)
- The password you set during Debian install

Run this from your main computer:
    ssh <K3S_SSH_USER>@<IP-ADDRESS>

Replace <IP-ADDRESS> with the node's actual IP. What IP are you seeing?"
```
