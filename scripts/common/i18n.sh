#!/bin/sh

# temporary while running this to quiesce perl
export LANG=C

set -e

# from https://raspberrypi.stackexchange.com/questions/28907/how-could-one-automate-the-raspbian-raspi-config-setup
raspi-config nonint do_configure_keyboard us
raspi-config nonint do_change_locale en_US.UTF-8


