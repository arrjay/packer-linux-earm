#!/usr/bin/env bash

# resize / on a freshly booted fs image

# get block device for a filesystem, then walk up and resize the parents

# lsblk -Ps | tac
# NAME="sda" MAJ:MIN="8:0" RM="0" SIZE="238.5G" RO="0" TYPE="disk" MOUNTPOINT=""
# NAME="sda3" MAJ:MIN="8:3" RM="0" SIZE="237.8G" RO="0" TYPE="part" MOUNTPOINT=""
# NAME="luks-xxxxxxxx-yyyy-zzzz-wwww-vvvvvvvv" MAJ:MIN="253:0" RM="0" SIZE="237.8G" RO="0" TYPE="crypt" MOUNTPOINT=""
# NAME="vg-root" MAJ:MIN="253:1" RM="0" SIZE="32G" RO="0" TYPE="lvm" MOUNTPOINT="/"

mountpt="${1:-/}"
target=''

# fine device for mountpoint
while read -r line ; do
  read -r device mount fstype rest <<<$line
  [[ "${mount}" == "${mountpt}" ]] && { target="${device}" ; break ; }
done < /proc/mounts

echo "resizing ${mountpt} (${target})..."

# walk lsblk from disks to final fs block device
while read -r line ; do
  ttype='' ; tname='' majmin='' ; parts=()
  read -ra parts <<<$line
  for p in "${parts[@]}" ; do
    case "${p}" in
      TYPE=*) ttype="${p#TYPE=\"}" ; ttype="${ttype%\"}" ;;
      NAME=*) tname="${p#NAME=\"}" ; tname="${tname%\"}" ;;
      MAJ:MIN=*) majmin="${p#MAJ:MIN=\"}" ; majmin="${majmin%\"}" ;;
    esac
  done
  case "${ttype}" in
    disk)
      # save device for partition resizer, rescan device
      parent="${tname}"
      [[ -f "/sys/class/block/${tname}/device/rescan" ]] && \
        { printf '%s\n' '1' > "/sys/class/block/${tname}/device/rescan" ; }
     ;;
    part)
      # make parted extend the partition
      read -r pno < "/sys/class/block/${tname}/partition"
      parted -s "/dev/${parent}" resizepart "${pno}" 100%
      parent=''
     ;;
    crypt)
      # cryptsetup here...
      cryptsetup resize "${tname}"
     ;;
    lvm)
      vgname='' ; lvpath='' ; pvpath=''
      # lvdisplay to get vg name
      while read -r lvline ; do
        case "${lvline}" in
          *:${majmin}) IFS=: read -r lvpath vgname rest <<<${lvline} ; break
        esac
      done < <(lvdisplay -c)
      # pvresize against all the PVs in this VG
      while read -r pvline ; do
        case "${pvline}" in
          *:"${vgname}":*)
            IFS=: read -r pvpath rest <<<${lvline}
            pvresize "${pvpath}"
           ;;
        esac
      done < <(pvdisplay -c)
      # lvexend to max
      lvextend -l+100%FREE "${lvpath}"
     ;;
    *) : ;;
  esac
done < <(lsblk -Ps "${target}" | tac)

# now resize a filesystem
case "${fstype}" in
  ext*) resize2fs  "${device}"               ;;
  xfs)  xfs_growfs "${mountpt}"              ;;
  jfs)  mount -o remount,resize "${mountpt}" ;;
  *)    :                                    ;;
esac
