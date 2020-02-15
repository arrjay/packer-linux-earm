#!/usr/bin/env bash

dhcp_xml=$(xmlstarlet sel -t -c metadata/dhcpserver/address "${IMD_PATH}")

# check for additional dhcp include here, but only replace if IMD has a newer copy.
[[ "${IMD_MOUNT}/dhcp-subnets.conf" -nt '/etc/dhcp/dhcpd.subnets' ]] && cp -f "${IMD_MOUNT}/dhcp-subnets.conf" '/etc/dhcp/dhcpd.subnets'

[[ "${dhcp_xml}" ]] && echo "${dhcp_xml}" > /etc/untrustedhost/netxml/dhcpd.xml

# generate stub network for dhcpd
[[ "${dhcp_xml}" ]] && {
  v4slice="$(echo "${dhcp_xml}" | xmlstarlet sel -t -v address/@ipv4 )"
  v4net="${v4slice%/*}"
  v4netm="$(ipcalc "${v4slice}" | awk '$1 == "Netmask:" { print $2 }')"

  printf 'subnet %s netmask %s { }\n' "${v4net}" "${v4netm}" > /run/untrustedhost/dhcpd-v4.interface
}

exit 0
