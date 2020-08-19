#!/usr/bin/env bash

discovered_ups_list=()

# unwind any aliases now
mkdir -p /run/untrustedhost/nut/alias.conf.d
for f in /run/untrustedhost/nut/discovered-ups.xml.d/*.xml ; do
  [[ -f "${f}" ]] || continue
  upsname='' ; upsvend='' ; upsser='' ; aliasct='0'
  upsname="$(xmlstarlet sel -t -v 'ups/@name' "${f}")"
  upsvend="$(xmlstarlet sel -t -v 'ups/@vendor' "${f}")"
  upsser="$(xmlstarlet sel -t -v 'ups/@serial' "${f}")"
  aliasct="$(xmlstarlet sel -t -v 'count(nut/ups[@vendor="'"${upsvend}"'"][@serial="'"${upsser}"'"]/alias)' /run/untrustedhost/nut/conf.xml)"
  while [[ "${aliasct}" -gt 0 ]] ; do
    aliasname="$(xmlstarlet sel -t -v 'nut/ups[@vendor="'"${upsvend}"'"][@serial="'"${upsser}"'"]/alias['"${aliasct}"']' /run/untrustedhost/nut/conf.xml)"
    printf '[%s]\n  driver = dummy-ups\n  port = %s@localhost\n' "${aliasname}" "${upsname}" > "/run/untrustedhost/nut/alias.conf.d/${aliasname}.conf"
    systemd-run --on-active=1m systemctl start "mdns-publish-cname@ups-${aliasname}"
    ((aliasct--))
  done
done

# fold real and virtual ups units into the file for driver startup.
printf 'maxretry = %s\n' 3 > /run/untrustedhost/nut/ups.conf
cat /run/untrustedhost/nut/ups.conf.d/*.conf /run/untrustedhost/nut/alias.conf.d/*.conf >> /run/untrustedhost/nut/ups.conf
chgrp nut /run/untrustedhost/nut/ups.conf
chmod 0660 /run/untrustedhost/nut/ups.conf

# start 'real' (discovered) ups units now. however, if we never did have any discovered ups units, die.
for f in /run/untrustedhost/nut/discovered-ups.xml.d/*.xml ; do
  [[ -f "${f}" ]] || exit 1
  upsname=''
  upsname="$(xmlstarlet sel -t -v 'ups/@name' "${f}")"
  systemd-run --on-active=1s systemctl start "nut-driver@${upsname}"
  discovered_ups_list=("${discovered_ups_list[@]}" "${upsname}")
done

# wire a netdata config for the nut plugin with only discovered upsen
mkdir -p /run/untrustedhost/netdata
printf 'nut_clients_chart=1\nnut_ups=%s\n' "${discovered_ups_list[*]}" > /run/untrustedhost/netdata/nut.conf
[[ -d /etc/netdata/charts.d ]] && ln -sf /run/untrustedhost/netdata/nut.conf /etc/netdata/charts.d/nut.conf

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

# ok! generate the monitoring config!
MINSUPPLIES=0
: > /run/untrustedhost/nut/upsmon.conf
chmod 0660 /run/untrustedhost/nut/upsmon.conf
chgrp nut /run/untrustedhost/nut/upsmon.conf

for f in /run/untrustedhost/nut/discovered-ups.xml.d/*.xml ; do
  [[ -f "${f}" ]] || continue
  upsname='' ; upsvend='' ; upsser='' ; myups=''
  upsname="$(xmlstarlet sel -t -v 'ups/@name' "${f}")"
  upsvend="$(xmlstarlet sel -t -v 'ups/@vendor' "${f}")"
  upsser="$(xmlstarlet sel -t -v 'ups/@serial' "${f}")"
  # determine if this UPS powers us - assume not
  myups="$(xmlstarlet sel -t -v 'nut/ups[@vendor="'"${upsvend}"'"][@serial="'"${upsser}"'"]/@powervalue' /run/untrustedhost/nut/conf.xml)"
  [[ "${myups}" ]] || myups=0
  [[ "${myups}" -ne 0 ]] && ((MINSUPPLIES++))
  printf 'MONITOR %s@localhost %s upsctrl %s master\n' "${upsname}" "${myups}" "${upsctrl_pw}" \
   >> /run/untrustedhost/nut/upsmon.conf
  # hook in the mdns alias job here, I don't really have a better place for it.
  systemd-run --on-active=1m systemctl start mdns-publish-cname@"ups-${upsname}"
done

cat <<EOF>>/run/untrustedhost/nut/upsmon.conf

MINSUPPLIES ${MINSUPPLIES}

SHUTDOWNCMD "/sbin/shutdown -h +0"

NOTIFYCMD /sbin/upssched

POLLFREQ 3

POLLFREQALERT 3

HOSTSYNC 15

DEADTIME 10

POWERDOWNFLAG /etc/killpower

NOTIFYFLAG ONLINE EXEC
NOTIFYFLAG ONBATT EXEC
NOTIFYFLAG LOWBATT EXEC
NOTIFYFLAG FSD EXEC
NOTIFYFLAG COMMOK EXEC
NOTIFYFLAG COMMBAD EXEC
NOTIFYFLAG SHUTDOWN EXEC
NOTIFYFLAG REPLBATT EXEC
NOTIFYFLAG NOCOMM EXEC
NOTIFYFLAG NOPARENT EXEC

RBWARNTIME 43200

NOCOMMWARNTIME 0

FINALDELAY 5
EOF

# schedule nut-monitor to start later
systemd-run --on-active=1m systemctl start nut-monitor

# save the passwords if needed.
[[ -f /root/upsd-admin-pw ]] || echo "${admin_pw}" > /root/upsd-admin-pw
[[ -f /root/upsd-upsctrl-pw ]] || echo "${upsctrl_pw}" > /root/upsd-upsctrl-pw
[[ -f /root/upsd-upsuser-pw ]] || echo "${upsuser_pw}" > /root/upsd-upsuser-pw
