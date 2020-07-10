#!/usr/bin/env bash
# check for gap in partition table holding root device, add swap

# if we already have a swap partition in fstab, go away
grep -q swap /etc/fstab && exit 0

# find the root device
while read -r line ; do
  read -r dev mount rest <<<$line
  [[ "${mount}" == "/" ]] && rootdev="${dev}"
done < /proc/mounts

# get partitions associated with the root device
parts=$(lsblk -Ps "${rootdev}" | awk '$0 ~ "TYPE=\"part\"" { e=split($1, o, "=") ; gsub(/"/, "", o[e]) ; print o[e] }')

# and walk all of them...
for slice in ${parts} ; do
  # get the disk and check if there's alarge (>100MB) free space gap between the first and second partitions
  # Model: SD SD16G (sd/mmc)
  # Disk /dev/mmcblk0: 15.5GB
  # Sector size (logical/physical): 512B/512B
  # Partition Table: msdos
  # Disk Flags: 
  #
  # Number  Start   End     Size    Type     File system  Flags
  #         32.3kB  1049kB  1016kB           Free Space
  #  1      1049kB  230MB   229MB   primary  ext2         boot
  #         230MB   768MB   538MB            Free Space
  #  2      768MB   15.5GB  14.7GB  primary  ext4
  disk=$(lsblk -Ps "/dev/${slice}" | awk '$0 ~ "TYPE=\"disk\"" { e=split($1, o, "=") ; gsub(/"/, "", o[e]) ; print o[e] }')
  candidate=$(parted -s "/dev/${disk}" print free | awk '/^ 1 /{f=1;next}/^ 2 /{f=0}f')
  case "${candidate}" in
    *"Free Space"*)
      read -r start end size rest <<<$candidate
      case "${size}" in
        *MB)
         size="$(echo "${size}" | awk '{ gsub(/MB/,"") ; print }')"
         [ "${size}" -gt 100 ] || continue
         # grab partitions that existed before we did this
         oldparts=($(lsblk -nl /dev/"${disk}" | awk '{ print $1 }'))
         # create a swap partition
         parted -s "/dev/${disk}" mkpart pri linux-swap "${start}" "${end}"
         # find it
         newparts=($(lsblk -nl /dev/"${disk}" | awk '{ print $1 }'))
         for step in "${newparts[@]}" ; do
           case " ${oldparts[*]} " in
             *" ${step} "*) : ;;
             *) # FOUND YOU!
               mkswap "/dev/${step}"
               uuid=$(blkid -o value -s UUID "/dev/${step}")
               printf 'UUID=%s swap swap defaults 0 0\n' "${uuid}" >> /etc/fstab
             ;;
           esac
         done
        ;;
      esac
    ;;
  esac
done

# flip on all swap devices
swapon -a

exit 0
