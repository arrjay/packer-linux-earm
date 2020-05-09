#!/bin/sh

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get -qq -y install xfce4 xfce4-screenshooter xfce4-terminal solaar blueman scdaemon

printf 'XFCE_PANEL_MIGRATE_DEFAULT=1\n' >> /etc/environment

mkdir -p /etc/systemd/system/lightdm.service.d
printf '[Unit]\nConditionPathExists=/sys/class/backlight/rpi_backlight\n' > /etc/systemd/system/lightdm.service.d/req-backlight.conf
ln -s /lib/systemd/system/lightdm.service /etc/systemd/system/multi-user.target.wants/lightdm.service
ln -s /dev/null /etc/systemd/system/plymouth-quit-wait.service
