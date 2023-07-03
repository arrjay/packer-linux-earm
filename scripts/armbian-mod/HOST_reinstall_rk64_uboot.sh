#!/usr/bin/env bash

set -ex

imagefile="$(jq -r '.builds[] | select(.packer_run_uuid=="'"${PACKER_RUN_UUID}"'") | .files[0].name' packer-manifest.json)"
[[ -f "${imagefile}" ]]

ubfile="files/armbian_mod/cache/rock64_uboot.tar"
[[ -f "${ubfile}" ]]

rcwd="${PWD}"
tdir="$(mktemp -d)"
( cd "${tdir}" && tar xvf "${rcwd}/${ubfile}" )

. "${tdir}/platform_install.sh"

write_uboot_platform "${tdir}" "${imagefile}"

rm -rf "${tdir}"
