#!/usr/bin/env bash

set -e

PFSRC=/tmp/packer-files

# load any environment things we need and export them
. /etc/environment
export $(awk -F= '{ print $1 }' < /etc/environment)

# install just the dropbear binaries for later use.
apt-get install dropbear-bin

cp -R "${PFSRC}/rescue-initramfs" /etc/rescue-initramfs
find /etc/rescue-initramfs/hooks -type f -exec chmod 0755 {} \;
find /etc/rescue-initramfs/scripts -type f -exec chmod 0755 {} \;
chmod 0755 /etc/rescue-initramfs/imdlite

# link the modules file from initramfs-tools
ln -sf /etc/initramfs-tools/modules /etc/rescue-initramfs/modules
