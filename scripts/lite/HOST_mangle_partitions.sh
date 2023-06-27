#!/usr/bin/env bash

set -ex

# commands check
for item in jq mlabel tune2fs kpartx fatlabel e2fsck fdisk ; do
  type "${item}" 2>/dev/null 1>&2
done

update_disk_id () {
  dev="${1}"
  id="${2}"
  printf 'x\ni\n0x%s\n\r\n\w\n' "${id}" | fdisk "${dev}"
}

update_fatboot_fs () {
  dev="${1}"
  id="${2}"
  mlabel -N "${id}" -i "${dev}"
  fatlabel "${dev}" boot
}

update_ext2_uuid () {
  dev="${1}"
  id="${2}"
  e2fsck -fy "${dev}"
  tune2fs -U "${id}" "${dev}"
}

# pick up the image file from the packer manifest
imagefile="$(jq -r '.builds[] | select(.packer_run_uuid=="'"${PACKER_RUN_UUID}"'") | .files[0].name' packer-manifest.json)"
[[ -f "${imagefile}" ]] || exit 1

# map the file and perform per-partition actions
for loop in $(kpartx -a -v "${imagefile}" | awk '{ print $3 }') ; do
  case "${loop}" in
    *1)
      case "${PACKER_BUILD_NAME}" in
        pi) update_fatboot_fs "/dev/mapper/${loop}" "${bootfs_id}" ;;
      esac
    ;;
    *2)
      case "${PACKER_BUILD_NAME}" in
        pi) update_ext2_uuid "/dev/mapper/${loop}" "${rootfs_uuid}" ;;
      esac
    ;;
  esac
done

while : ; do
  kpartx -d "${imagefile}" && break
done

case "${PACKER_BUILD_NAME}" in
  pi) update_disk_id "${imagefile}" "${partition_id}" ;;
esac
