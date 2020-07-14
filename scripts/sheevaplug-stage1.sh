#!/bin/env bash

set -ex

# build a stage 1 rootfs
type dirname > /dev/null || { echo "dirname is required" 1>&2 ; exit 1 ; }
SELFDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd "${SELFDIR}/.."
. ./shelllib/common

# check for needed binaries now
__check_progs git date env sleep mktemp tar tee wget kpartx mount parted mkfs.ext2 mkfs.ext4 tee || exit "${?}"

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
    --keyring="${PWD}/keyrings/debian-archive-buster-stable.gpg" \
    ${release} \
    ${rootdir} \
    ${DEBIAN_URI} 1>&2
  rc="${?}"
  echo "${rootdir}"
  return "${rc}"
}

case "${CODEREV}" in
  *-DIRTY) __warn_msg "WARNING: git tree is dirty, sleeping 5 seconds for running confirmation."
           sleep 5
           ;;
esac

echo "building ${CODEREV} at ${BUILD_TIMESTAMP}"

temp_chroot="$(debootstrap buster)"

# create disk image, partition it
temp_image="$(mktemp)"

truncate -s 2G "${temp_image}"
parted "${temp_image}" mklabel msdos
parted "${temp_image}" mkpart pri ext2 1m 230m
parted "${temp_image}" mkpart pri fat16 230m 238m
# MIND THE GAP (for a swap partition)
parted "${temp_image}" mkpart pri ext4 768m 100%
parted "${temp_image}" toggle 1 boot

sudo kpartx -a "${temp_image}"
lo_device=$(losetup -a | grep -F '('"${temp_image}"')' | cut -d: -f1 | cut -d/ -f3)
sudo mkfs.ext2 -L "bfs-${BUILD_TIMESTAMP}" -O none,ext_attr,resize_inode,dir_index,filetype,sparse_super "/dev/mapper/${lo_device}p1"
sudo mkfs.vfat -F16 -n IMD "/dev/mapper/${lo_device}p2"
sudo mkfs.ext4 -L "rfs-${BUILD_TIMESTAMP}" "/dev/mapper/${lo_device}p3"

newsys="$(mktemp -d)"

sudo mount "/dev/mapper/${lo_device}p3" "${newsys}"
sudo mkdir -p "${newsys}/boot"
sudo mount "/dev/mapper/${lo_device}p1" "${newsys}/boot"
sudo mkdir -p "${newsys}/boot/IMD"

(cd "${temp_chroot}" && sudo tar cpf - .) | sudo tar xpf - -C "${newsys}"

printf 'LABEL=%s / ext4 defaults,noatime 0 1\n' "rfs-${BUILD_TIMESTAMP}" | sudo tee "${newsys}/etc/fstab" > /dev/null
printf 'LABEL=%s /boot ext2 defaults,noatime 0 2\n' "bfs-${BUILD_TIMESTAMP}" | sudo tee -a "${newsys}/etc/fstab" > /dev/null

sudo umount "${newsys}/boot"
sudo umount "${newsys}"

sudo kpartx -d "${temp_image}"

rmdir "${newsys}"

case "${temp_chroot}" in
 *tmp*) sudo rm -rf "${temp_chroot}" ;;
esac

mkdir -p images/upstream
mv "${temp_image}" images/upstream/sheevaplug-s1.img
