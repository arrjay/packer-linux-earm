#!/bin/sh

set -e

u=ejusdem

# install augtool
apt-get -qq -y install augeas-tools

# disable pi user
passwd -l pi

# add ejusdem user
groupadd $u
useradd -g $u $u

# create .ssh dir for that, copy the key to it
mkdir -p /home/$u/.ssh
[ -f /tmp/SSH_PUB ] && mv /tmp/SSH_PUB /home/$u/.ssh/authorized_keys
chown -R $u:$u /home/$u/

# force key-only login over ssh
augtool set /files/etc/ssh/sshd_config/PasswordAuthentication no

# enable ssh pi-style
touch /boot/ssh

# reconfigure sudoers
rm -f /etc/sudoers.d/010_pi-nopasswd
printf '%s ALL=(ALL) NOPASSWD: ALL\n' $u > /etc/sudoers.d/010_$u-nopasswd
chmod 0440 /etc/sudoers.d/010_$u-nopasswd
