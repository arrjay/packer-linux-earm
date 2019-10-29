#!/bin/sh

set -e

# set the hostname
printf '%s\n' 'hose' > /etc/hostname

# enable the serial port
printf 'enable_uart=%s\n' '1' >> /boot/config.txt
