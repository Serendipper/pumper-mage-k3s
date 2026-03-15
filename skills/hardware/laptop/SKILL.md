---
name: k3s-laptop-hardening
description: Harden a laptop for use as a headless K3s worker node. Covers WiFi driver installation, lid close behavior, suspend/hibernate disabling, display off, battery charge management, and fan control. Use when setting up a laptop as a cluster node.
---

# Laptop Hardening for K3s

Laptops need extra configuration to work as always-on headless nodes. Run these steps after OS prep (cgroups, iptables-legacy) but before cluster join.

## 1. WiFi Drivers

Identify the chipset and install firmware:

```bash
lspci | grep -i net
```

Cross-reference with `wifi-drivers.md` in this directory for package mapping. Common cases:

| Chipset | Package | Driver | Notes |
|---------|---------|--------|-------|
| Intel Wireless | `firmware-iwlwifi` | iwlwifi | Usually pre-installed with netinst |
| Broadcom BCM43xx (older) | `firmware-b43-installer` | b43 | Downloads firmware at install time |
| Broadcom BCM43142/4352 | `broadcom-sta-dkms` | wl | Needs `linux-headers-$(uname -r)` + `dkms autoinstall` |
| Realtek | `firmware-realtek` | rtl | Usually works out of box |

After install, reload the driver:
```bash
modprobe -r <driver> && modprobe <driver>
```

## 2. WiFi Configuration

Source config so SSID and PSK are set (required for autonomous runs):

```bash
source config/defaults.env
[ -f config/project.env ] && source config/project.env
apt install -y wpasupplicant
wpa_passphrase "$K3S_WIFI_SSID" "$K3S_WIFI_PSK" > /etc/wpa_supplicant/wpa_supplicant-<iface>.conf
```

Values come from **config/defaults.env** (`K3S_WIFI_SSID`) and **config/project.env** (`K3S_WIFI_PSK`).

Add to `/etc/network/interfaces`:
```
# WiFi
allow-hotplug <iface>
iface <iface> inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant-<iface>.conf
```

For Broadcom `wl` driver, add `wpa-driver wext` to the interface block (default nl80211 fails):
```
    wpa-driver wext
    wpa-conf /etc/wpa_supplicant/wpa_supplicant-<iface>.conf
```

**SSID strategy**: Use `K3S_WIFI_SSID` from config. If it doesn't appear in scan (`iw dev <iface> scan | grep -i ssid`), use another SSID temporarily, move the laptop to its end location, then switch back.

Bring up the interface:
```bash
ifup <iface>
```

Verify IP:
```bash
ip addr show <iface>
```

## 3. Lid Close — Ignore

A sleeping node drops out of the cluster. Disable lid-triggered suspend:

```bash
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchDocked=ignore/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
systemctl restart systemd-logind
```

## 4. Disable Suspend/Hibernate

```bash
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

## 5. Turn Off Display

Create `/etc/systemd/system/display-off.service`:
```ini
[Unit]
Description=Turn off display
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/setterm --blank force --term linux

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable display-off.service
systemctl start display-off.service
```

## 6. Battery Management

Install TLP and detect what's supported:

```bash
apt install -y tlp
systemctl enable tlp
systemctl start tlp
tlp-stat -b
```

Check the `Plugin` line in output and configure accordingly:

### ThinkPad (`thinkpad_acpi` plugin)
```bash
sed -i 's/#START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=40/' /etc/tlp.conf
sed -i 's/#STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=80/' /etc/tlp.conf
tlp start
```
Verify: battery shows "Not charging" when above stop threshold.

### Lenovo IdeaPad (`lenovo` / `ideapad_laptop` plugin)
Conservation mode only (binary on/off, caps at ~60%):
```bash
sed -i 's/#STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=1/' /etc/tlp.conf
tlp start
```
Verify: `conservation_mode = 1` in `tlp-stat -b`.

### Dell (`dell` plugin)
```bash
sed -i 's/#START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=50/' /etc/tlp.conf
sed -i 's/#STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=80/' /etc/tlp.conf
tlp start
```

### Apple (no plugin)
Charge threshold control **not possible**. Apple SMC doesn't expose this to Linux. Install TLP for general power management only, or skip it entirely. Do not waste time trying to make it work.

## 7. Fan Control

Detect available interfaces:

```bash
# ThinkPad ACPI fan interface
cat /proc/acpi/ibm/fan 2>/dev/null

# Apple SMC
ls /sys/devices/platform/applesmc*/fan*_input 2>/dev/null

# Generic hwmon
ls /sys/class/hwmon/*/fan*_input 2>/dev/null
find /sys/devices -name pwm1 2>/dev/null

# Dell SMM
ls /sys/class/hwmon/*/fan*_input 2>/dev/null | xargs -I{} dirname {} | xargs -I{} cat {}/name 2>/dev/null | grep dell
```

### Apple MacBook → `mbpfan`
```bash
apt install -y mbpfan
systemctl enable mbpfan
systemctl start mbpfan
```
Default thresholds (63/66/86°C) are reasonable. Verify: `sensors` shows fan RPM.

### ThinkPad → `thinkfan`
Only works if `/proc/acpi/ibm/fan` exists and is writable. Many consumer ThinkPads (S-series, E-series) do NOT expose this — check first.

```bash
echo "options thinkpad_acpi fan_control=1" > /etc/modprobe.d/thinkfan.conf
modprobe -r thinkpad_acpi && modprobe thinkpad_acpi
cat /proc/acpi/ibm/fan
```

If it shows fan levels, install thinkfan and configure `/etc/thinkfan.yaml`. If empty or absent, fan is firmware-managed — document as a known limitation and move on.

### No interface found
Fan is firmware-managed by the EC. This is the case for most consumer laptops (IdeaPad, non-business ThinkPad, many Dells). Document it in the node changelog as a known limitation. Do not install fan daemons that won't work.

## Verification Checklist

After completing all steps, verify:

```bash
# Lid behavior
grep -E '^HandleLid' /etc/systemd/logind.conf

# Suspend masked
systemctl is-enabled sleep.target  # should be "masked"

# Display off service
systemctl is-enabled display-off

# WiFi connected
ip addr show <iface> | grep inet

# Battery (if applicable)
tlp-stat -b | grep -E "conservation|thresh|Plugin"

# Fan (if applicable)
sensors | grep -i fan
```
