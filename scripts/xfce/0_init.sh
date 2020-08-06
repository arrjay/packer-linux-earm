#!/bin/sh

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get -qq clean
apt-get -qq -y install xfce4 xfce4-screenshooter xfce4-terminal solaar blueman scdaemon virt-manager
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
