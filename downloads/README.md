# OS images for node staging

Image used to prepare boot media for Raspberry Pi workers (USB stick or USB SSD). Run the steps below on any machine (Linux, macOS, WSL) that has the target USB/SD attached.

## Raspberry Pi OS Lite (64-bit)

Trixie, 2025-12-04.

- **URL:** https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz
- **Size:** ~487 MB compressed
- **Checksum:** same directory, `2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256`

### 1. Download and verify

```bash
mkdir -p ~/downloads && cd ~/downloads
wget --progress=bar:force -O 2025-12-04-raspios-trixie-arm64-lite.img.xz "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz"
wget -q -O 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256 "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256"
sha256sum -c 2025-12-04-raspios-trixie-arm64-lite.img.xz.sha256
```

### 2. Write to USB stick or SSD

Plug in the target device. Use the whole-disk device (e.g. `/dev/sda` on Linux), not a partition. Confirm with `lsblk` that you have the right device.

```bash
# List block devices; check SIZE and RM (removable). Replace sdX with your target.
lsblk -d -o NAME,SIZE,RM,MODEL

# Write image (replace sdX with target; this overwrites the entire device)
xzcat ~/downloads/2025-12-04-raspios-trixie-arm64-lite.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

On macOS use `diskutil list` to find the raw device (e.g. `/dev/rdisk4`) and `diskutil unmountDisk` before writing.

### 3. Preconfigure first-boot (optional)

After writing, mount the boot and root partitions and set cloud-init `user-data` (user, hostname) and `network-config` (WiFi). Generate network config from project config: `./scripts/render-pi-firstboot-network.sh` → use `config/generated/pi-firstboot-network.yaml` as `network-config`. User-data template: `scripts/pi-firstboot-userdata.yaml` (default hostname **modera**). Set `/etc/hostname` and `/etc/hosts` in rootfs as needed.
