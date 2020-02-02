#!/bin/sh

# this is an optional component

# install etherwake, copy over /etc/ethers
apt-get -qq -y install etherwake
groupadd etherwake
usermod -a -G etherwake ejusdem
usermod -a -G etherwake ssm-user
chown root:etherwake /usr/sbin/etherwake
chmod 4750 /usr/sbin/etherwake
cp /tmp/common/ethers /etc/ethers
chown root:etherwake /etc/ethers
chmod 640 /etc/ethers

# have a stupid wake script too
cat <<"_EOF_">/usr/local/bin/wake
#!/usr/bin/env bash

for d in /sys/class/net/*/device ; do
  i="${d%/device}" ; i="${i##*/}"
  etherwake -i $i $1
done
chmod 755 /usr/local/bin/wake
_EOF_
