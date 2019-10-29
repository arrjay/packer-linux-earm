#!/bin/sh

set -e

# set the hostname
printf '%s\n' 'edger' > /etc/hostname

# flip the screen
printf 'lcd_rotate=%s\n' '2' >> /boot/config.txt

# enable the serial port...
printf 'enable_uart=%s\n' '1' >> /boot/config.txt
# but _disable_ using it for linux console
sed -i -e 's/console=serial0.*0 //' /boot/cmdline.txt

# configure consoleblank
sed -i -e 's/consoleblank=[0-9]\+//' -e 's/$/ consoleblank=90/' /boot/cmdline.txt
