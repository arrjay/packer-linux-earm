#!/usr/bin/env bash

set -ex

for item in jq mlabel tune2fs kpartx ; do
  type "${item}" 2>/dev/null 1>&2
done

imagefile="$(jq -r '.builds[] | select(.packer_run_uuid=="'"${PACKER_RUN_UUID}"'") | .files[0].name' packer-manifest.json)"
[[ -f "${imagefile}" ]]

for loop in $(kpartx -a -v "${imagefile}" | awk '{ print $3 }') ; do
  case "${loop}" in
    *1)
      mlabel -N "${bootfs_id}"  -i "/dev/mapper/${loop}"
      fatlabel "/dev/mapper/${loop}" boot
    ;;
    *2) tune2fs -U "${rootfs_uuid}"  "/dev/mapper/${loop}" ;;
  esac
done

kpartx -d "${imagefile}"

printf 'x\ni\n0x%s\nr\nw\n' "${partition_id}" | fdisk "${imagefile}"
