#!/usr/bin/env bash
# Flash an SD card from the host. Run ./01_flash_sdcard.sh to start.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
for cmd in lsblk findmnt readlink xzcat dd sync sudo grep tr umount; do need "$cmd"; done
IMAGE_DIR="$SCRIPT_DIR/../vendor_images"
shopt -s nullglob
images=("$IMAGE_DIR"/*.img.xz)
((${#images[@]})) || { echo "No images found: $IMAGE_DIR"; exit 1; }
echo 'Available images:'
for i in "${!images[@]}"; do printf '%s) %s\n' "$((i+1))" "${images[i]##*/}"; done
ask choice 'Image number'
[[ $choice =~ ^[0-9]{1,3}$ ]] && ((10#$choice >= 1 && 10#$choice <= ${#images[@]})) || { echo 'Invalid selection.'; exit 1; }
IMAGE=$(readlink -f -- "${images[10#$choice-1]}")
echo 'Check disk SIZE, MODEL, and MOUNTPOINTS carefully.'
lsblk -p -o NAME,TYPE,SIZE,MODEL,TRAN,RM,MOUNTPOINTS
ask DISK 'SD card disk path (e.g. /dev/sdb, not a partition)'
DISK=$(readlink -f -- "$DISK")
[[ -b $DISK && $(lsblk -dnro TYPE "$DISK") == disk ]] || { echo 'Select a whole block disk.'; exit 1; }

check_disk() {
    local mount image_source swapdev
    # Reject disks with system mounts.
    while IFS= read -r mount; do
        case "$mount" in
            '' ) ;;
            /media/*|/run/media/*|/mnt/*|/mnt) ;;
            *) echo "Protected or active mount found: $mount" >&2; return 1 ;;
        esac
    done < <(lsblk -nrpo MOUNTPOINTS "$DISK")
    # Check root device ancestry, including LVM and dm-crypt.
    local root_source
    root_source=$(findmnt -nro SOURCE /)
    root_source=${root_source%%\[*}
    if [[ -b $root_source ]] && lsblk -snrpo NAME "$root_source" | grep -Fx "$DISK" >/dev/null; then
        echo 'Cannot flash the host root disk.' >&2; return 1
    fi
    image_source=$(findmnt -nro SOURCE -T "$IMAGE")
    image_source=${image_source%%\[*}
    if [[ -b $image_source ]] && lsblk -snrpo NAME "$image_source" | grep -Fx "$DISK" >/dev/null; then
        echo 'Cannot overwrite the disk containing the image.' >&2; return 1
    fi
    # Reject disks backing an active swap partition or file.
    while read -r swapdev _; do
        [[ $swapdev == Filename ]] && continue
        if [[ ! -b $swapdev ]]; then swapdev=$(findmnt -nro SOURCE -T "$swapdev"); fi
        swapdev=${swapdev%%\[*}
        if [[ -b $swapdev ]] && lsblk -snrpo NAME "$swapdev" | grep -Fx "$DISK" >/dev/null; then
            echo 'Cannot overwrite a disk used for swap.' >&2; return 1
        fi
    done < /proc/swaps
}
check_disk
DISK_ID=$(lsblk -bdnro MAJ:MIN,SIZE,MODEL,SERIAL "$DISK")
lsblk -p -o NAME,SIZE,MODEL,MOUNTPOINTS "$DISK"
printf 'Image: %s\nDisk to erase: %s\n' "$IMAGE" "$DISK"
ask confirmation "All data on $DISK will be erased. Continue? (yes/no)" no
[[ ${confirmation,,} == yes ]] || { echo 'Cancelled.'; exit 1; }
sudo -v
[[ $(lsblk -bdnro MAJ:MIN,SIZE,MODEL,SERIAL "$DISK") == "$DISK_ID" ]] || { echo 'Disk identity changed. Stopping.'; exit 1; }
check_disk
# Unmount child partitions first. Stop if unmounting fails.
mapfile -t nodes < <(lsblk -nrpo NAME "$DISK")
for ((i=${#nodes[@]}-1; i>=0; i--)); do
    if findmnt -rn -S "${nodes[i]}" >/dev/null; then sudo umount --all-targets -- "${nodes[i]}"; fi
done
[[ -z $(lsblk -nrpo MOUNTPOINTS "$DISK" | tr -d '[:space:]') ]] || { echo 'Disk is still mounted.'; exit 1; }
xzcat -- "$IMAGE" | sudo dd of="$DISK" bs=4M status=progress conv=fsync
sync
echo 'Flash and sync completed.'
