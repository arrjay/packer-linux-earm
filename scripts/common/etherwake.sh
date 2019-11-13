#!/bin/sh

# this is an optional component

# install etherwake, copy over /etc/ethers
apt-get -qq -y install etherwake
groupadd etherwake
usermod -a -G etherwake ejusdem
chown root:etherwake /usr/sbin/etherwake
chmod 4750 /usr/sbin/etherwake
cp /tmp/common/ethers /etc/ethers
chown root:etherwake /etc/ethers
chmod 640 /etc/ethers
