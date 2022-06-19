#!/usr/bin/env bash

set -ex
shopt -s dotglob

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

apt-get -qq clean
apt-get -qq -y install yubikey-personalization \
                       yubikey-personalization-gui \
                       yubikey-manager
apt-get -qq clean

u=gfx
# NOTE: position-dependent arguments...
tar xvf "${PFSRC}/cache/misc-scripts.tar" -C "/home/${u}" --strip-components=1 noarch/cardykey.sh
chmod +x "/home/${u}/cardykey.sh"
chown -R "${u}:${u}" "/home/${u}"
