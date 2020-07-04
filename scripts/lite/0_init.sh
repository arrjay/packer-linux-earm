#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# just for comparison...
df -m

# install environment files by concatenating them
cat "${PFSRC}/environment" >> /etc/environment
[[ -f "${PFSRC}/environment-${PACKER_BUILD_NAME}" ]] && cat "${PFSRC}/environment-${PACKER_BUILD_NAME}" >> /etc/environment
chown 0:0 /etc/environment
chmod 0644 /etc/environment

# load any environment things we need and export them
. /etc/environment
export $(awk -F= '{ print $1 }' < /etc/environment)

# (rpi) drop dist hack for init, create serial-oriented command line
[[ -f /boot/cmdline.txt ]] && {
  sed -i -e 's@ init=[0-9a-zA-Z/_.\-]\+@@' /boot/cmdline.txt
  sed -e 's/console=tty1//' -e 's/quiet//' -e 's/ +//' < /boot/cmdline.txt > /boot/serial.txt
}

# (rpi) append initramfs loading to config.txt
[[ -e /boot/config.txt ]] && [[ -f "${PFSRC}/${PACKER_BUILD_NAME}/config.txt" ]] && \
  cat "${PFSRC}/${PACKER_BUILD_NAME}/config.txt" >> /boot/config.txt

# (rpi) configure initramfs generation
[[ -f /etc/default/raspberrypi-kernel ]] && {
  printf 'RPI_INITRD=%s\n' 'Yes' >> /etc/default/raspberrypi-kernel
}

# recursion function for walking around in /tmp, installing to /etc
install_ef () {
  local s d
  while (( "$#" )) ; do
    s="${1}" ; shift
    [[ -e "${s}" ]] || exit 0
    [[ -d "${s}" ]] && { "${FUNCNAME[0]}" "${s}"/* ; continue ; }
    d="${s#/tmp}"
    install --verbose --mode="${INSTALL_MODE:-0644}" --owner=0 --group=0 -D "${s}" "/etc${d}"
  done
}

# install system configs from packer file provisioner
for source in \
  "${PFSRC}/apt" \
  "${PFSRC}/dpkg" \
  "${PFSRC}/systemd" \
  "${PFSRC}/${PACKER_BUILD_NAME}/apt" \
 ; do
  [[ -d "${source}" ]] && cp -R "${source}" /tmp
done

# install from scratch directories into filesystem, clean them back up
for directory in /tmp/apt /tmp/dpkg /tmp/systemd ; do
  install_ef "${directory}"
  rm -rf "${directory}"
done

# kernel/initrd hooks from packer file provisioner
for source in \
  "${PFSRC}/initramfs-tools" \
  "${PFSRC}/${PACKER_BUILD_NAME}/initramfs-tools" \
  "${PFSRC}/${PACKER_BUILD_NAME}/kernel" \
 ; do
  [[ -d "${source}" ]] && cp -R "${source}" /tmp
done

for directory in /tmp/initramfs-tools /tmp/kernel ; do
  INSTALL_MODE=0755 install_ef "${directory}"
  rm -rf "${directory}"
done

# force the update as root, otherwise this fails in some packer-chroots
apt-get -o APT::Sandbox::User=root update

# delete anything from that now
find /usr/share/doc -depth -type f ! -name copyright|xargs rm || true
find /usr/share/doc -empty|xargs rmdir || true
rm -rf /usr/share/groff/* /usr/share/info/* /usr/share/man/*
rm -rf /usr/share/lintian/* /usr/share/linda/* /var/cache/man/*

# (rpi) configure pi locale
type raspi-config >/dev/null 2>&1 && {
  raspi-config nonint do_configure_keyboard us
  raspi-config nonint do_change_locale en_US.UTF-8
}

# server runs in UCT kthxbye
ln -sf /usr/share/zoneinfo/UCT /etc/localtime

# configure localepurge, make ssl shut _up_
libssl=$(dpkg -l | grep libssl | awk '{print $2}') 
printf '%s\n' "localepurge localepurge/use-dpkg-feature boolean false" \
              "localepurge localepurge/mandelete boolean true" \
              "localepurge localepurge/dontbothernew boolean true" \
              "localepurge localepurge/showfreedspace boolean false" \
              "localepurge localepurge/quickndirtycale boolean true" \
              "localepurge localepurge/verbose boolean false" \
              "localepurge localepurge/nopurge string en,en_US,en_US.UTF-8" \
              "${libssl} libraries/restart-without-asking boolean true" \
 | debconf-set-selections
apt-get install localepurge
localepurge
echo "localepurge localepurge/use-dpkg-deature boolean true" | debconf-set-selections
dpkg-reconfigure localepurge

# (rpi) create the initrds
[[ -x /etc/kernel/postinst.d/rpi-initramfs ]] && {
  RPI_INITRD=yes /etc/kernel/postinst.d/rpi-initramfs
}

# clean up the entire source directory
rm -rf "${PFSRC}"

# collect stats for next image...
df -m
