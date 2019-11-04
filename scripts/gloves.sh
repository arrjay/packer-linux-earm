#!/bin/sh

set -e

# install nut for ups fun...
apt-get install -qq -y nut nut-monitor apg
printf 'MODE=%s\n' 'netserver' > /etc/nut/nut.conf

# configure that entire stack
# ups.conf is the ups service drivers
cat <<_EOF_> /etc/nut/ups.conf
maxretry = 3

[a]
  driver = usbhid-ups
  port = auto
_EOF_

# upsd.conf is the network ups control plane
cat <<_EOF_> /etc/nut/upsd.conf
LISTEN 0.0.0.0 3493
LISTEN :: 3493
_EOF_

# upsd.users is for ~the children~ authentication
cat <<_EOF_> /etc/nut/upsd.users
[root]
  password = $UPS_ROOT_PASSWORD
  actions = set fsd
  instcmds = all
  upsmon master

[upsmon]
  password = $UPS_UPSMON_PASSWORD
  upsmon slave
_EOF_

# set the hostname
printf '%s\n' 'gloves' > /etc/hostname

# create gloves user
u=gloves

groupadd $u
useradd -g $u $u
rsync -a /etc/skel/ /home/$u/

# tell lightdm to log in automatically
mkdir -p /etc/lightdm/lightdm.conf.d
printf '[SeatDefaults]\nautologin-user=%s\n' $u > /etc/lightdm/lightdm.conf.d/autologin.conf

# disable light-locker
mkdir -p /home/$u/.config/autostart
printf '[Desktop Entry]\nHidden=true\n' > /home/$u/.config/autostart/light-locker.desktop
chown -R $u:$u /home/$u
