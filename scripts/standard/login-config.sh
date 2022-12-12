#!/bin/sh

set -e

u=ejusdem
h='$6$6fGmOsJL.Ql5uGyI$GLLkrlJRnvkqKDf35.3QfI219fD1/RYTaV1qbHk9Mm.tuMDF17tQ38pPoD/inTo633u8Yq36FDyirlVJKQ3ed.'

# disable pi user
getent passwd pi && passwd -l pi

# add ejusdem user
groupadd $u
useradd -g $u $u
for g in dialout i2c systemd-journal netdev ; do
  getent group $g && usermod -a -G $g $u
done

# create .ssh dir for that, copy the key to it
rsync -a /etc/skel/ /home/$u/
chown -R $u:$u /home/$u/

# force key-only login over ssh
augtool set /files/etc/ssh/sshd_config/PasswordAuthentication no

# remove rpi banner if exists
[ -e /etc/ssh/sshd_config.d/rename_user.conf ] && {
  rm /etc/ssh/sshd_config.d/rename_user.conf
}

# reconfigure sudoers
rm -f /etc/sudoers.d/010_pi-nopasswd
printf '%s ALL=(ALL) NOPASSWD: ALL\n' $u > /etc/sudoers.d/010_$u-nopasswd
chmod 0440 /etc/sudoers.d/010_$u-nopasswd

# set password for user and root to hash from top
usermod -p $h root
usermod -p $h $u

# (rpi) reconfigure /boot filesystem to be root exclusive
case "${PACKER_BUILD_NAME}" in
  pi)
cat <<_EOF_ | augtool
ins opt after /files/etc/fstab/*[file="/boot"]/opt[last()]
set /files/etc/fstab/*[file="/boot"]/opt[last()] umask
set /files/etc/fstab/*[file="/boot"]/opt[last()]/value 0077
ins opt after /files/etc/fstab/*[file="/boot"]/opt[last()]
set /files/etc/fstab/*[file="/boot"]/opt[last()] uid
set /files/etc/fstab/*[file="/boot"]/opt[last()]/value 0
ins opt after /files/etc/fstab/*[file="/boot"]/opt[last()]
set /files/etc/fstab/*[file="/boot"]/opt[last()] gid
set /files/etc/fstab/*[file="/boot"]/opt[last()]/value 0
save
_EOF_
  ;;
esac

# set default target to be just multi-user
systemctl set-default multi-user.target
