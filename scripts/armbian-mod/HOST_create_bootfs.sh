#!/usr/bin/env bash

set -ex

for item in expr parted fdisk sfdisk truncate jq mlabel mke2fs mkfs.vfat e2fsck kpartx wipefs ; do
  type "${item}" 2>/dev/null 1>&2
done

imagefile="$(jq -r '.builds[] | select(.packer_run_uuid=="'"${PACKER_RUN_UUID}"'") | .files[0].name' packer-manifest.json)"
[[ -f "${imagefile}" ]]

# make the file, mmm... 300MB bigger? we're gonna use 256MB for /boot
# and the remainder for IMD
partshift=300
truncate -s "+${partshift}MiB" "${imagefile}"

# grab the starting sector of the first partition, we'll need that
read -r sectorsz startsec <<<"$(parted -s "${imagefile}" 'unit s' 'print' | awk 'END { print sz,st } $1 == "Sector" { sz=$4 } $1 == "1" { st=$2 }')"
startsec="${startsec%s}"
sectorsz="${sectorsz%%B*}"

# calculate new starting point in sectors...
newstart=$(expr "${partshift}" '*' 1048576 / "${sectorsz}")
newpre=$(expr "${newstart}" - 1)

# make sfdisk move the partition and data therein
printf "${newstart}" | sfdisk "${imagefile}" -N 1 --move-data 

# create new partition for /boot filesystem
parted -s "${imagefile}" mkpart pri ext2 "${startsec}s" 256M

# and IMD fits in the gap
parted -s "${imagefile}" mkpart pri ext2 256M "${newpre}s"

# now swap the partition IDs...
sfdisk -r "${imagefile}"

case "${PACKER_BUILD_NAME}" in
  rock64)
    bootfs_uuid="${ROCK64_BOOTFS_UUID}"
    imdfs_id="${ROCK64_IMDFS_ID}"
  ;;
  espressobin)
    bootfs_uuid="${ESPRESSOBIN_BOOTFS_UUID}"
    imdfs_id="${ESPRESSOBIN_IMDFS_ID}"
  ;;
esac

# great. now let's poke at the filesystems side.
for loop in $(kpartx -a -v "${imagefile}" | awk '{ print $3 }') ; do
  case "${loop}" in
    *1)
      # the new /boot partition
      [[ "${bootfs_uuid}" ]] && mke2fs -O none,ext_attr,resize_inode,dir_index,filetype,sparse_super -U "${bootfs_uuid}" "/dev/mapper/${loop}"
    ;;
    *2)
      # IMD metadata partition
      mkfs.vfat -n "IMD" -i "${imdfs_id}" "/dev/mapper/${loop}"
    ;;
    *3)
      # the new root partition
      e2fsck -fy "/dev/mapper/${loop}"
    ;;
  esac
done

# and clean up.
while : ; do
  kpartx -d "${imagefile}" && break
done
