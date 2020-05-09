#!/usr/bin/env bash

. secrets/common/ssh_pubkey
. secrets/sickle/imdsecrets
. secrets/common/vlandb
. secrets/common/ipdb.home

# deploy would be expecting a libvirt xml doc to modify, but...this isn't libvirt, so make something.
xmlstarlet_args=()

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'domain' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain' '--type' 'elem' '-n' 'name' '-v' 'sickle')

# build devie tree for network interfaces
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain' '--type' 'elem' '-n' 'devices' '-v' '')

# onboard interface is a bridge...
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices' '--type' 'elem' '-n' 'interface' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'attr' '-n' 'type' '-v' 'bridge')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'source' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/source' '--type' 'attr' '-n' 'bridge' '-v' "onboard")

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'bridge' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/bridge' '--type' 'attr' '-n' 'name' '-v' 'bridge')

# vlan db lives in metadata/vlan
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'vlan' -v '')

for vid in "${!vlan[@]}" ; do
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/vlan' '--type' 'elem' '-n' 'map' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/vlan/map[last()]' '--type' 'attr' '-n' 'id' '-v' "${vid}")
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/vlan/map[last()]' '--type' 'attr' '-n' 'name' '-v' "${vlan[${vid}]}")
done

for vl in hv ; do
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="onboard"]' '--type' 'elem' '-n' 'vlan' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="onboard"]/vlan[last()]' '--type' 'attr' '-n' 'name' '-v' "${vl}")
  [[ "${ipv4[${vl}]}" ]] && {
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="onboard"]/vlan[last()]' '--type' 'elem' '-n' 'ipv4' '-v' '')
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="onboard"]/vlan[last()]/ipv4' '--type' 'attr' '-n' 'address' '-v' "${ipv4[${vl}]}")
  }
done

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"]/vlan[@name="ninf"]' '--type' 'elem' '-n' 'bridge' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"]/vlan[@name="ninf"]/bridge' '--type' 'attr' '-n' 'name' '-v' 'ninf')

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="onboard"]' '--type' 'elem' '-n' 'ipv4' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="onboard"]/ipv4[last()]' '--type' 'attr' '-n' 'address' '-v' "${ipv4['ninf']}")

# configure dhcp server
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'dhcpserver' '-v' '')
for vid in "${!vlan[@]}" ; do
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver' '--type' 'elem' '-n' 'subnet' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]' '--type' 'attr' '-n' 'ipv4' '-v' "${ipv4[${vid}]}")
  [[ "${range_start[${vid}]}" ]] && [[ "${range_end[${vid}]}" ]] && {
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]' '--type' 'elem' '-n' 'range' '-v' '')
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]/range[last()]' '--type' 'attr' '-n' 'begin' '-v' "${range_start[${vid}]}")
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]/range[last()]' '--type' 'attr' '-n' 'end' '-v' "${range_end[${vid}]}")
  }
  [[ "${gateway[${vid}]}" ]] && xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]' '--type' 'attr' '-n' 'gateway' '-v' "${gateway[${vid}]}")
  [[ "${dns[${vid}]}" ]] && {
    for srv in "${dns[${vid}]}" ; do
      xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]' '--type' 'attr' '-n' 'dns' '-v' "${srv}")
    done
  }
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]' '--type' 'elem' '-n' 'ddns' '-v' '')
  [[ "${ddnsdomain[${vid}]}" ]] && {
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]/ddns' '--type' 'attr' '-n' 'domain' '-v' "${ddnsdomain[${vid}]}")
  }
  [[ "${revddnsdomain[${vid}]}" ]] && {
    xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dhcpserver/subnet[last()]/ddns' '--type' 'attr'
                     '-n' 'revdomain' '-v' "${revddnsdomain[${vid}]}")
  }
done

# configure 'e*' - an interface to match any usb ethernet adapters
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices' '--type' 'elem' '-n' 'interface' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'attr' '-n' 'type' '-v' 'bridge')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'source' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/source' '--type' 'attr' '-n' 'bridge' '-v' 'e*')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="e*"]'
                 '--type' 'elem' '-n' 'bridge' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[@type="bridge"][source/@bridge="e*"]/bridge'
                 '--type' 'attr' '-n' 'name' '-v' 'bridge')

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'ethers' '-v' '')
# this is...a fun one. turn ethers into xml.
while read -r line ; do
  read -ra split <<<"${line}"
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/ethers' '--type' 'elem' '-n' 'entry' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/ethers/entry[last()]' '--type' 'attr' '-n' 'hwaddr' '-v' "${split[0]}")
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/ethers/entry[last()]' '--type' 'attr' '-n' 'name' '-v' "${split[1]}")
done < secrets/common/ethers

# ssh userkey
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'ssh' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/ssh' '--type' 'elem' '-n' 'pubkey' '-v' "${ssh_pubkey}")

# build in an empty metadata tag...
echo '<metadata/>' | xmlstarlet ed "${xmlstarlet_args[@]}"
