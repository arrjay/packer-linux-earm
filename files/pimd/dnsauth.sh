#!/usr/bin/env bash

dns_xml=$(xmlstarlet sel -t -c metadata/dnsauth/address "${IMD_PATH}")

[[ "${dns_xml}" ]] && echo "${dns_xml}" > /etc/untrustedhost/netxml/dnsauth.xml

# create pdns db if it does not exist
[[ ! -f /var/lib/powerdns/pdns.sqlite3 ]] && {
  sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/lib/untrustedhost/share/schema.sqlite3.sql
}

# always reset the permissions though.
chown pdns:pdns /var/lib/powerdns
chown pdns:pdns /var/lib/powerdns/pdns.sqlite3

# copy the entire dnsauth node out.
dnsauth_xml=$(xmlstarlet sel -t -c metadata/dnsauth "${IMD_PATH}")

[[ "${dnsauth_xml}" ]] && echo "${dnsauth_xml}" > /etc/untrustedhost/dnsauth.xml

tsigkeys=($(echo "${dnsauth_xml}" | xmlstarlet sel -t -v dnsauth/tsigkey/@name))
oldkeys=()

# init add array to flag wether keys are to be added (or not)
for k in "${tsigkeys[@]}" ; do
  add["${k//./_}"]=1
done

# get current state from pdnsutil list-tsig-keys
while read -r keyname keyalg keydata ; do
  skey="${keyname%?}"
  case " ${tsigkeys[*]} " in
    *" ${skey} "*)
      x_keyalg='' x_keydat=''
      x_keyalg="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/tsigkey[@name="'"${skey}"'"]/@algo')"
      x_keydat="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/tsigkey[@name="'"${skey}"'"]/@data')"
      [[ "${keyalg}" == "${x_keyalg}." ]] && [[ "${keydata}" == "${x_keydat}" ]] && add["${skey//./_}"]=0
      oldkeys=("${oldkeys[@]}" "${skey}")
    ;;
  esac
done < <(pdnsutil list-tsig-keys)

# handle any adds
for k in "${tsigkeys[@]}" ; do
  [[ "${add["${k//./_}"]:-0}" == 1 ]] && {
    x_keyalg='' x_keydat=''
    x_keyalg="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/tsigkey[@name="'"${k}"'"]/@algo')"
    x_keydat="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/tsigkey[@name="'"${k}"'"]/@data')"
    pdnsutil import-tsig-key "${k}" "${x_keyalg}" "${x_keydat}"
  }
done

# if flagged to do so, delete any other keys.
allow_unref_keys="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/tsig/@allow_unref_keys')"
[[ "${allow_unref_keys}" == 'false' ]] && {
  for k in "${oldkeys[@]}" ; do
    # skip keys declared in xml here
    [[ "${add["${k}"]+exists}" ]] && continue
    pdnsutil delete-tsig-key "${k}"
  done
}

# build an argument for tsig keys
ts_arg="${tsigkeys[*]}"
ts_arg="${ts_arg// /, }"

# used in creation and update
get_tsig_arg() {
  local generated_ts_arg priv_ts_keys zone type
  zone="${1}" type="${2:-tsigkey}"
  priv_ts_keys=($(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/zone[@name="'"${zone}"'"]/'"${type}"'/@id' ))
  generated_ts_arg="${priv_ts_keys[*]}" ; generated_ts_arg="${generated_ts_arg// /, }"
  printf '%s' "${generated_ts_arg}"
}

# keys are (mostly) done, go poke at zones
zones=($(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/zone/@name'))
oldzones=($(pdnsutil list-all-zones))
for k in "${zones[@]}" ; do
  # if the zone exists skip creating it
  case " ${oldzones[*]} " in
    *" ${k} "*) continue ;;
  esac
  local_ts_arg=''
  local_ts_arg=$(get_tsig_arg "${k}")
  [[ "${local_ts_arg}" ]] || local_ts_arg="${ts_arg}"
  pdnsutil create-zone "${k}"
  # if we're here, making a zone, set the TSIG secrets.
  pdnsutil set-meta "${k}" TSIG-ALLOW-DNSUPDATE ${local_ts_arg//,/ }
  # also drop a 0/0 acl for allowed updates, the TSIG keys are controlling it
  pdnsutil set-meta "${k}" ALLOW-DNSUPDATE-FROM 0.0.0.0/0
done

server_fqdn="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/@fqdn')"
fallback_tsig_mode="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/tsig/@global_dnsupdate_keys')"
# validate type (native|master|slave, default master) and SOA
for k in "${zones[@]}" ; do
  zonetype="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/zone[@name="'"${k}"'"]/@type')"
  [[ "${zonetype}" ]] || zonetype=master
  pdnsutil set-kind "${k}" "${zonetype}"
  # compare per-zone tsig keys here
  local_ts_arg=''
  local_ts_arg=$(get_tsig_arg "${k}")
  # specific zones _will_ override the global
  [[ "${local_ts_arg}" ]] && {
    pdnsutil set-meta "${k}" TSIG-ALLOW-DNSUPDATE ${local_ts_arg//,/ }
    # also drop a 0/0 acl for allowed updates, the TSIG keys are controlling it
    pdnsutil set-meta "${k}" ALLOW-DNSUPDATE-FROM 0.0.0.0/0
  }
  [[ "${fallback_tsig_mode}" == 'true' ]] && { [[ "${local_ts_arg}" ]] || {
    pdnsutil set-meta "${k}" TSIG-ALLOW-DNSUPDATE ${ts_arg//,/ } ; }
    # also drop a 0/0 acl for allowed updates, the TSIG keys are controlling it
    pdnsutil set-meta "${k}" ALLOW-DNSUPDATE-FROM 0.0.0.0/0
  }
  local_ak_arg=''
  local_ak_arg=$(get_tsig_arg "${k}" "axfrkey")
  [[ "${local_ak_arg}" ]] && {
    pdnsutil set-meta "${k}" TSIG-ALLOW-AXFR "${local_ak_arg}"
  }
  [[ "${fallback_tsig_mode}" == 'true' ]] && { [[ "${local_ak_arg}" ]] || {
    pdnsutil set-meta "${k}" TSIG-ALLOW-AXFR ${ts_arg//,/ } ; }
  }
  # get the current SOA
  read -r name ttl type rec server rname serial refresh retry expire nxttl < <(pdnsutil list-zone "${k}" | grep $'\tIN\tSOA\t')
  # get the SOA values from xml...
  read -r x_refresh x_retry x_expire x_nxttl x_rname < <(echo "${dnsauth_xml}" | xmlstarlet sel -t -m 'dnsauth/zone[@name="'"${k}"'"]' -v '@refresh' -n -v '@retry' -n -v '@expire' -n -v '@nxttl' -n -v '@rname' | tr '\n' ' ')
  # compare all of them - if they match go away
  [[ "${server}" == "${server_fqdn}." ]] && [[ "${refresh}" == "${x_refresh}" ]] && [[ "${retry}" == "${x_retry}" ]] && [[ "${expire}" == "${x_expire}" ]] && [[ "${nxttl}" == "${x_nxttl}" ]] && [[ "${rname}" == "${x_rname}." ]] && continue
  pdnsutil replace-rrset "${k}" . SOA "${ttl}" "${server_fqdn} ${x_rname} ${serial} ${x_refresh} ${x_retry} ${x_expire} ${x_nxttl}"
  pdnsutil increase-serial "${k}"
done

# add ourselves a NS record if we don't have one
for k in "${zones[@]}" ; do
  have_ns=0
  while read -r name ttl type rec value ; do
    [[ "${value}" == "${server_fqdn}." ]] && have_ns=1
  done < <(pdnsutil list-zone "${k}" | grep $'\tIN\tNS\t')
  [[ "${have_ns}" -eq 0 ]] && {
    pdnsutil add-record "${k}" . NS 86400 "${server_fqdn}"
    pdnsutil increase-serial "${k}"
  }
done

add_somewhere_rec() {
  local fqdn="${1}" type="${2}" data="${3}" ndots="${4}"
  local dots="${fqdn//[^\.]/}"
  [[ "${ndots}" ]] || ndots="${#dots}"
  local prefix="${fqdn%%.*}"
  local suffix="${fqdn#${prefix}.}"
  while [[ "${ndots}" -gt 0 ]] ; do
    # do I have a zone that matches suffix? if so, add that and then stop.
    case " ${zones[*]} " in
      *" ${suffix} "*)
        # do we already have the record?
        extrec=''
        extrec=$(pdnsutil list-zone "${suffix}" | grep "^${fqdn}"$'\t' | grep $'\tIN\t'"${type}"$'\t' | cut -d$'\t' -f5)
        # we do not.
        [[ "${extrec}" ]] || {
          pdnsutil add-record "${suffix}" "${prefix}" "${type}" "${data}"
          pdnsutil increase-serial "${suffix}"
          return
        }
        # it's wrong.
        [[ "${extrec}" == "${data}" ]] || {
          pdnsutil replace-rrset "${suffix}" "${prefix}" "${type}" "${data}"
          pdnsutil increase-serial "${suffix}"
        }
        break
      ;;
    esac
    # okay, break one part over to prefix now
    ((ndots--))
    next="${suffix%%.*}"
    prefix="${prefix}.${next}"
    suffix="${suffix#${next}.}"
  done
}

# finally, do we have a zone that matches _us_? if we do, go add to that. longest match wins.
server_range4="$(echo "${dnsauth_xml}" | xmlstarlet sel -t -v 'dnsauth/address/@ipv4')"
server_addr4=''
[[ "${server_range4}" ]] && server_addr4=$(ipcalc "${server_range4}" | awk '$1 == "HostMax:" { print $2 }')
[[ "${server_addr4}" ]] && add_somewhere_rec "${server_fqdn}" A "${server_addr4}"

# reverse lookup too!
[[ "${server_addr4}" ]] && {
  IFS=. read -r o1 o2 o3 o4 < <(echo "${server_addr4}")
  rev4="${o4}.${o3}.${o2}.${o1}.in-addr.arpa"
  add_somewhere_rec "${rev4}" PTR "${server_fqdn}"
}

# finally, sort through our zones and figure out if anything should be a delegation.
for k in "${zones[@]}" ; do
  add_somewhere_rec "${k}" NS "${server_fqdn}." 1
done

exit 0
