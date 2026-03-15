# OS images for node staging

**medivh** is the staging host: it holds the Pi OS image and writes it to USB sticks (or USB SSDs) for other Raspberry Pis. All download and write steps run **on medivh**, not on your desktop.

## Raspberry Pi OS Lite (64-bit)

Use this image to prepare boot media for other Pis (USB stick or USB SSD). Latest: Trixie, 2025-12-04.

- **URL:** https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz
- **Size:** ~487 MB compressed
- **Checksum:** same directory, `2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256`

### Download on medivh

From your PC (one command; download runs on medivh):

```bash
ssh medivh 'mkdir -p ~/downloads && cd ~/downloads && wget -q --show-progress -O 2025-12-04-raspios-trixie-arm64-lite.img.xz "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz" && wget -q -O 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256 "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256" && sha256sum -c 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256 && ls -la ~/downloads/'
```

Or SSH into medivh and run:

```bash
mkdir -p ~/downloads && cd ~/downloads
wget --progress=bar:force -O 2025-12-04-raspios-trixie-arm64-lite.img.xz "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz"
wget -q -O 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256 "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256"
sha256sum -c 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256
```

### Write to USB stick/SSD (on medivh)

Plug the target USB drive into medivh. Use whole-disk device (e.g. `/dev/sda`), not a partition:

```bash
# On medivh: list devices, confirm target is RM=1
lsblk -d -o NAME,SIZE,RM,MODEL

# Write image (replace sdX with target)
xzcat ~/downloads/2025-12-04-raspios-trixie-arm64-lite.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

**Preconfigure first-boot (optional):** After writing the image, mount the boot and root partitions on medivh and set cloud-init `user-data` (user, hostname) and `network-config` (WiFi). Generate network config from project config: `./scripts/render-pi-firstboot-network.sh` → use `config/generated/pi-firstboot-network.yaml` as `network-config`. User-data template: `scripts/pi-firstboot-userdata.yaml` (default hostname **modera**). Set `/etc/hostname` and `/etc/hosts` in rootfs.

**Procedure:** See `skills/sanitizing-sandbox/SKILL.md` for setting up medivh (USB SSD boot, sanitization workflow).
