#!/usr/bin/env bash

# router id for ospf
rtid="172.16.193.9"

# bridge name:ospf zones
ospf_zm=("ospf.garage:0.0.1.0")

# ospf zone keys - shellcheck has no idea how I got these ;)
. ./secrets/common/ospfkeys

# hose data
. ./secrets/hose/imdsecrets

# dns tsig keys
. ./secrets/common/tsigkeys

# deploy would be expecting a libvirt xml doc to modify, but...this isn't libvirt, so make something.
xmlstarlet_args=()

# domain/devices/bridge needs to exist for ospf generator - names come from hypervisor-networkd tho.
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'domain' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain' '--type' 'elem' '-n' 'devices' '-v' '')

# we also need a router tag to ply ospf zones into.
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'router' '-v' '')

# loop on zm struct
for ent in "${ospf_zm[@]}" ; do
  name='' ; zone='' ; area_hx='' ; id_keys='' ; IFS=:
  read -r name zone <<<"${ent}"
  unset IFS
  # add a new interface statement
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices' '--type' 'elem' '-n' 'interface' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'attr' '-n' 'type' '-v' 'bridge')
  # addign the last interface (which we just added) the source bridge and ospf area
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'source' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/source' '--type' 'attr' '-n' 'bridge' '-v' "${name}")
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]' '--type' 'elem' '-n' 'ospf' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/domain/devices/interface[last()]/ospf' '--type' 'attr' '-n' 'area' '-v' "${zone}")
  # visit the router block and add the ospf zone
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/router' '--type' 'elem' '-n' 'ospf' '-v' '')
  xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/router/ospf[last()]' '--type' 'attr' '-n' 'area' '-v' "${zone}")
  # lookup keys
  # convert area from octet to hex for lookup...requires multiple args to printf.
  # shellcheck disable=SC2086
  area_hx=$(printf '%02X' ${zone//./ })
  handle="ospf_key_${area_hx}"
  # this is...the only way to get the keys of an array dynamically AFAICT.
  # shellcheck disable=SC1083,SC2086
  id_keys=$(eval echo \${!${handle}[*]})
  [[ "${id_keys}" ]] && {
    for keyid in ${id_keys} ; do
      # shellcheck disable=SC1083,SC2086
      pass=$(eval echo \${${handle}[${keyid}]})
      xmlstarlet_args=("${xmlstarlet_args[@]}"
                         -s "/metadata/router/ospf[@area=\"${zone}\"]" -t 'elem' -n 'authentication' -v ''
                         -s "/metadata/router/ospf[@area=\"${zone}\"]/authentication[last()]" -t 'attr' -n 'key' -v "${keyid}"
                         -s "/metadata/router/ospf[@area=\"${zone}\"]/authentication[@key=\"${keyid}\"]" -t 'attr' -n 'password' -v "${pass}")
    done
  }
done

# insert router id, ospf keys
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/router' '--type' 'attr' '-n' 'id' '-v' "${rtid}")

# application data - metadata/dnsauth (structure, ipv4 addr)
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata' '--type' 'elem' '-n' 'dnsauth' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dnsauth' '--type' 'attr' '-n' 'fqdn' '-v' "${dns_fqdn}")
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dnsauth' '--type' 'elem' '-n' 'address' '-v' '')
xmlstarlet_args=("${xmlstarlet_args[@]}" '--subnode' '/metadata/dnsauth/address' '--type' 'attr' '-n' 'ipv4' '-v' "${ns_ipv4}")

# tsig keys
# tsig keying
for tskey in "${tsig_keys_names[@]}" ; do
  xmlstarlet_args=("${xmlstarlet_args[@]}"
    -s /metadata/dnsauth -t 'elem' -n 'tsigkey' -v ''
    -i '/metadata/dnsauth/tsigkey[last()]' -t attr -n 'name' -v "${tskey//_/.}"
    -i '/metadata/dnsauth/tsigkey[last()]' -t attr -n 'algo' -v "hmac-sha512"
    -i '/metadata/dnsauth/tsigkey[last()]' -t attr -n 'data' -v "${tsig_keys["${tskey}"]}")
done

# zones
for zonename in "${zones[@]}" ; do
  xmlstarlet_args=("${xmlstarlet_args[@]}"
    -s /metadata/dnsauth -t 'elem' -n "zone" -v ''
    -i '/metadata/dnsauth/zone[last()]' -t attr -n 'name' -v "${zonename}"
    -i '/metadata/dnsauth/zone[last()]' -t attr -n 'refresh' -v "86400"
    -i '/metadata/dnsauth/zone[last()]' -t attr -n 'retry' -v "7200"
    -i '/metadata/dnsauth/zone[last()]' -t attr -n 'expire' -v "3600000"
    -i '/metadata/dnsauth/zone[last()]' -t attr -n 'rname' -v "${dns_fqdn}")
  case "${zonename}" in
    ni.g.bbxn.us|hv.g.bbxn.us) xmlstarlet_args=("${xmlstarlet_args[@]}"
        -i '/metadata/dnsauth/zone[last()]' -t attr -n 'nxttl' -v "300") ;;
    *) xmlstarlet_args=("${xmlstarlet_args[@]}"
        -i '/metadata/dnsauth/zone[last()]' -t attr -n 'nxttl' -v "3600") ;;
  esac
  for tsigkey in "${tsig_keys_names[@]}" ; do
    case "${tsigkey}" in
      *update)
        xmlstarlet_args=("${xmlstarlet_args[@]}" -s '/metadata/dnsauth/zone[last()]' -t 'elem' -n 'tsigkey' -v ''
          -i '/metadata/dnsauth/zone[last()]/tsigkey[last()]' -t attr -n 'id' -v "${tsigkey//_/.}")
      ;;
    esac
  done
done

# build in an empty metadata tag...
echo '<metadata/>' | xmlstarlet ed "${xmlstarlet_args[@]}"
