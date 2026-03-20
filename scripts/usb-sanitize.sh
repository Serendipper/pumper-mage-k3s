#!/bin/bash
# USB stick sanitization for medivh sandbox (and similar Pi/headless hosts).
# Run as root. Only acts on removable block devices; requires explicit device.
set -e

usage() {
    echo "Usage: $0 <block-device>" >&2
    echo "Example: sudo $0 /dev/sda" >&2
    echo "" >&2
    echo "Lists removable block devices (candidates):" >&2
    lsblk -d -o NAME,SIZE,RM,MODEL,TRAN 2>/dev/null | head -1
    lsblk -d -o NAME,SIZE,RM,MODEL,TRAN 2>/dev/null | awk '$3==1'
    exit 1
}

if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

DEV="$1"
if [ ! -b "$DEV" ]; then
    echo "Not a block device: $DEV" >&2
    exit 2
fi

# Strip partition number so we check the whole disk
DISK="${DEV%%[0-9]*}"
if [ "$DISK" != "$DEV" ]; then
    echo "Use the whole-disk device (e.g. /dev/sda), not a partition (e.g. /dev/sda1)." >&2
    exit 2
fi

# Reject if not removable (RM=1 from lsblk)
RM=$(lsblk -d -n -o RM "$DEV" 2>/dev/null || echo "0")
if [ "$RM" != "1" ]; then
    echo "Refusing: $DEV is not marked removable (lsblk RM=1). Possible internal disk." >&2
    exit 3
fi

# Reject if device is in use as root or boot
ROOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/p[0-9]*$//')
BOOT_DEV=$(findmnt -n -o SOURCE /boot 2>/dev/null | sed 's/p[0-9]*$//')
BOOT_DEV_FW=$(findmnt -n -o SOURCE /boot/firmware 2>/dev/null | sed 's/p[0-9]*$//')
for d in "$ROOT_DEV" "$BOOT_DEV" "$BOOT_DEV_FW"; do
    [ -z "$d" ] && continue
    if [ "$(readlink -f "$d")" = "$(readlink -f "$DEV")" ]; then
        echo "Refusing: $DEV appears to be the root or boot device." >&2
        exit 3
    fi
done

SIZE=$(lsblk -d -n -o SIZE "$DEV" 2>/dev/null)
MODEL=$(lsblk -d -n -o MODEL "$DEV" 2>/dev/null)
echo "Target: $DEV ($SIZE, $MODEL) — REMOVABLE"
echo "This will wipe all partition tables and overwrite data. Unrecoverable."
read -p "Type YES to continue: " confirm
if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 0
fi

echo "Wiping filesystem signatures..."
wipefs -a "$DEV" 2>/dev/null || true

echo "Overwriting with zeros (one pass)..."
dd if=/dev/zero of="$DEV" bs=1M status=progress conv=fsync 2>/dev/null || true

echo "Done. You can remove the USB stick."
echo "To verify: lsblk $DEV (should show no partitions)."
