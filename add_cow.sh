#!/bin/bash
# Usage: ./add_cow.sh input.iso output.iso cow_partition_size
# Example: ./add_cow.sh out/sawalinux.iso out/sawalinux_cow.iso 1600M

ORIG_ISO="$1"
DEST_ISO="$2"
SIZE="$3"

COW_NAME="SAWACOWUSB"
TMP_IMG='/tmp/tmpimg'

rm "$DEST_ISO"

cp "$ORIG_ISO" "$DEST_ISO" || exit 1
dd if=/dev/zero bs=1M count="$SIZE" iflag=count_bytes >> "$DEST_ISO" || exit 1
echo "DEBUG:"; ls -lh "$DEST_ISO"
echo "n




p
w" | fdisk "$DEST_ISO" || exit 1

START_SECTOR=$(fdisk -o 'start' --list "$DEST_ISO" | tail -n 1)
START_BYTE=$(echo "$START_SECTOR*512" | bc)
END_SECTOR=$(fdisk -o 'end' --list "$DEST_ISO" | tail -n 1)
SIZE_BYTE=$(echo "$END_SECTOR*512 - $START_SECTOR*512" | bc)
echo "DEBUG: start: ($START_SECTOR sector, $START_BYTE byte). end: ($END_SECTOR sector, $SIZE_BYTE byte size)"

dd if=/dev/zero of="$TMP_IMG" bs=1M count="$SIZE" iflag=count_bytes || exit 1
echo "DEBUG:"; ls -lh "$TMP_IMG"
mkfs.ext4 -L "$COW_NAME" "$TMP_IMG" || exit 1
dd if="$TMP_IMG" of="$DEST_ISO" bs=1M seek="$START_BYTE" count="$SIZE_BYTE" oflag=seek_bytes iflag=count_bytes conv=notrunc || exit 1
echo "DEBUG:"; ls -lh "$DEST_ISO"
rm "$TMP_IMG"

#LOOP_DEVICE='/dev/loop314'
#sudo losetup -o "$START_BYTE" --sizelimit "$SIZE_BYTE" "$LOOP_DEVICE" "$DEST_ISO" || exit 1
#sudo mkfs.ext4 -L "$COW_NAME" "$LOOP_DEVICE"
#sudo losetup -d "$LOOP_DEVICE" || exit 1

