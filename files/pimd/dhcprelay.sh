#!/usr/bin/env bash

# flatten all the destination arguments into a space-separated list
dhcp_peers=$(xmlstarlet sel -t -v metadata/dhcprelay/destination < "${IMD_PATH}" | xargs printf '%s ')
dhcp_peers="${dhcp_peers:0:-1}"
dhcp_ipv4="$(xmlstarlet sel -t -v metadata/dhcpserver/address/@ipv4 < "${IMD_PATH}")"
dhcp_interfaces=$(xmlstarlet sel -t -v metadata/dhcprelay/interface < "${IMD_PATH}" | xargs printf '%s ')
dhcp_interfaces="${dhcp_interfaces:0:-1}"

# check in metadata if we have a dhcpserver and add that too...
[[ "${dhcp_ipv4}" ]] && {
  # that's a range get the slice address
  hx="$(ipcalc "${dhcp_ipv4}"| awk '$1 == "HostMax:" { print $2 }')"
  dhcp_peers="${hx} ${dhcp_peers}"
  dhcp_peers="${dhcp_peers%"${dhcp_peers##*[![:space:]]}"}"

  # also check here for a non-zero interfaces, and so, add dhcpd.0 as needed
  [[ "${dhcp_interfaces}" ]] && {
    case " ${dhcp_interfaces} " in
      *" dhcpd.0 "*) : ;;
      *) dhcp_interfaces="dhcpd.0 ${dhcp_interfaces}" ;;
    esac
  }
}

[[ "${dhcp_peers}" ]] && {
  sed -i -e '/^\(SERVERS=\).*/{s//\1"'"${dhcp_peers}"'"/;:a;n;ba;q}' -e '$aSERVERS="'"${dhcp_peers}"'"' /etc/default/isc-dhcp-relay
}

[[ "${dhcp_interfaces}" ]] && {
  sed -i -e '/^\(INTERFACES=\).*/{s//\1"'"${dhcp_interfaces}"'"/;:a;n;ba;q}' -e '$aINTERFACES="'"${dhcp_interfaces}"'"' /etc/default/isc-dhcp-relay
}

# make sure dhcpd.0 (from the namespace stuff) is in INTERFACES _if_ INTERFACES is non-empty
# read

exit 0
