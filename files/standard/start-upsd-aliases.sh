#!/usr/bin/env bash

# the dummy-ups drivers refer to upsd on the host, so we need to start them..after upsd itself.
for f in /run/untrustedhost/nut/alias.conf.d/*.conf ; do
  [[ -f "${f}" ]] || continue
  target=''
  target="${f##*/}"
  target="${target%.conf}"
  systemd-run --on-active=1s systemctl start "nut-driver@${target}"
done

exit 0
