#!/usr/bin/env bash

. secrets/sickle/imdsecrets
. secrets/common/vlandb

# deploy would be expecting a libvirt xml doc to modify, but...this isn't libvirt, so make something.
xmlstarlet_args=()

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'domain' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain' '--type' 'elem' '-n' 'name' '-v' 'trowel')

# build devie tree for network interfaces
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain' '--type' 'elem' '-n' 'devices' '-v' '')

# onboard interface is a bridge...
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices' '--type' 'elem' '-n' 'interface' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'attr' '-n' 'type' '-v' 'bridge')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'source' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/source' '--type' 'attr' '-n' 'bridge' '-v' "onboard")

xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'bridge' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/bridge' '--type' 'attr' '-n' 'name' '-v' 'ninf')

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

# build in an empty metadata tag...
echo '<metadata/>' | xmlstarlet ed "${xmlstarlet_args[@]}"
