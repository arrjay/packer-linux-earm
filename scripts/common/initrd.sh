#!/usr/bin/env bash

set -e

# rebuild the initramfs now
# relies on the fact pi can't have multiple kernels installed. feels bad.
for kv in /lib/modules/* ; do
  case "${kv}" in
    *-v7+)   mkinitramfs -o /boot/initrd7.img  "${kv}" ;;
    *-v7l+)  mkinitramfs -o /boot/initrd7l.img "${kv}" ;;
    *-v8+)   mkinitramfs -o /boot/initrd8.img  "${kv}" ;;
    *[0-9]+) mkinitramfs -o /boot/initrd.img   "${kv}" ;;
  esac
done

set +x

# wire config.txt to load these...
cat <<_EOF_>>/boot/config.txt
[pi0]
initramfs initrd.img followkernel
[pi1]
initramfs initrd.img followkernel
[pi2]
# NOTE: if you are using a 64-bit kernel, adjust these!
initramfs initrd7.img followkernel
[pi3]
initramfs initrd7.img followkernel
[pi4]
initramfs initrd7l.img followkernel
[all]
# cleared filter
_EOF_
