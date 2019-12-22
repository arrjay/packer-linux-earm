#!/bin/sh

set -e

u=ejusdem
h='$6$6fGmOsJL.Ql5uGyI$GLLkrlJRnvkqKDf35.3QfI219fD1/RYTaV1qbHk9Mm.tuMDF17tQ38pPoD/inTo633u8Yq36FDyirlVJKQ3ed.'

# disable pi user
passwd -l pi

# add ejusdem user
groupadd $u
useradd -g $u $u
for g in dialout i2c systemd-journal netdev ; do
  usermod -a -G $g $u
done

# create .ssh dir for that, copy the key to it
mkdir -p /home/$u/.ssh
rsync -a /etc/skel/ /home/$u/
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

# set password for user and root to hash from top
usermod -p $h root
usermod -p $h $u
