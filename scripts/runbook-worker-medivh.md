# Runbook: Add medivh as K3s worker

Run from a machine that can reach **192.168.1.217** (e.g. your laptop on the same LAN, or from dalaran). From repo root, source config first:

```bash
cd /path/to/k3s
source config/defaults.env && [ -f config/project.env ] && source config/project.env
MEDIVH_IP=192.168.1.217
```

---

## 1. SSH test

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@$MEDIVH_IP" "hostname && uname -m"
# Expect: medivh, aarch64 (Pi)
```

## 2. Detect hardware (confirm SBC)

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$MEDIVH_IP" "uname -m; ls /sys/class/power_supply/BAT* 2>/dev/null || true; cat /proc/device-tree/model 2>/dev/null || true"
# aarch64 + no BAT = SBC (Pi). Proceed with SBC steps.
```

## 3. Non-free repos + update

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$MEDIVH_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S bash -c 'sed -i \"s/main non-free-firmware/main contrib non-free non-free-firmware/g\" /etc/apt/sources.list && apt update && apt upgrade -y'"
```

## 4. Cgroups (Pi: cmdline.txt, not GRUB)

Check which cmdline exists, then append cgroup args:

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$MEDIVH_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S bash -c 'grep -q cgroup_enable /boot/firmware/cmdline.txt 2>/dev/null || sed -i \"s/\$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/\" /boot/firmware/cmdline.txt; grep -q cgroup_enable /boot/cmdline.txt 2>/dev/null || sed -i \"s/\$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/\" /boot/cmdline.txt'"
```

## 5. iptables-legacy + curl

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$MEDIVH_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S bash -c 'apt install -y iptables curl && update-alternatives --set iptables /usr/sbin/iptables-legacy && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy'"
```

## 6. Reboot (required for cgroups)

```bash
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$MEDIVH_IP" "echo \"$K3S_NODE_PASSWORD\" | sudo -S reboot"
# Wait 1–2 minutes, then:
sshpass -p "$K3S_NODE_PASSWORD" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$K3S_SSH_USER@$MEDIVH_IP" "cat /proc/cmdline | grep cgroup"
```

## 7. Get join token from control plane

```bash
K3S_TOKEN=$(ssh "$K3S_SSH_USER@$K3S_CP_HOST" "cat $K3S_NODE_TOKEN_PATH")
echo "Token retrieved (length ${#K3S_TOKEN})"
```

## 8. Join cluster (run on medivh)

```bash
K3S_URL="https://${K3S_CP_IP}:${K3S_API_PORT}"
sshpass -p "$K3S_NODE_PASSWORD" ssh "$K3S_SSH_USER@$MEDIVH_IP" "curl -sfL $K3S_INSTALL_URL | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sudo sh -"
```

## 9. Label node (from control plane)

```bash
./scripts/ssh-node.sh dalaran 'sudo k3s kubectl label node medivh node-role.kubernetes.io/worker=worker'
```

## 10. Verify

```bash
./scripts/ssh-node.sh dalaran 'sudo k3s kubectl get nodes -o wide'
# medivh should be Ready, role worker
```

## 11. Update config/nodes and docs

- Ensure **config/nodes** has: `medivh 192.168.1.217` (remove the "medivh (sandbox) not in cluster" comment if present)
- Run: `./scripts/ssh-config-from-nodes.sh` and update your `~/.ssh/config` K3s block if needed
- Create **nodes/medivh-<model>.md** (e.g. `nodes/medivh-pi4.md`) from the changelog template in AGENTS.md; fill Hardware Snapshot from step 2 and any `lscpu`/`lsblk`/`ip link` output from medivh
- Update **nodes/roadmap.md** inventory table

---

If medivh gets a new IP after reboot (e.g. DHCP), run `nmap -sn $K3S_SCAN_SUBNET` to find it and update config/nodes.
