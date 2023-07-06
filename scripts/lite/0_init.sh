#!/usr/bin/env bash

set -ex

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# just for comparison...
df -m

# stomp on resolv.conf
rm /etc/resolv.conf
cp "${PFSRC}/cache/resolv.conf" /etc/resolv.conf

# stomp on gai.conf, we're in ipv4 here. no regrets.
printf '%s\n' 'precedence ::ffff:0:0/96  100' > /etc/gai.conf

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
  # switch to using FS UUID for root FS discovery
  sed -i -e 's@ root=[0-9a-zA-Z/_.\=-]\+@ root=UUID='"${pi_rootfs_uuid}"'@' /boot/cmdline.txt
  # arm luksipc
  sed -i -e 's@ root=@ luksipc=PARTUUID='"${pi_disk_id}"'-02 root=@' /boot/cmdline.txt
  # create variant using serial for config.txt ease
  sed -e 's/console=tty1//' -e 's/quiet//' -e 's/ +//' < /boot/cmdline.txt > /boot/serial.txt
}

# (rpi) append initramfs loading to config.txt
[[ -e /boot/config.txt ]] && [[ -f "${PFSRC}/${PACKER_BUILD_NAME}/config.txt" ]] && \
  cat "${PFSRC}/${PACKER_BUILD_NAME}/config.txt" >> /boot/config.txt

# (rpi) configure initramfs generation
[[ -f /etc/default/raspberrypi-kernel ]] && {
  printf 'RPI_INITRD=%s\n' 'Yes' >> /etc/default/raspberrypi-kernel
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

# (rpi/rock64) stomp on fstab
case "${PACKER_BUILD_NAME}" in
  pi)
    {
      printf 'UUID=%s / ext4 defaults,noatime 0 1\n' "${pi_rootfs_uuid}"
      printf 'UUID=%s /boot vfat defaults,umask=0077,uid=0,gid=0 0 2\n' "$(munge_vfat_id "${pi_bootfs_id}")"
    } > /etc/fstab
  ;;
  rock64)
    {
      printf 'UUID=%s /boot ext2 defaults,noatime,errors=remount-ro 0 2\n' "${rock64_bootfs_uuid}"
      printf 'UUID=%s /IMD vfat defaults,umask=0077,uid=0,gid=0 0 2\n' "$(munge_vfat_id "${rock64_imdfs_id}")"
    } >> /etc/fstab
  ;;
  espressobin)
    {
      printf 'UUID=%s /boot ext2 defaults,noatime,errors=remount-ro 0 2\n' "${espressobin_bootfs_uuid}"
      printf 'UUID=%s /IMD vfat defaults,umask=0077,uid=0,gid=0 0 2\n' "$(munge_vfat_id "${espressobin_imdfs_id}")"
    } >> /etc/fstab
  ;;
esac

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

# move the cryptsetup-initramfs conf-hook out of the way
dpkg-divert --rename /etc/cryptsetup-initramfs/conf-hook

# install system configs from packer file provisioner
for source in \
  "${PFSRC}/apt" \
  "${PFSRC}/dpkg" \
  "${PFSRC}/systemd" \
  "${PFSRC}/cryptsetup-initramfs" \
  "${PFSRC}/${PACKER_BUILD_NAME}/apt" \
 ; do
  [[ -d "${source}" ]] && cp -R "${source}" /tmp
done

# install from scratch directories into filesystem, clean them back up
for directory in /tmp/apt /tmp/cryptsetup-initramfs /tmp/dpkg /tmp/systemd ; do
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
  # ???
  rm -f /etc/initramfs-tools/scripts/local-premount/luksipc
  ln /etc/initramfs-tools/scripts/local-block/luksipc /etc/initramfs-tools/scripts/local-premount/luksipc
done

# reset hostnames for these to the builder name
echo "${PACKER_BUILD_NAME}" > /etc/hostname

# temporarily move backports.list away while installing the key for it
[[ -f /etc/apt/sources.list.d/backports.list ]] && {
  mv /etc/apt/sources.list.d/backports.list /etc/apt/sources.list.d/backports.list.disabled
}

# force the update as root, otherwise this fails in some packer-chroots
apt-get update

# install backports key, move backports back, update again
[[ -f /etc/apt/sources.list.d/backports.list.disabled ]] && {
  apt-get install gnupg2
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
  mv /etc/apt/sources.list.d/backports.list.disabled /etc/apt/sources.list.d/backports.list
  apt-get update
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

# (rpi) reinstall rpi-eeprom-images, this packaging sucks with nodoc
mkdir /usr/share/man/man1
chmod 0755 /usr/share/man/man1
dpkg -l rpi-eeprom-images > /dev/null && apt-get reinstall rpi-eeprom-images
dpkg -l rpi-eeprom        > /dev/null && apt-get reinstall rpi-eeprom

# server runs in UCT kthxbye
ln -sf /usr/share/zoneinfo/UCT /etc/localtime

# configure localepurge, make ssl shut _up_
apt-get install locales
# older locale-gen only reads locale.gen - but it also ignores all arguments.
grep -q '^en_US.UTF-8 UTF-8$' /etc/locale.gen || printf '%s %s\n' 'en_US.UTF-8' 'UTF-8' >> /etc/locale.gen
locale-gen en_US.UTF-8
case "${PACKER_BUILD_NAME}" in
  sheeva) libssl="libssl3" ;; # hack for a libssl I don't yet have?
  *) libssl=$(dpkg -l | grep libssl | awk '{print $2}' |grep -v dev) ;;
esac
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
echo "localepurge localepurge/use-dpkg-feature boolean true" | debconf-set-selections
dpkg-reconfigure localepurge

# if we don't have /bin -> /usr/bin and such, install usrmerge
readlink /bin > /dev/null || apt-get install usrmerge

# common packages to all systems at this point.
apt-get install \
 systemd systemd-sysv \
 mawk util-linux parted \
 iproute2 bind9utils dnsutils \
 rsync sudo vim curl tmux \
 augeas-tools mtools dpkg-dev \
 ca-certificates openssh-client openssh-server openssh-sftp-server \
 cryptsetup cryptsetup-initramfs zstd fdisk

# pi's udev rules are *broken* for gpio. or maybe systemd is broken. I don't care, just fix it.
case "${PACKER_BUILD_NAME}" in
  pi)
    rpi_gpio_sum="$(md5sum /usr/lib/udev/rules.d/60-rpi.gpio-common.rules)"
    rpi_gpio_sum="${rpi_gpio_sum% *}"
    case "${rpi_gpio_sum}" in
      f9bbb85798060dfe95239e7f4674c12d)
        rm /usr/lib/udev/rules.d/60-rpi.gpio-common.rules
        cp "${PFSRC}/pi/60-rpi.gpio-common.rules" /etc/udev/rules.d
      ;;
    esac
  ;;
esac

# do exceedingly wacky thing in case c_rehash just...didn't do anything
for f in /etc/ssl/certs/* ; do
  case "${f}" in
    *.0) continue ;;
  esac
  hf="$(openssl x509 -hash -noout -in "${f}").0"
  [[ -e "/etc/ssl/certs/${hf}" ]] || {
    ln -s ".${f#/etc/ssl/certs}" "/etc/ssl/certs/${hf}"
  }
done

# (armbian) configure maximal verbosity
[[ -f /boot/armbianEnv.txt ]] && {
  printf '%s\n' \
    'set /augeas/load/Simplevars/lens Simplevars.lns' \
    'set /augeas/load/Simplevars/incl /boot/armbianEnv.txt' \
    'load' \
    'set /files/boot/armbianEnv.txt/verbosity 7' \
    'set /files/boot/armbianEnv.txt/console serial' \
    'save' \
  | augtool -A
  sed -i -e 's/ = /=/' /boot/armbianEnv.txt
}

arm_luksipc () {
  partuuid="${1}"
  envfile="${2}"
  printf '%s\n' \
    'set /augeas/load/Simplevars/lens Simplevars.lns' \
    'set /augeas/load/Simplevars/incl '"${envfile}" \
    'load' \
    'set /files'"${envfile}"'/extraargs luksipc=PARTUUID='"${partuuid}" \
    'save' \
  | augtool -A
  sed -i -e 's/ = /=/' "${envfile}"
}

case "${PACKER_BUILD_NAME}" in
  # (rock64) arm luksipc
  rock64)
    arm_luksipc "${rock64_disk_id}-03" "/boot/armbianEnv.txt"
  ;;
  espressobin)
    arm_luksipc "${espressobin_disk_id}-03" "/boot/armbianEnv.txt"
    # HACK: we also made the kernel stop screaming about hwmon while running initramfs.
    sed -i -e 's/luksipc=/loglevel=2 luksipc=/' "/boot/armbianEnv.txt"
  ;;
  # (sheeva) install a kernel, flash-tools
  sheeva)
    # HACK: install the kernel and utils here
    FK_MACHINE=none apt-get install u-boot-tools flash-kernel linux-image-marvell
    # also the addswap service
    systemctl enable addswap.service
    arm_luksipc "${sheeva_disk_id}-03" "/boot/sheevaEnv.txt"
  ;;
esac

# install the resize-rootfs, sshd-keygen service scripts now
install --verbose --mode=0755 --owner=0 --group=0 -D "${PFSRC}/resize-rootfs.sh" "/usr/lib/untrustedhost/scripts/resize-rootfs.sh"
install --verbose --mode=0755 --owner=0 --group=0 -D "${PFSRC}/sshd-keygen" "/usr/lib/untrustedhost/scripts/sshd-keygen"
install --verbose --mode=0755 --owner=0 --group=0 -D "${PFSRC}/addswap.sh" "/usr/lib/untrustedhost/scripts/addswap.sh"
install --verbose --mode=0755 --owner=0 --group=0 -D "${PFSRC}/postluksipc.sh" "/usr/lib/untrustedhost/scripts/postluksipc.sh"

# install our custom services
systemctl enable resize-rootfs.service
systemctl enable resolvlink.service
systemctl enable postluksipc.service
systemctl enable privsep-apt.service

# wipe any ssh keys
rm -rf /etc/ssh/ssh_host_*_key*
# and disable rpi's service that makes them.
systemctl disable regenerate_ssh_host_keys.service || true

# disable rpi's resize rootfs service too.
systemctl disable resize2fs_once.service || true

# add cryptsetup stuff to initrds
grep -q ^CRYPTSETUP=y /etc/initramfs-tools/initramfs.conf || printf '%s\n' 'CRYPTSETUP=y' >> /etc/initramfs-tools/initramfs.conf

# (rpi) create the initrds
[[ -x /etc/kernel/postinst.d/rpi-initramfs ]] && {
  for kv in /lib/modules/* ; do
    case "${kv}" in
      *-v7+)   kimage=kernel7.img  ;;
      *-v7l+)  kimage=kernel7l.img ;;
      *-v8+)   kimage=kernel8.img  ;;
      *[0-9]+) kimage=kernel.img   ;;
    esac
    RPI_INITRD=yes /etc/kernel/postinst.d/rpi-initramfs "${kv##*/}" "/boot/${kimage}"
  done
}

# (sheeva) assemble the kernel and initrd - these values are hardcoded for a sheevaplug (kirkwood)
# all this is assuming there is exactly one kernel installed.
case "${PACKER_BUILD_NAME}" in
  sheeva)
    kblob="$(mktemp)"
    cat /boot/vmlinuz-* /usr/lib/linux-image-*/kirkwood-sheevaplug.dtb > "${kblob}"
    # for the initrd, wire it to locate rootfs by LABEL (which was wired back in stage1)
    # this does work...but it leads to side-effects from stuff that parses the command line.
    rfs="$(grep ' / ' /etc/fstab | cut -d' ' -f1)"
    for v in /lib/modules/* ; do
      k="${v##*/}"
      mkinitramfs -o "/boot/initrd.img-${k}" -r "${rfs}" "${k}"
    done
    # copy over the dtb for use with a newer version of u-boot (which we're not yet)
    mkdir /boot/dtb
    cp /usr/lib/linux-image-*/kirkwood-sheevaplug.dtb /boot/dtb/kirkwood-sheevaplug.dtb
    # but, this boot script will let us tinker with the rootfs args.
    cp /tmp/packer-files/sheeva/boot.cmd /boot/boot.cmd
    mkimage -A arm -T script -C none -d /boot/boot.cmd /boot/boot.scr
    printf 'linux_rootdev=%s\n' "${rfs}" >> /boot/sheevaEnv.txt
    mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n kernel -d "${kblob}" /boot/uImage
    mkimage -A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0 -n ramdisk -d /boot/initrd.img-* /boot/uInitrd
    rm "${kblob}"
  ;;
esac

# clean up the entire source directory
# actually, do this after network setup. should probably move to a zz script and do proper run-parts.
#rm -rf "${PFSRC}"

# collect stats for next image...
df -m
