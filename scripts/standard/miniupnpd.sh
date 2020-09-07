#!/usr/bin/env bash

printf '%s\n' "miniupnpd miniupnpd/ip6script boolean false" \
              "miniupnpd miniupnpd/listen string INTERNAL" \
              "miniupnpd miniupnpd/force_igd_desc_v1 boolean false" \
              "miniupnpd miniupnpd/start_daemon boolean false" \
              "miniupnpd miniupnpd/iface string EXTERNAL" \
  | debconf-set-selections

apt-get install miniupnpd

systemctl enable untrustedhost-miniupnpd
