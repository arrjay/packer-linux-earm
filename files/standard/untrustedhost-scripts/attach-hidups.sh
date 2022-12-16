#!/usr/bin/env bash

# we are handed one argument - vendorid-serial
vendorid="${1%-*}"
serialno="${1#*-}"

# drag dynamic device setup over to nut, ffs this is annoying
mkdir -p /run/untrustedhost/nut/ups.conf.d
mkdir -p /run/untrustedhost/nut/discovered-ups.xml.d

# make an xml fragment for later.
echo '<ups/>' | xmlstarlet ed -s 'ups' -t 'attr' -n 'vendor' -v "${vendorid}" \
                  -s 'ups' -t 'attr' -n 'serial' -v "${serialno}" \
                  -s 'ups' -t 'attr' -n 'name' -v "${vendorid}-${serialno}" \
  > "/run/untrustedhost/nut/discovered-ups.xml.d/${vendorid}-${serialno}.xml"

cat <<EOF>"/run/untrustedhost/nut/ups.conf.d/${vendorid}-${serialno}.conf"
[${vendorid}-${serialno}]
  driver       = usbhid-ups
  port         = auto
  vendorid     = ${vendorid}
  pollinterval = 2
  pollfreq     = 15
EOF

case "${vendorid}" in
  # BUG: tripplite device does not return iserial so we unset it.
  09ae) unset serialno ;;
esac

[[ "${serialno}" ]] && printf '  serialno = %s\n' "${serialno}"

# also, tell systemd to leave the driver running.
mkdir -p "/run/systemd/system/nut-driver.service.d"
cat <<EOF>"/run/systemd/system/nut-driver.service.d/10-dontstop.conf"
[Unit]
StopWhenUnneeded=no
EOF
systemctl daemon-reload

exit 0
