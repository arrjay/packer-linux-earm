#!/usr/bin/env bash

set -e
shopt -s dotglob

export DEBIAN_FRONTEND=noninteractive
PFSRC=/tmp/packer-files

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
  "${PFSRC}/skel" \
 ; do
  [[ -d "${source}" ]] && cp -R "${source}" /tmp
done

# install from scratch directories into filesystem, clean them back up
for directory in /tmp/skel ; do
  install_ef "${directory}"
  rm -rf "${directory}"
done

# blueman will not shut up about this
mkdir /etc/skel/Downloads

additional_packages=()
case "${PACKER_BUILD_NAME}" in
  pi)
    additional_packages=('xserver-xorg-video-fbturbo')
  ;;
esac

apt-get -qq clean
apt-get -qq -y install xserver-xorg xserver-xorg-video-fbdev xserver-xorg-input-all \
               lightdm xfce4 xfce4-screenshooter xfce4-terminal xfce4-power-manager \
               xfonts-terminus fonts-terminus \
               solaar blueman scdaemon virt-manager "${additional_packages[@]}"
apt-get -qq clean

# disable the newer vc4 graphics stack. reasons.
[[ -e /boot/config.txt ]] && sed -i -e 's/^dtoverlay=vc4-/#dtoverlay=vc4-/g' /boot/config.txt

# the multihead setup is only test on pi. anything else is hopefully not this silly.
case "${PACKER_BUILD_NAME}" in
  pi)
    ln -sf /run/untrustedhost/xorg.conf.d /etc/X11/xorg.conf.d
    mkdir -p /usr/lib/untrustedhost/xorg.conf.d
    for f in "${PFSRC}/xorg.conf.d"/* ; do
      [[ -f "${f}" ]] && install --verbose --mode=0644 --owner=0 --group=0 "${f}" "/usr/lib/untrustedhost/xorg.conf.d/${f##*/}"
    done
    for f in "${PFSRC}/imd"/* ; do
      [[ -f "${f}" ]] && install --verbose --mode=0755 --owner=0 --group=0 "${f}" "/usr/lib/untrustedhost/imd/${f##*/}"
    done
    ;;
esac

# this is done after the base xfce4 install because we're riding the line of image space
apt-get -qq -y install chromium-browser
apt-get -qq clean

printf 'XFCE_PANEL_MIGRATE_DEFAULT=1\n' >> /etc/environment

mkdir -p /etc/systemd/system/lightdm.service.d
printf '[Unit]\nConditionPathExists=/sys/class/backlight/rpi_backlight\n' > /etc/systemd/system/lightdm.service.d/req-backlight.conf
ln -s /lib/systemd/system/lightdm.service /etc/systemd/system/multi-user.target.wants/lightdm.service
ln -s /dev/null /etc/systemd/system/plymouth-quit-wait.service

# wire gfx user for autologin via lightdm
u=gfx

groupadd $u
useradd -g $u $u
rsync -a /etc/skel/ /home/$u/

mkdir -p /etc/lightdm/lightdm.conf.d
printf '[SeatDefaults]\nautologin-user=%s\n' $u > /etc/lightdm/lightdm.conf.d/autologin.conf

# disable light-locker
mkdir -p /home/$u/.config/autostart
printf '[Desktop Entry]\nHidden=true\n' > /home/$u/.config/autostart/light-locker.desktop

# finish with this user.
chown -R $u:$u /home/$u

# report disk usage
df -h
