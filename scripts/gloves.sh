#!/usr/bin/env bash

set -e

# copy stable host keys to image
ln -s /dev/null /etc/systemd/system/regenerate_ssh_host_keys.service
mv /tmp/gloves/ssh_host_*_key /etc/ssh
chmod 0600 /etc/ssh/ssh_host_*_key
for k in /etc/ssh/ssh_host_*_key ; do
  [[ -f $k ]] && ssh-keygen -y -f $k > $k.pub
done

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

# install synergy
dpkg -i /tmp/synergy.deb || true
apt-get install -qq -y -f

# create use for ssh tunneling of synergy
u=tunnel
groupadd $u
useradd -g $u $u
mkdir -p /home/$u/.ssh

# restrict this user to allow the synergy port, 24800 via ssh authorized_key wrangling
p=24800
while read -r t k r ; do
  case $t in ssh-*) : ;; *) continue ;; esac
  printf 'command="/bin/true",restrict,port-forwarding,permitopen="localhost:%s",permitopen="127.0.0.1:%s" %s %s %s\n' $p $p $t $k $r > /home/$u/.ssh/authorized_keys
done < /tmp/gloves/sshpub_tunnel_keys

chown -R $u:$u /home/$u
