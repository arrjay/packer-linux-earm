#!/usr/bin/env bash

# walk the dnsupdate xml and check all the zones
hostct="$(xmlstarlet sel -t -v 'count(/dns-update/host)' /run/untrustedhost/dns-update.xml)"
[[ "${hostct}" ]] || hostct=0

zones=($(xmlstarlet sel -t -v '/dns-update/zone/@name' /run/untrustedhost/dns-update.xml))

while [[ "${hostct}" -gt 0 ]] ; do
  name="$(xmlstarlet sel -t -v '/dns-update/host['"${hostct}"']/@name' /run/untrustedhost/dns-update.xml)"
  ip="$(xmlstarlet sel -t -v '/dns-update/host['"${hostct}"']/@ip' /run/untrustedhost/dns-update.xml)"
  IFS=. read -r -a ip4 <<<"${ip}"
  rev="${ip4[3]}.${ip4[2]}.${ip4[1]}.${ip4[0]}.in-addr.arpa"
  dest='' ; rdest=''
  ndots="${name//[^.]}"
  ndots="${#ndots}"
  zdots=0
  rdots=0
  for zone in "${zones[@]}" ; do
    # longest zone match wins
    [[ "${name}" == *"${zone}" ]] && {
      cdots="${zone//[^.]}"
      cdots="${#cdots}"
      [[ "${cdots}" -gt "${zdots}" ]] && dest="${zone}"
    }
    [[ "${rev}" == *"${zone}" ]] && {
      rcdots="${zone//[^.]}"
      rcdots="${#rcdots}"
      [[ "${rcdots}" -gt "${rdots}" ]] && rdest="${zone}"
    }
  done
  hostct=$((hostct - 1))
  [[ "${dest}" ]] && {
    destns="$(xmlstarlet sel -t -v '/dns-update/zone[@name="'"${dest}"'"]/@ns' /run/untrustedhost/dns-update.xml)"
    host "${name}" "${destns}" > /dev/null || {
      nsurec="$(mktemp)"
      {
        printf 'server %s\n' "${destns}"
        printf 'update delete %s A\n' "${name}"
        printf 'update add %s 86400 A %s\n' "${name}" "${ip}"
        printf 'send\nquit\n'
      } > "${nsurec}"
      nsu_args=()
      tsk="$(xmlstarlet sel -t -v '/dns-update/zone[@name="'"${dest}"'"]/@key' /run/untrustedhost/dns-update.xml)"
      [[ "${tsk}" ]] && {
        algo="$(xmlstarlet sel -t -v '/dns-update/tsigkey[@name="'"${tsk}"'"]/@algo' /run/untrustedhost/dns-update.xml)"
        [[ "${algo}" ]] && algo="${algo}:"
        data="$(xmlstarlet sel -t -v '/dns-update/tsigkey[@name="'"${tsk}"'"]/@data' /run/untrustedhost/dns-update.xml)"
        nsu_args=("-y" "${algo}${tsk}:${data}")
      }
      nsupdate "${nsu_args[@]}" "${nsurec}"
      rndc flush
      rm "${nsurec}"
    }
  }

  [[ "${rdest}" ]] && {
    rdestns="$(xmlstarlet sel -t -v '/dns-update/zone[@name="'"${rdest}"'"]/@ns' /run/untrustedhost/dns-update.xml)"
    dig -t PTR "${rev}" "${rdestns}" | grep -v '^;' | grep -q PTR || {
      nsurec_r="$(mktemp)"
      {
        printf 'server %s\n' "${destns}"
        printf 'update delete %s PTR\n' "${rev}"
        printf 'update add %s 86400 PTR %s\n' "${rev}" "${name}"
        printf 'send\nquit\n'
      } > "${nsurec_r}"
      nsur_args=()
      rtsk="$(xmlstarlet sel -t -v '/dns-update/zone[@name="'"${rdest}"'"]/@key' /run/untrustedhost/dns-update.xml)"
      [[ "${rtsk}" ]] && {
        r_algo="$(xmlstarlet sel -t -v '/dns-update/tsigkey[@name="'"${rtsk}"'"]/@algo' /run/untrustedhost/dns-update.xml)"
        [[ "${r_algo}" ]] && r_algo="${r_algo}:"
        r_data="$(xmlstarlet sel -t -v '/dns-update/tsigkey[@name="'"${rtsk}"'"]/@data' /run/untrustedhost/dns-update.xml)"
        nsur_args=("-y" "${r_algo}${rtsk}:${r_data}")
      }
      nsupdate "${nsur_args[@]}" "${nsurec_r}"
      rndc flush
      rm "${nsurec_r}"
    }
  }
done

exit 0
