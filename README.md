# HA HDD Auto-Mount Add-on for Frigate Storage

This repository contains a **starter Home Assistant add-on** that mounts a secondary disk/partition at boot, without modifying your OS SSD configuration.

## What it does

- Waits for a specific block device (path or UUID).
- Mounts it on a host mount point (default `/mnt/data/frigate_storage`).
- Optionally creates a symlink so Frigate can read/write through Home Assistant media paths.
- Keeps the container running so Home Assistant sees the add-on as healthy.

## Why this approach works on HAOS

HAOS itself is locked down, but a privileged add-on with host PID namespace can call `nsenter` and run `mount` **in the host namespace**. That gives controlled host-level mount behavior from an add-on lifecycle.

## Install

1. Add this repository to your HA Add-on Store:
   - `https://github.com/spikar85/ha-hdd-addon`
2. Install **HA HDD Mounter for Frigate Storage**.
3. Configure options in the add-on.
4. Start add-on and check logs.

## Example options
## Change for your drive which can be found using terminal command 'ha hardware info'

```yaml
disk_path: "/dev/nvme0n1p1"
fs_type: "ext4"
mount_point: "/mnt/data/frigate_storage"
mount_options: "defaults,noatime"
symlink_path: "/mnt/data/supervisor/media/frigate_storage"
wait_for_device_seconds: 60
```

## Configuration notes

- `disk_path`: direct device path (default `/dev/nvme0n1p1`).
- `disk_uuid`: optional; if set, it overrides `disk_path`.
- `mount_point`: host path where the partition is mounted.

## Important safety note

Keep this set to your secondary storage partition only. Do not set it to OS partitions.

## HACS vs Add-on Store

This will **not** install through HACS. HACS is for Home Assistant frontend/custom integrations, not Supervisor add-ons.

Use **Settings → Apps** (older versions: **Settings → Add-ons**) then open the Add-on Store/Repositories section and add:

- `https://github.com/spikar85/ha-hdd-addon`

Then install **HA HDD Mounter for Frigate Storage** from the Add-on Store.

