#!/usr/bin/env bash

# simple case - we're not using systemd-resolved?
grep -qF 'nameserver 127' /etc/resolv.conf || cat /etc/resolv.conf

type resolvectl >/dev/null 2>&1 && {
  upstream_ns="$(resolvectl status | awk '$0 ~ "DNS Servers:" { $1="";$2="";print $0 }')"
  [[ "${upstream_ns}" ]] && {
    for ns in ${upstream_ns} ; do
      printf 'nameserver %s\n' "${ns}"
    done
  }
}
