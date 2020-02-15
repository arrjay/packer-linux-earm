#!/usr/bin/env bash

# flatten all the destination arguments into a space-separated list
dhcp_peers=$(xmlstarlet sel -t -v metadata/dhcprelay/destination < "${IMD_PATH}" | xargs printf '%s ')
dhcp_peers="${dhcp_peers:0:-1}"

[[ "${dhcp_peers}" ]] && {
  sed -i -e '/^\(SERVERS=\).*/{s//\1"'"${dhcp_peers}"'"/;:a;n;ba;q}' -e '$aSERVERS="'"${dhcp_peers}"'"' /etc/default/isc-dhcp-relay
}

exit 0
