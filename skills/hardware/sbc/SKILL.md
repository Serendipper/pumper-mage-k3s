---
name: k3s-sbc-setup
description: Configure a single-board computer (Raspberry Pi, Orange Pi, Odroid, etc.) as a K3s worker node. Covers ARM architecture, boot media, reduced-RAM strategies, and power stability. Use when the target node is an SBC or ARM device.
---

# SBC Setup for K3s

> **Status**: Placeholder — no SBC has been deployed in this cluster yet. These are known considerations from K3s documentation and community experience. Update this skill after the first real deployment.

## Key Differences from x86 Nodes

| Concern | x86 Desktop/Laptop | SBC |
|---------|--------------------|----|
| Architecture | amd64 | arm64 or armhf |
| K3s binary | Auto-detected | Auto-detected (verify with `uname -m`) |
| Boot media | SSD/HDD | SD card, eMMC, USB SSD |
| RAM | 8-32 GB typical | 1-8 GB typical |
| Networking | Ethernet + WiFi | Varies (some have WiFi, some don't) |
| Power | PSU / battery | USB-C / barrel jack (can be flaky) |
| cgroups | GRUB kernel args | `/boot/cmdline.txt` or `/boot/firmware/cmdline.txt` |

## Supported SBCs

K3s officially supports `arm64` and `armhf`. Common boards:

| Board | RAM | Notes |
|-------|-----|-------|
| Raspberry Pi 4 Model B | 2/4/8 GB | Most common, well-supported |
| Raspberry Pi 5 | 4/8 GB | Newer, faster, same process |
| Raspberry Pi 3 Model B+ | 1 GB | Marginal for K3s, may need `--kubelet-arg` tuning |
| Orange Pi 5 | 4-16 GB | RK3588S, good performance |
| Odroid N2+ | 4 GB | Amlogic S922X |

## OS Installation

### Raspberry Pi
Use **Raspberry Pi OS Lite (64-bit)** or **Debian arm64** via Raspberry Pi Imager:
- Headless: enable SSH in imager settings (or place empty `ssh` file on boot partition)
- Set hostname and user in imager settings
- WiFi can be pre-configured in imager if needed

### Other SBCs
Check the vendor's recommended OS image. Prefer Debian-based (Armbian is common) for consistency with the rest of the cluster.

## cgroups Configuration

SBCs don't use GRUB — cgroups are set in the boot command line file.

### Raspberry Pi OS / Debian on Pi
```bash
# Edit cmdline.txt (single line, append to existing)
sed -i 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt
reboot
```

Older Pi OS versions use `/boot/cmdline.txt` instead of `/boot/firmware/cmdline.txt`.

### Armbian
```bash
# /boot/armbianEnv.txt
echo "extraargs=cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" >> /boot/armbianEnv.txt
reboot
```

Verify after reboot:
```bash
cat /proc/cmdline | grep cgroup
```

## iptables-legacy

Same as x86:
```bash
apt install -y iptables
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

## Reduced-RAM Strategies

For SBCs with 2 GB or less, K3s can be tuned:

```bash
# Limit kubelet memory
curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... sh -s - \
  --kubelet-arg="--system-reserved=memory=256Mi" \
  --kubelet-arg="--eviction-hard=memory.available<100Mi"
```

Consider using K3s `--disable` flags to reduce overhead:
```bash
# Disable components not needed on this node
--disable=metrics-server
```

## Boot Media Considerations

**SD cards** wear out under sustained writes (container logs, etcd-like workloads). Mitigations:
- Use a USB SSD as the boot drive (Raspberry Pi supports USB boot natively on Pi 4/5)
- Mount `/var/log` as tmpfs if using SD: `tmpfs /var/log tmpfs defaults,noatime,size=100M 0 0`
- Set `log-driver` in containerd config to limit log retention

**eMMC** is more durable than SD but still flash-based — same precautions apply at scale.

## Power Stability

SBCs are sensitive to power supply quality:
- Use the official power supply or a known-good USB-C PD supply
- Undervoltage causes random crashes and SD card corruption
- Raspberry Pi: check `vcgencmd get_throttled` — `0x0` means no issues

For always-on operation, consider a small UPS hat (e.g., PiSugar, Waveshare UPS HAT) or a USB UPS.

## Networking

Some SBCs have WiFi; others are ethernet-only:
- If WiFi is needed, same process as laptops (see `skills/hardware/laptop/SKILL.md`)
- Many SBC WiFi chips use `brcmfmac` driver — usually works with `firmware-brcm80211`
- Prefer wired ethernet where possible — SBC WiFi tends to be weak

## GPIO / Peripheral Conflicts

Container networking (Flannel/VXLAN) uses network interfaces and iptables. This doesn't conflict with GPIO, I2C, SPI, or UART — those can still be used by pods with appropriate device mounts.

If running containers that access hardware peripherals:
```yaml
# In pod spec
securityContext:
  privileged: true
# Or mount specific devices
volumeMounts:
  - name: gpio
    mountPath: /sys/class/gpio
```

## What to Skip

SBCs typically don't need:
- Lid close configuration (no lid)
- Battery management (no battery, unless UPS hat)
- Fan control (passive cooling or small always-on fan)
- Display-off service (headless by design)
- Suspend/hibernate masking (SBCs don't auto-suspend)
