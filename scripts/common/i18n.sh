#!/bin/sh

# temporary while running this to quiesce perl
export LANG=C

set -e

# from https://raspberrypi.stackexchange.com/questions/28907/how-could-one-automate-the-raspbian-raspi-config-setup
raspi-config nonint do_configure_keyboard us
raspi-config nonint do_change_locale en_US.UTF-8

# server runs in UCT kthxbye
ln -sf /usr/share/zoneinfo/UCT /etc/localtime

# https://blog.packagecloud.io/eng/2017/02/21/set-environment-variable-save-thousands-of-system-calls/ o_O
mkdir -p /etc/systemd/system.conf.d
printf '[Manager]\nDefaultEnvironment=TZ=UCT\n' > /etc/systemd/system.conf.d/TZ.conf

# people run in LA...
printf 'TZ=America/Los_Angeles\n' >> /etc/environment
