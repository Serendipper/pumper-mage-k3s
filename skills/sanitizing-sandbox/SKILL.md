---
name: k3s-sanitizing-sandbox
description: Set up a Raspberry Pi as a dedicated USB sanitization sandbox — USB SSD boot, minimal OS, and safe wipe workflow for USB sticks. Use when staging or maintaining the medivh (or any Pi) sandbox; not for K3s worker deployment.
---

# Sanitizing Sandbox Setup

A **sandbox** Pi (medivh) runs a minimal OS and serves two roles: (1) **sanitizing** USB sticks (wipe before reuse) and (2) **staging** boot media for other Pis — it holds the Raspberry Pi OS image and writes it to USB sticks/SSDs. It does not join the K3s cluster. Boot medivh from USB SSD to avoid SD card wear; use the project script for safe, removable-only wiping. Image download and USB writes run on medivh; see `downloads/README.md`.

## Prerequisites

- Raspberry Pi 4 or 5 (USB boot supported natively).
- Known IP (e.g. from network scan: `nmap -sn $K3S_SCAN_SUBNET` with **config/defaults.env** sourced, or see **config/nodes**).
- SSH access (password or project key). User and key from **config/** (see `AGENTS.md`).

**Staging first-boot:** When writing Pi OS to a stick for another node, generate WiFi network config from project config: `./scripts/render-pi-firstboot-network.sh` → use `config/generated/pi-firstboot-network.yaml` as cloud-init `network-config`. See `downloads/README.md`.

## Procedure

### 1. USB SSD boot migration

**1.1 Confirm USB boot**  
From current SD boot:

```bash
vcgencmd otp_dump | grep 17
```

If line 17 ends in `6` or `7`, USB boot is already enabled. Otherwise one-time enable:

```bash
echo "program_usb_boot_mode=1" | sudo tee -a /boot/config.txt
sudo reboot
# After reboot, remove the line from /boot/config.txt (one-time only).
```

**1.2 Image to USB SSD**

- Plug USB SSD into the Pi (or use another machine with USB adapter).
- **Option A — Fresh install:** Use Raspberry Pi Imager, choose “Raspberry Pi OS Lite (64-bit)”, target = USB SSD. In Imager settings set hostname (e.g. `medivh`), user matching `K3S_SSH_USER` (e.g. `serendipper`), enable SSH.
- **Option B — Clone from SD:** Clone rootfs to SSD (e.g. `rsync -ax / /mnt/ssd/` after partitioning and mounting the SSD), then expand partition, update `/boot/firmware/cmdline.txt` (or `/boot/cmdline.txt`) and `/etc/fstab` to use SSD partition by UUID/label so the next boot can be from USB.

**1.3 Boot from USB**

- Power off, remove SD card, leave only USB SSD connected.
- Power on. Confirm root is on USB: `findmnt /` and `lsblk` show root on the USB disk.

**1.4 Optional: tmpfs for /var/log**

If you keep an SD for other storage or want to limit log writes on any remaining flash:

```bash
echo "tmpfs /var/log tmpfs defaults,noatime,size=100M 0 0" | sudo tee -a /etc/fstab
sudo mount -a
```

### 2. OS baseline for sandbox

- Minimal install: SSH server + standard utilities only. No K3s, no cgroups/iptables-legacy required for sandbox role.
- Set hostname (if not set by Imager): `sudo hostnamectl set-hostname medivh`.
- Add project SSH key to `~/.ssh/authorized_keys`; add to local SSH config: `Host medivh` → `HostName <IP>`.
- Create a DHCP reservation on the router so the hostname is stable. Add the node to **config/nodes** when the IP is known.

### 3. USB sanitization setup

**3.1 Install tools**

```bash
sudo apt update && sudo apt install -y wipe secure-delete
```

Optional: `shred` (coreutils), `badblocks` (e2fsprogs) for extra checks.

**3.2 Deploy script**

Copy the project script to the Pi (clone repo or scp):

- Repo script: `scripts/usb-sanitize.sh`
- On the Pi: make executable `chmod +x usb-sanitize.sh`.

The script only acts on **removable** block devices (`lsblk` RM=1) and refuses root/boot disks.

### 4. Sanitization workflow (manual)

1. Plug in **only** the USB stick(s) to sanitize.
2. List candidates: `lsblk -d -o NAME,SIZE,RM,MODEL` — target must show `RM=1`.
3. Run (use whole-disk device, not a partition):
   ```bash
   sudo ./usb-sanitize.sh /dev/sdX
   ```
4. Confirm by typing `YES`. Script runs `wipefs -a` then one pass of zeros with `dd`.
5. When done, remove the stick. Verify with `lsblk` if desired (no partitions).

## Documentation

- **Node changelog:** `nodes/medivh-pi-sandbox.md` — hardware snapshot, IP, change history.
- **Inventory:** Update `nodes/roadmap.md` when the sandbox is deployed or retired.

## Optional: repurpose as K3s worker

If you later want this Pi as a cluster worker, follow `skills/worker-node-setup/SKILL.md` and `skills/hardware/sbc/SKILL.md` (cgroups, iptables-legacy, join token). The sandbox skill does not install or configure K3s.
