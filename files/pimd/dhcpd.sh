#!/usr/bin/env bash

dhcp_xml=$(xmlstarlet sel -t -c metadata/dhcpserver/address "${IMD_PATH}")

# flatten all the destination arguments into a space-separated list
dhcp_peers=$(xmlstarlet sel -t -v metadata/dhcprelay/destination < "${IMD_PATH}" | xargs printf '%s ')
dhcp_peers="${dhcp_peers:0:-1}"

# check for additional dhcp include here, but only replace if IMD has a newer copy.
[[ "${IMD_MOUNT}/dhcp-subnets.conf" -nt '/etc/dhcp/dhcpd.subnets' ]] && cp -f "${IMD_MOUNT}/dhcp-subnets.conf" '/etc/dhcp/dhcpd.subnets'

[[ "${dhcp_xml}" ]] && echo "${dhcp_xml}" > /etc/untrustedhost/netxml/dhcpd.xml

[[ "${dhcp_peers}" ]] && {
  sed -i -e '/^\(SERVERS=\).*/{s//\1"'"${dhcp_peers}"'"/;:a;n;ba;q}' -e '$aSERVERS="'"${dhcp_peers}"'"' /etc/default/isc-dhcp-relay
}

exit 0
