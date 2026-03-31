#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="/data/options.json"

log() {
  echo "[ha_hdd_mounter] $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "Missing required command: $1"
    exit 1
  }
}

require_cmd bash
require_cmd nsenter
require_cmd jq

HOST_NS=(nsenter --target 1 --mount --pid)
# Some nsenter versions support --fork while others only support --no-fork.
# Avoid false positives from matching the --no-fork help text.
if nsenter --help 2>&1 | grep -Eq -- '(^|[[:space:],])--fork([[:space:],=]|$)'; then
  HOST_NS+=(--fork)
fi

host_exec() {
  "${HOST_NS[@]}" -- "$@"
}

host_sh() {
  "${HOST_NS[@]}" -- sh -c "$1"
}

if [[ ! -f "$CONFIG_PATH" ]]; then
  log "Missing options file at $CONFIG_PATH"
  exit 1
fi

DISK_PATH="$(jq -r '.disk_path // "/dev/nvme0n1p1"' "$CONFIG_PATH")"
DISK_UUID="$(jq -r '.disk_uuid // empty' "$CONFIG_PATH")"
FS_TYPE="$(jq -r '.fs_type // "ext4"' "$CONFIG_PATH")"
MOUNT_POINT="$(jq -r '.mount_point // "/mnt/data/frigate_storage"' "$CONFIG_PATH")"
MOUNT_OPTIONS="$(jq -r '.mount_options // "defaults,noatime"' "$CONFIG_PATH")"
SYMLINK_PATH="$(jq -r '.symlink_path // empty' "$CONFIG_PATH")"
WAIT_SECONDS="$(jq -r '.wait_for_device_seconds // 60' "$CONFIG_PATH")"

if [[ -n "$DISK_UUID" && "$DISK_UUID" != "null" ]]; then
  DEVICE_PATH="/dev/disk/by-uuid/$DISK_UUID"
else
  DEVICE_PATH="$DISK_PATH"
fi

if [[ -z "$DEVICE_PATH" || "$DEVICE_PATH" != /dev/* ]]; then
  log "Configuration error: device must be under /dev (disk_path or disk_uuid)."
  exit 1
fi

log "Starting mount process for device=$DEVICE_PATH FS=$FS_TYPE"

# Wait for device to appear on host.
FOUND=0
for ((i=1; i<=WAIT_SECONDS; i++)); do
  if host_exec test -b "$DEVICE_PATH" >/dev/null 2>&1; then
    FOUND=1
    break
  fi
  sleep 1
done

if [[ "$FOUND" -ne 1 ]]; then
  log "Timed out waiting for $DEVICE_PATH after ${WAIT_SECONDS}s"
  log "Host /dev listing (filtered nvme/sd):"
  host_sh 'ls -l /dev/nvme* /dev/sd* 2>/dev/null || true'
  exit 1
fi

# Ensure mount point exists on host.
host_exec mkdir -p "$MOUNT_POINT"

# Mount only if not already mounted.
if host_exec mountpoint -q "$MOUNT_POINT"; then
  log "Mount point already active: $MOUNT_POINT"
else
  log "Mounting $DEVICE_PATH to $MOUNT_POINT"
  if ! host_exec mount -t "$FS_TYPE" -o "$MOUNT_OPTIONS" "$DEVICE_PATH" "$MOUNT_POINT"; then
    log "Mount failed. Host diagnostics:"
    host_exec lsblk -f || true
    host_exec blkid "$DEVICE_PATH" || true
    exit 1
  fi
fi

# Optional symlink for Frigate/media path convenience.
if [[ -n "$SYMLINK_PATH" && "$SYMLINK_PATH" != "null" ]]; then
  host_exec mkdir -p "$(dirname "$SYMLINK_PATH")"
  if host_exec test -L "$SYMLINK_PATH"; then
    log "Symlink already exists: $SYMLINK_PATH"
  elif host_exec test -e "$SYMLINK_PATH"; then
    log "Path exists and is not a symlink, leaving unchanged: $SYMLINK_PATH"
  else
    log "Creating symlink: $SYMLINK_PATH -> $MOUNT_POINT"
    host_exec ln -s "$MOUNT_POINT" "$SYMLINK_PATH"
  fi
fi

log "Mount process completed successfully."

# Keep add-on alive.
while true; do
  sleep 3600
done
