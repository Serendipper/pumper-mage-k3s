# WiFi Driver Reference

On-demand reference for laptop WiFi chipset identification and driver installation on Debian stable.

## Quick Identification

```bash
lspci | grep -i net
# Look for "Network controller" line — that's the WiFi card
```

## Chipset → Package Mapping

### Broadcom

| Chipset | PCI ID | Package | Driver | Notes |
|---------|--------|---------|--------|-------|
| BCM4331 | 14e4:4331 | `firmware-b43-installer` | b43 | e.g. older MacBook |
| BCM43142 | 14e4:4365 | `broadcom-sta-dkms` | wl | e.g. IdeaPad |
| BCM4352 | 14e4:43b1 | `broadcom-sta-dkms` | wl | — |
| BCM4360 | 14e4:43a0 | `broadcom-sta-dkms` | wl | — |

**b43 vs broadcom-sta decision**:
- `b43` (open-source): BCM4306, BCM4311, BCM4312, BCM4318, BCM4321, BCM4322, BCM4331. Uses `firmware-b43-installer` which downloads firmware at install time from the internet.
- `broadcom-sta` / `wl` (proprietary): BCM4311, BCM4312, BCM4313, BCM4321, BCM4322, BCM43142, BCM43224, BCM43225, BCM43227, BCM43228, BCM4352, BCM4360. Uses `broadcom-sta-dkms`.

When in doubt, check which driver loads: `lspci -k | grep -A3 "Network controller"`.

#### broadcom-sta / wl installation

Requires kernel headers for DKMS:
```bash
apt install -y linux-headers-$(uname -r) broadcom-sta-dkms
dkms autoinstall
modprobe wl
```

**Known quirk**: The `wl` driver does not work with wpa_supplicant's default `nl80211` driver. Must specify `wpa-driver wext` in `/etc/network/interfaces`:
```
iface wlp2s0 inet dhcp
    wpa-driver wext
    wpa-conf /etc/wpa_supplicant/wpa_supplicant-wlp2s0.conf
```

**After kernel updates**: `broadcom-sta-dkms` rebuilds automatically via DKMS, but verify with `dkms status`. If the module is missing after an update, run `dkms autoinstall`.

#### b43 installation

```bash
apt install -y firmware-b43-installer
modprobe -r b43 && modprobe b43
```

No special wpa_supplicant driver needed — default `nl80211` works.

**Known issue**: b43 driver can be flaky on some chipsets (notably BCM4331 on MacBooks). High latency, occasional drops. The proprietary `wl` driver may be more stable but doesn't support BCM4331.

### Intel

| Chipset | Package | Driver | Notes |
|---------|---------|--------|-------|
| Intel Wireless 7260 | `firmware-iwlwifi` | iwlwifi | — |
| Intel Wireless 8260 | `firmware-iwlwifi` | iwlwifi | — |
| Intel AX200/201 | `firmware-iwlwifi` | iwlwifi | — |
| Intel AX210/211 | `firmware-iwlwifi` | iwlwifi | — |

Intel WiFi is usually the easiest — `firmware-iwlwifi` is often already included in the Debian netinst image. Check:

```bash
dmesg | grep iwlwifi
# If it shows "loaded firmware version", no additional install needed
```

If not present:
```bash
apt install -y firmware-iwlwifi
modprobe -r iwlwifi && modprobe iwlwifi
```

### Realtek

| Chipset | Package | Driver |
|---------|---------|--------|
| RTL8723BE | `firmware-realtek` | rtl8723be |
| RTL8821CE | `firmware-realtek` | rtl8821ce |
| RTL8822BE | `firmware-realtek` | rtl8822be |

```bash
apt install -y firmware-realtek
modprobe -r <driver> && modprobe <driver>
```

Some newer Realtek chips (RTL8852xx) may need out-of-tree drivers from GitHub — check if the kernel includes support first.

### Qualcomm/Atheros

Usually works with the `ath9k` or `ath10k` drivers and `firmware-atheros`:
```bash
apt install -y firmware-atheros
```

## Debugging WiFi Issues

```bash
# Check if interface exists
ip link show

# Check if driver loaded
lspci -k | grep -A3 "Network controller"

# Check dmesg for firmware errors
dmesg | grep -i -E "firmware|wifi|wlan|b43|iwlwifi|wl"

# Scan for networks
iw dev <iface> scan | grep -i ssid

# If scan fails with wl driver, try wpa_supplicant directly
wpa_supplicant -D wext -i <iface> -c /etc/wpa_supplicant/wpa_supplicant-<iface>.conf -B
dhcpcd <iface>
```

## Post-Kernel-Update Checklist

After any kernel update (`apt upgrade` that touches `linux-image-*`):

1. Reboot into the new kernel
2. Verify WiFi interface exists: `ip link show`
3. If using DKMS drivers (`broadcom-sta-dkms`): check `dkms status`
4. If module missing: `apt install linux-headers-$(uname -r) && dkms autoinstall`
