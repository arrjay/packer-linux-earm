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
    [[ -e "${s}" ]] || continue
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

# reset hostnames for these to the builder name
echo "${PACKER_BUILD_NAME}" > /etc/hostname

# temporarily move backports.list away while installing the key for it
[[ -f /etc/apt/sources.list.d/backports.list ]] && {
  mv /etc/apt/sources.list.d/backports.list /etc/apt/sources.list.d/backports.list.disabled
}

# force the update as root, otherwise this fails in some packer-chroots
apt-get -o APT::Sandbox::User=root update

# install backports key, move backports back, update again
[[ -f /etc/apt/sources.list.d/backports.list.disabled ]] && {
  apt-get install gnupg2
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
  mv /etc/apt/sources.list.d/backports.list.disabled /etc/apt/sources.list.d/backports.list
  apt-get -o APT::Sandbox::User=root update
}

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

# if we don't have /bin -> /usr/bin and such, install usrmerge
readlink /bin > /dev/null || apt-get install usrmerge

# common packages to all systems at this point.
apt-get install \
 systemd systemd-sysv \
 mawk util-linux parted \
 iproute2 bind9utils dnsutils \
 openssh-client openssh-server openssh-sftp-server

# (sheeva) install a kernel, flash-tools
case "${PACKER_BUILD_NAME}" in
  sheeva)
    # HACK: install the kernel and utils here
    FK_MACHINE=none apt-get install u-boot-tools flash-kernel linux-image-marvell
  ;;
esac

# install the resize-rootfs service script now
install --verbose --mode=0755 --owner=0 --group=0 -D "${PFSRC}/resize-rootfs.sh" "/usr/lib/untrustedhost/scripts/resize-rootfs.sh"

# wipe any ssh keys
rm -rf /etc/ssh/ssh_host_*_key*

# (rpi) create the initrds
[[ -x /etc/kernel/postinst.d/rpi-initramfs ]] && {
  RPI_INITRD=yes /etc/kernel/postinst.d/rpi-initramfs
}

# (sheeva) assemble the kernel and initrd - these values are hardcoded for a sheevaplug (kirkwood)
# all this is assuming there is exactly one kernel installed.
case "${PACKER_BUILD_NAME}" in
  sheeva)
    kblob="$(mktemp)"
    cat /boot/vmlinuz-* /usr/lib/linux-image-*/kirkwood-sheevaplug.dtb > "${kblob}"
    # for the initrd, wire it to locate rootfs by LABEL (which was wired back in stage1)
    rfs="$(grep ' / ' /etc/fstab | cut -d' ' -f1)"
    for v in /lib/modules/* ; do
      k="${v##*/}"
      mkinitramfs -o "/boot/initrd.img-${k}" -r "${rfs}" "${k}"
    done
    mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n kernel -d "${kblob}" /boot/uImage
    mkimage -A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0 -n ramdisk -d /boot/initrd.img-* /boot/uInitrd
    rm "${kblob}"
  ;;
esac

# clean up the entire source directory
rm -rf "${PFSRC}"

# collect stats for next image...
df -m
