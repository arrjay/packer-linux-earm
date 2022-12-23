#!/usr/bin/env bash

# if we're called, luksipc should have been in the kernel params. go see if that's a LUKS volume and readjust initramfs.

srcarg=''
read -r -a args < /proc/cmdline
for arg in "${args[@]}" ; do
  case "${arg}" in
    luksipc=*) srcarg="${arg#luksipc=}" ;;
  esac
done

# if we don't have that kernel arg...go away
[[ "${srcarg}" ]] || exit 0

case "${srcarg}" in
  *=*)
    lsbk="$(echo "${srcarg}" | awk -F= '{ print $1 }')"
    lsbv="$(echo "${srcarg}" | awk -F= '{ gsub(/"/, "", $2) ; print $2 }')"
    srcdev="$(blkid | awk -F: '$2 ~ "'"${lsbk}"'=\"'"${lsbv}"'\"" { print $1 }')"
  ;;
esac

# if the thing at the end of luksipc is _not_ LUKS...go away
has_luks=0
read -r -a srcdata < <(blkid "${srcdev}")
for data in "${srcdata[@]}" ; do
  case "${data}" in
    'TYPE="crypto_LUKS"') has_luks=1 ;;
  esac
done

[[ "${has_luks}" -eq 1 ]] || exit 0

# get uuid for mapping
luksuuid="$(cryptsetup luksUUID "${srcdev}")"
[[ "${luksuuid}" ]] || exit 1

# go looking for the key - NOTE: currently we don't verify it's the right key.
[[ -f /etc/untrustedhost/imd.conf ]] && . /etc/untrustedhost/imd.conf

[[ "${mount_source:-}" ]] && {
	echo "ah, now what?"
	exit 1
}

[[ -f /boot/luksipc.key ]] && [[ -s /boot/luksipc.key ]] && {
  # fix crypttab
  printf 'luks-%s UUID=%s %s\n' "${luksuuid}" "${luksuuid}" none >> /etc/crypttab.luksipc

  # regenerate initramfs
  [[ -x /etc/kernel/postinst.d/rpi-initramfs ]] && {
    for kv in /lib/modules/* ; do
      case "${kv}" in
        *-v7+)   kimage=kernel7.img ;;
        *-v7l+)  kimage=kernel7l.img ;;
        *-v8+)   kimage=kernel8.img ;;
        *[0-9]+) kimage=kernel.img ;;
      esac
      RPI_INITRD=1 /etc/kernel/postinst.d/rpi-initramfs "${kv##*/}" "/boot/${kimage}"
    done
  }

  # remove commandlines
  #for file in /boot/cmdline.txt /boot/serial.txt ; do
  #  [[ -f "${file}" ]] && sed -i -e 's@luksipc=[0-9A-Za-z/_.\=-]\+@@' "${file}"
  #done
}
