#!/bin/env bash

set -ex

# build a stage 1 rootfs
type dirname > /dev/null || { echo "dirname is required" 1>&2 ; exit 1 ; }
SELFDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd "${SELFDIR}/.."
. ./shelllib/common

# check for needed binaries now
__check_progs git date env sleep mktemp tar tee wget kpartx mount parted mkfs.ext2 mkfs.ext4 tee uuidgen || exit "${?}"

# have a debian archive mirror if we didn't specify one
[[ "${DEBIAN_URI}" ]] || DEBIAN_URI=http://debian.osuosl.org/debian
[[ -d /var/tmp ]] && export TMPDIR=/var/tmp

# load our debootstrap from checkout...
debootstrap () {
  local rootdir release rc
  rootdir="$(mktemp -d)"
  release="${1}"
  sudo DEBOOTSTRAP_DIR="${PWD}/vendor/debootstrap/share/debootstrap" \
   bash "${PWD}/vendor/debootstrap/sbin/debootstrap" \
    --verbose --variant=minbase --arch=armel \
    --foreign --merged-usr \
    --keyring="${PWD}/keyrings/debian-archive-bookworm-stable.gpg" \
    ${release} \
    ${rootdir} \
    ${DEBIAN_URI} 1>&2
  rc="${?}"
  echo "${rootdir}"
  return "${rc}"
}

uuidgen_trunc () {
 out="$(uuidgen)"
 out="${out%%-*}"
 printf '%s\n' "${out}"
}

munge_vfat_id () {
  id="${1}"
  # uppercase
  id="${id^^}"
  # add the dash that fatfs has
  id="${id:0:4}-${id:4:4}"
  # return
  printf '%s' "${id}"
}

case "${CODEREV}" in
  *-DIRTY) __warn_msg "WARNING: git tree is dirty, sleeping 5 seconds for running confirmation."
           sleep 5
           ;;
esac

echo "building ${CODEREV} at ${BUILD_TIMESTAMP}"

rfs_uuid="$(uuidgen)"
bfs_uuid="$(uuidgen)"
imd_id="$(uuidgen_trunc)"

temp_chroot="$(debootstrap bookworm)"

# create disk image, partition it
temp_image="$(mktemp)"

truncate -s 2G "${temp_image}"
parted "${temp_image}" mklabel msdos
parted "${temp_image}" mkpart pri ext2 1m 230m
parted "${temp_image}" mkpart pri fat16 230m 246m
# MIND THE GAP (for a swap partition)
parted "${temp_image}" mkpart pri ext4 768m 100%
parted "${temp_image}" toggle 1 boot

sudo kpartx -a "${temp_image}"
lo_device=$(losetup -a | grep -F '('"${temp_image}"')' | cut -d: -f1 | cut -d/ -f3)
sudo mkfs.ext2 -L "bfs-${BUILD_TIMESTAMP}" -O none,ext_attr,resize_inode,dir_index,filetype,sparse_super -U "${bfs_uuid}" "/dev/mapper/${lo_device}p1"
sudo mkfs.vfat -F16 -n IMD -i "${imd_id}" "/dev/mapper/${lo_device}p2"
sudo mkfs.ext4 -L "rfs-${BUILD_TIMESTAMP}" -U "${rfs_uuid}" "/dev/mapper/${lo_device}p3"

newsys="$(mktemp -d)"

sudo mount "/dev/mapper/${lo_device}p3" "${newsys}"
sudo mkdir -p "${newsys}/boot"
sudo mount "/dev/mapper/${lo_device}p1" "${newsys}/boot"
sudo mkdir -p "${newsys}/IMD"

(cd "${temp_chroot}" && sudo tar cpf - .) | sudo tar xpf - -C "${newsys}"

printf 'UUID=%s / ext4 defaults,noatime 0 1\n' "${rfs_uuid}" | sudo tee "${newsys}/etc/fstab" > /dev/null
printf 'UUID=%s /boot ext2 defaults,noatime 0 2\n' "${bfs_uuid}" | sudo tee -a "${newsys}/etc/fstab" > /dev/null
printf 'UUID=%s /IMD vfat defaults,umask=0077,uid=0,gid=0 0 2\n' "$(munge_vfat_id "${imd_id}")" | sudo tee -a "${newsys}/etc/fstab" > /dev/null

sudo umount "${newsys}/boot"
sudo umount "${newsys}"

sudo kpartx -d "${temp_image}"

rmdir "${newsys}"

case "${temp_chroot}" in
 *tmp*) sudo rm -rf "${temp_chroot}" ;;
esac

mv "${temp_image}" images/upstream/sheeva.img
