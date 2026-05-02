# Incident: dalaran control-plane flap

Date: 2026-04-26
Status: Mitigated by reboot, root cause not fully confirmed
Severity: High (control-plane instability)

## What happened

- `dalaran` (K3s server/control plane) went down again.
- After reboot, `k3s` returned to `active (running)`, but evidence shows repeated underlying host-level failures.

## Evidence captured

### 1) Reboot history shows recurring crashes

From `last -x` on `dalaran`:

- `Sun Apr 26 04:12` (current boot)
- `Sat Apr 25 05:56 - crash`
- `Fri Apr 24 22:53 - crash`
- `Fri Apr 24 21:26 - crash`
- `Mon Apr 20 21:11 - crash`
- `Sun Apr 19 16:08 - crash`

This pattern suggests repeated unexpected host resets, not only a one-off K3s restart.

### 2) Cluster events show filesystem I/O failures on control-plane paths

Recent `kubectl get events -A` includes:

- `ReadManifestFailed ... /var/lib/rancher/k3s/server/manifests/...: input/output error`
- `ApplyManifestFailed ... /var/lib/rancher/k3s/server/tls/server-ca.crt: input/output error`
- `FailedCreatePodSandBox ... meta.db: input/output error`
- `Failed ... /var/lib/kubelet/.../etc-hosts: input/output error`
- `fork/exec .../runc: input/output error`

These are direct disk/filesystem read-write failures on `dalaran` paths.

### 3) Secondary API instability after storage faults

Many follow-on events:

- `failed to fetch token ... https://127.0.0.1:6444 ... read: connection reset by peer`

This indicates API instability after the host/storage fault cascade.

### 4) Current recovery state

`systemctl status k3s` on `dalaran` currently reports:

- `Active: active (running) since Sun 2026-04-26 04:12:53 EDT`

So service is presently up, but prior crash indicators remain unresolved.

## Working diagnosis

Most likely: intermittent local storage path instability (NVMe media/controller/filesystem, or power-related abrupt resets causing filesystem issues).

Not yet proven in this capture:

- Full kernel crash trail for the failed boot windows

### 5) SMART/NVMe check results (executed after initial capture)

Executed on `dalaran`:

- `sudo apt install -y smartmontools nvme-cli`
- `sudo smartctl -a /dev/nvme0`
- `sudo nvme smart-log /dev/nvme0`

Key outputs:

- Device: `PM9B1 NVMe Samsung 256GB`
- `SMART overall-health self-assessment test result: PASSED`
- `Media and Data Integrity Errors: 0`
- `Error Information Log Entries: 0`
- `Critical Warning: 0x00`
- `percentage_used: 0%`
- Temperature nominal during check (~33C)
- Notable: `Unsafe Shutdowns: 143` (high relative to `Power Cycles: 200`)

Interpretation:

- SMART does not currently show media errors.
- High unsafe shutdown count is consistent with repeated abrupt losses/crashes and may still indicate power path, controller, or abrupt reset issues even without logged media faults.

## Immediate next checks (priority order)

1. Run filesystem check in maintenance window:
   - offline `fsck.ext4 -f /dev/nvme0n1p2`
2. Keep watching SMART counters over time (especially media errors and error log entries).
3. If errors appear/increase, replace the NVMe and restore/migrate K3s data.

## Notes

- Capacity is not currently a pressure signal (`/` had ample free space and inodes).
- This incident note is evidence capture only; no manifest changes were made.
