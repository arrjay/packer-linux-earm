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

apt-get -qq clean
apt-get -qq -y install xserver-xorg xserver-xorg-video-fbdev xserver-xorg-input-all \
               lightdm xfce4 xfce4-screenshooter xfce4-terminal \
               xfonts-terminus \
               solaar blueman scdaemon virt-manager
apt-get -qq clean

# this is done after the base xfce4 isntall because we're riding the line of image space
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
