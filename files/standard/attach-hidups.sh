#!/usr/bin/env bash

# we are handed one argument - vendorid/serial
vendorid="${1%/*}"
serialno="${1#*/}"

# drag dynamic device setup over to nut, ffs this is annoying
mkdir -p /run/untrustedhost/nut/ups.conf.d

cat <<EOF>"/run/untrustedhost/nut/ups.conf.d/${vendorid}-${serialno}.conf"
[${vendorid}-${serialno}]
  driver   = usbhid-ups
  port     = auto
  vendorid = ${vendorid}
  serial   = ${serialno}
EOF
