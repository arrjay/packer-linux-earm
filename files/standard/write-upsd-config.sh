#!/usr/bin/env bash

cat /run/untrustedhost/nut/ups.conf.d/*.conf > /run/untrustedhost/nut/ups.conf
chgrp nut /run/untrustedhost/nut/ups.conf
chmod 0660 /run/untrustedhost/nut/ups.conf

# create upsd.users - always assume three - admin, upsctrl, and upsuser
# appropriate for ups administration, monitor master, monitor slave.
touch /run/untrustedhost/nut/upsd.users
chgrp nut /run/untrustedhost/nut/upsd.users
chmod 0660 /run/untrustedhost/nut/upsd.users

# this process is a little more awkward in that we have three ways to get to
# a password, xml, /root/upsd-$u-pw or a generator.

admin_pw='' ; upsctrl_pw='' ; upsuser_pw=''

[[ -f /run/untrustedhost/nut/conf.xml ]] && {
  admin_pw="$(xmlstarlet sel -t -v 'nut/user[@name="admin"]/@password' /run/untrustedhost/nut/conf.xml)"
  upsctrl_pw="$(xmlstarlet sel -t -v 'nut/user[@name="upsctrl"]/@password' /run/untrustedhost/nut/conf.xml)"
  upsuser_pw="$(xmlstarlet sel -t -v 'nut/user[@name="upsuser"]/@password' /run/untrustedhost/nut/conf.xml)"
}

[[ "${admin_pw}" ]] || {
  [[ -f /root/upsd-admin-pw ]] && read -r admin_pw < /root/upsd-admin-pw
}
[[ "${upsctrl_pw}" ]] || {
  [[ -f /root/upsd-upsctrl-pw ]] && read -r upsctrl_pw < /root/upsd-upsctrl-pw
}
[[ "${upsuser_pw}" ]] || {
  [[ -f /root/upsd-upsuser-pw ]] && read -r upsuser_pw < /root/upsd-upsuser-pw
}

# still no? ok, make some.
[[ "${admin_pw}" ]] || admin_pw="$(apg -M SNCL -m 14 -E \\\'\" | head -n1)"
[[ "${upsctrl_pw}" ]] || upsctrl_pw="$(apg -M SNCL -m 14 -E \\\'\" | head -n1)"
[[ "${upsuser_pw}" ]] || upsuser_pw="$(apg -M SNCL -m 14 -E \\\'\" | head -n1)"

cat <<EOF>/run/untrustedhost/nut/upsd.users
[admin]
  password = ${admin_pw}
  actions = set fsd
  instcmds = all

[upsctrl]
  password = ${upsctrl_pw}
  upsmon master

[upsuser]
  password = ${upsuser_pw}
  upsmon slave
EOF

# save the passwords if needed.
[[ -f /root/upsd-admin-pw ]] || echo "${admin_pw}" > /root/upsd-admin-pw
[[ -f /root/upsd-upsctrl-pw ]] || echo "${upsctrl_pw}" > /root/upsd-upsctrl-pw
[[ -f /root/upsd-upsuser-pw ]] || echo "${upsuser_pw}" > /root/upsd-upsuser-pw
