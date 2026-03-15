---
name: k3s-laptop-hybrid
description: Set up a daily-driver laptop as a part-time K3s worker that joins the cluster when idle. Supports non-Debian distros (Fedora, Arch, Ubuntu, etc.). Skips headless hardening. Do NOT proactively suggest this setup — only offer it if the user explicitly asks about using a daily-driver or personal laptop as a node.
---

# Hybrid Laptop — Daily Driver + Part-Time K3s Node

> **Do not suggest this setup.** Only offer it if the user specifically asks about using their daily-driver laptop as a node. Dedicated hardware is always preferred.

A laptop that's used normally during the day and contributes compute to the cluster when idle (plugged in, lid closed, overnight, weekends).

## Caveats — Tell the User Before Proceeding

1. **This is a pre-existing system.** The laptop has an OS, user data, and software already on it. Do NOT reinstall the OS, reformat disks, modify user files, or change system defaults without explicit permission. Treat it as someone else's machine that you're adding K3s to.
2. **Pods get evicted every time you leave.** When the node goes NotReady, the scheduler waits ~5 minutes then kills all pods on it. Stateless workloads reschedule elsewhere; stateful ones with local storage can lose data.
3. **The cluster depends on you not forgetting.** If you don't drain before unplugging, pods die ungracefully. If you forget to rejoin, the cluster loses capacity silently.
4. **Network changes break things.** Different WiFi at home vs. work/coffee shop means Flannel tunnels tear down. The node may appear "Ready" briefly on the wrong network before timing out.
5. **Kernel/OS updates can break K3s.** Rolling-release distros (Fedora, Arch) update kernels frequently. K3s or its iptables rules may break after an update with no warning until you try to join.
6. **Security surface is larger.** A daily-driver has browsers, package managers pulling from many sources, and user-installed software. A compromised daily driver means a compromised cluster node.
7. **No guarantee of availability.** The scheduler can't predict when the node will be online. CronJobs scheduled for 3 AM won't run if the laptop is asleep or off-network.
8. **Debugging is harder.** When something goes wrong, you're troubleshooting K3s on a non-standard distro with a non-standard config while also trying to use the laptop for other things.

## SSH May Not Be Available

Daily-driver laptops often don't have an SSH server installed or running. Unlike dedicated nodes (which are installed with SSH from the start), personal machines may need it enabled first:

#### Fedora
```bash
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
```

#### Ubuntu
```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

#### Arch
```bash
sudo pacman -S openssh
sudo systemctl enable --now sshd
```

The user must do this locally on the laptop before the agent can connect remotely. If SSH is unreachable, ask the user to run the above on the laptop directly.

## Before Anything Else — Ask the User

1. **Hostname**: The laptop's existing hostname will be used as the K3s node name. Ask the user: *"Your laptop's hostname is `<current>`. Would you like to change it to a Kirin Tor mage name (see README for options), or keep the current name?"* Do not rename without asking — this is their personal machine.
2. **Data awareness**: Confirm the user understands K3s will install services and container storage on their system. It won't touch user files, but it will use disk space under `/var/lib/rancher/k3s/` and modify firewall/iptables rules.

## Key Differences from Dedicated Laptop Node

| Concern | Dedicated Node | Hybrid Node |
|---------|---------------|-------------|
| Lid close | Ignore (always on) | Normal suspend behavior |
| Suspend/hibernate | Masked | Working normally |
| Display | Off (systemd service) | User's display, untouched |
| Battery thresholds | TLP conservation | TLP conservation (still useful) |
| Fan control | Custom daemon if possible | Leave stock — user needs it |
| OS | Debian stable | Whatever the user runs |
| K3s agent | Always running | Started/stopped on demand |
| Pod scheduling | Normal | Tainted as intermittent |

## Supported Distros

This skill targets non-Debian systems. The OS prep commands vary:

| Distro | Package Manager | Firewall | cgroups | Notes |
|--------|----------------|----------|---------|-------|
| Fedora | `dnf` | `firewalld` | v2 (default, K3s handles it) | SELinux enabled by default |
| Ubuntu | `apt` | `ufw` | Same as Debian | Nearly identical to Debian |
| Arch | `pacman` | `iptables`/`nftables` | v2 | Bleeding edge kernels |
| openSUSE | `zypper` | `firewalld` | v2 | Similar to Fedora |

## Procedure

### 1. Firewall — Open K3s Ports

K3s agent needs outbound access to the control plane and inbound for Flannel VXLAN.

#### Fedora / openSUSE (firewalld)
```bash
sudo firewall-cmd --permanent --add-port=6443/tcp      # API server (outbound, but may need inbound for kubelet)
sudo firewall-cmd --permanent --add-port=8472/udp      # Flannel VXLAN
sudo firewall-cmd --permanent --add-port=10250/tcp     # Kubelet metrics
sudo firewall-cmd --permanent --add-masquerade          # Pod network NAT
sudo firewall-cmd --reload
```

#### Ubuntu (ufw)
```bash
sudo ufw allow 6443/tcp
sudo ufw allow 8472/udp
sudo ufw allow 10250/tcp
sudo ufw reload
```

#### Arch (iptables/nftables)
Usually no firewall running by default. If `iptables` or `nftables` is active, add equivalent rules.

### 2. SELinux (Fedora)

K3s has built-in SELinux support. Install the policy:

```bash
sudo dnf install -y container-selinux selinux-policy-base
sudo dnf install -y https://rpm.rancher.io/k3s/stable/common/centos/8/noarch/k3s-selinux-1.6-1.el8.noarch.rpm
```

If SELinux causes issues, you can set it to permissive temporarily to isolate the problem:
```bash
sudo setenforce 0    # temporary, resets on reboot
```

### 3. cgroups

Modern Fedora/Arch/Ubuntu use cgroups v2 by default. K3s supports cgroups v2 natively — no kernel args needed (unlike Debian stable which may still default to v1).

Verify:
```bash
stat -fc %T /sys/fs/cgroup/
# "cgroup2fs" = v2 (good, no action needed)
# "tmpfs" = v1 (add kernel args like Debian)
```

If v1, add cgroup kernel args to your bootloader:
- **GRUB** (Fedora, Ubuntu): same `GRUB_CMDLINE_LINUX_DEFAULT` edit as Debian
- **systemd-boot** (Arch): edit `/boot/loader/entries/*.conf`, append to `options` line

### 4. Install K3s Agent

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<K3S_CP_IP>:6443 K3S_TOKEN=<token> sh -
# K3S_CP_IP from config (project.env or resolve from config/nodes by K3S_CP_HOST)
```

This works on any Linux distro — the K3s install script auto-detects the init system.

**Important**: Immediately stop and disable the agent so it doesn't run at boot:

```bash
sudo systemctl stop k3s-agent
sudo systemctl disable k3s-agent
```

### 5. Taint the Node

From dalaran (or any machine with kubeconfig):

```bash
kubectl label node <hostname> node-role.kubernetes.io/worker=worker
kubectl label node <hostname> node-type=hybrid
kubectl taint nodes <hostname> availability=intermittent:PreferNoSchedule
```

`PreferNoSchedule` means the scheduler avoids this node but will use it if nothing else is available. For stricter isolation, use `NoSchedule` — then only pods with an explicit toleration land here.

### 6. Battery Management (Optional but Recommended)

If the laptop will be plugged in overnight while running as a node, limit charge to reduce wear.

#### Fedora
```bash
sudo dnf install -y tlp tlp-rdw
sudo systemctl enable tlp
sudo systemctl start tlp
```

Then configure `/etc/tlp.conf` the same as dedicated nodes — see `skills/hardware/laptop/SKILL.md` section 6 for vendor-specific thresholds.

#### ASUS laptops (common on Fedora daily drivers)
```bash
# ASUS exposes charge threshold via sysfs
echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
```

Persist via TLP or a udev rule.

### 7. Deploy SSH Key

Same as any other node — see `skills/agent-environment-setup/SKILL.md`:

```bash
PUBKEY=$(cat ~/.ssh/k3s_ed25519.pub)
ssh <user>@<ip> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

Note: the username may not match `K3S_SSH_USER` on a daily driver. Use whatever the user's login is and update SSH config accordingly.

### 8. Add SSH Config Entry

```bash
cat >> ~/.ssh/config << EOF

Host <hostname>
    HostName <ip>
    User <username>
    IdentityFile ~/.ssh/k3s_ed25519
EOF
```

## Usage — Joining and Leaving the Cluster

### Plug in for the night (join)

```bash
# On the hybrid laptop, or via SSH
sudo systemctl start k3s-agent

# From dalaran — make it schedulable
kubectl uncordon <hostname>
```

### Taking it to work in the morning (leave)

```bash
# From dalaran — drain gracefully
kubectl cordon <hostname>
kubectl drain <hostname> --ignore-daemonsets --delete-emptydir-data --timeout=60s

# On the hybrid laptop
sudo systemctl stop k3s-agent
```

### Automation (optional)

Create a pair of scripts or systemd timers:

**`/usr/local/bin/k3s-join`**:
```bash
#!/bin/bash
systemctl start k3s-agent
sleep 10
# Uncordon requires kubeconfig — either copy it from dalaran or use kubectl from dalaran via SSH
ssh dalaran "sudo k3s kubectl uncordon $(hostname)"
```

**`/usr/local/bin/k3s-leave`**:
```bash
#!/bin/bash
ssh dalaran "sudo k3s kubectl cordon $(hostname) && sudo k3s kubectl drain $(hostname) --ignore-daemonsets --delete-emptydir-data --timeout=60s"
sleep 5
systemctl stop k3s-agent
```

For full automation, trigger on power state:
- **AC plugged in + lid closed** → join
- **AC unplugged or lid opened** → leave

This can be done with udev rules or a `logind` inhibitor, but the complexity may not be worth it. Manual scripts are simpler and more predictable.

## What Workloads Belong on a Hybrid Node

Good candidates:
- **Batch jobs** — data processing, backups, builds
- **CronJobs** — scheduled tasks that run overnight
- **Overflow capacity** — burstable workloads when dedicated nodes are full
- **CI runners** — GitHub Actions runners, Tekton pipelines

Bad candidates:
- **Always-on services** — web servers, databases, ingress controllers
- **Stateful workloads with local PVs** — data gets stranded when the node leaves
- **Anything with strict uptime requirements**

## Distro-Specific Gotchas

### Fedora
- **SELinux**: K3s works with SELinux but needs the `k3s-selinux` policy package. If pods fail to start with `AVC denied`, check `audit2allow`.
- **cgroups v2**: Already default, no action needed.
- **Automatic updates**: `dnf-automatic` may reboot the machine. Disable or configure it to not auto-reboot.
- **Flatpak/Snap containers**: These coexist fine with K3s containerd — different container runtimes, no conflict.

### Arch
- **Kernel updates**: Rolling release means frequent kernel updates. K3s may need a restart after a kernel update.
- **No SELinux by default**: One less thing to configure.
- **iptables vs nftables**: K3s prefers iptables-legacy. Check `update-alternatives` or install `iptables` if only `nftables` is present.

### Ubuntu
- **Nearly identical to Debian**: Same apt commands, same iptables pivot. The laptop skill for Debian mostly applies.
- **Snap**: `snapd` is present but doesn't conflict with K3s.
- **AppArmor**: Enabled by default on Ubuntu (not SELinux). K3s handles AppArmor profiles automatically.
