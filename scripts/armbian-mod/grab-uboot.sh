#!/usr/bin/env bash

# go pick up uboot bits and pack into /tmp/uboot.tar
TDIR=$(mktemp -d)

while read -r path ; do
  case "${path}" in
    */idbloader.img|*/u-boot.itb|*/platform_install.sh)
      cp "${path}" "${TDIR}"
    ;;
  esac
done < <(dpkg -L linux-u-boot-rock64-current)

( cd "${TDIR}" && tar cvf /tmp/uboot.tar . )
