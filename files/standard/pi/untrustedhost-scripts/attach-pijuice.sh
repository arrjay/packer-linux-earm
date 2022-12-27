#!/usr/bin/env bash

# we're not handed any arguments.
# if you have more than one pijuice attached...how? why?

# we're going to use the same pieces as attach-hidups
# but they're...static.
mkdir -p /run/untrustedhost/nut/ups.conf.d
mkdir -p /run/untrustedhost/nut/discovered-ups.xml.d

vendorid=pijuice
serialno=builtin

echo '<ups/>' | xmlstarlet ed -s 'ups' -t 'attr' -n 'vendor' -v "${vendorid}" \
                  -s 'ups' -t 'attr' -n 'serial' -v "${serialno}" \
                  -s 'ups' -t 'attr' -n 'name' -v "${vendorid}-${serialno}" \
  > "/run/untrustedhost/nut/discovered-ups.xml.d/pijuice.xml"

cat <<EOF>"/run/untrustedhost/nut/ups.conf.d/${vendorid}-${serialno}.conf"
[${vendorid}-${serialno}]
  driver       = pijuice
  port         = /dev/i2c-1
  pollinterval = 2
EOF
