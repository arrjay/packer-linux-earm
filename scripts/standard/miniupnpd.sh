#!/usr/bin/env bash

printf '%s\n' "miniupnpd miniupnpd/ip6script boolean false" \
              "miniupnpd miniupnpd/listen string INTERNAL" \
              "miniupnpd miniupnpd/force_igd_desc_v1 boolean false" \
              "miniupnpd miniupnpd/start_daemon boolean false" \
              "miniupnpd miniupnpd/iface string EXTERNAL" \
  | debconf-set-selections

apt-get install miniupnpd

systemctl enable untrustedhost-miniupnpd

firewall-offline-cmd --new-service=natpmp
firewall-offline-cmd --service=natpmp --add-port=5351/udp
firewall-offline-cmd --zone=trusted --add-service=natpmp
firewall-offline-cmd --zone=trusted --add-service=upnp-client
