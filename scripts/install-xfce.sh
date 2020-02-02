#!/bin/sh

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get -qq -y install xfce4 xfce4-screenshooter xfce4-terminal solaar blueman scdaemon

printf 'XFCE_PANEL_MIGRATE_DEFAULT=1\n' >> /etc/environment
