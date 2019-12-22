#!/usr/bin/env bash

mkdir -p /run/imd

IMD_FILE="MDDATA.XML"
IMD_RUN="/run/imd"
IMD_MOUNT="${IMD_RUN}/source"
IMD_PATH="${IMD_MOUNT}/${IMD_FILE}"

. /usr/lib/untrustedhost/shellib/imd.bash

export IMD_MOUNT IMD_PATH

lock_file="${IMD_RUN}/.lock"
# 0 for immidiate fail, see 'man lockfile-progs' for details
lock_retry=0

lock(){
        lockfile-create -r $lock_retry -p $lock_file && return 0
        echo "ERROR: Can't get lock"
        exit $?
}

unlock(){ lockfile-remove $lock_file; }

lock "${lock_file}" "${lock_retry}"

# give a moment for /dev/disk/by-label/IMD
sleep 1

[[ -e /dev/disk/by-label/IMD ]] || { unlock ; exit 0 ; }

mkdir -p "${IMD_MOUNT}"

mount -o ro /dev/disk/by-label/IMD "${IMD_MOUNT}"

[[ -f "${IMD_PATH}" ]] || { unlock ; exit 0 ; }

# at this point we have a metadata file, try pulling things from it
xml_hn=$(xmlstarlet sel -t -v 'metadata/domain/name' < "${IMD_PATH}")
[[ "${xml_hn}" != '' ]] && { hostnamectl set-hostname "${xml_hn}" ; }

router_id=$(xmlstarlet sel -t -v metadata/router/@id "${IMD_PATH}")

bridges="$(xmlstarlet sel -t -v 'metadata/domain/devices/interface/source/@bridge' "${IMD_PATH}")"

for b in ${bridges} ; do
  selpath="metadata/domain/devices/interface[source/@bridge=\"${b}\"]"
  int_ipv4='' ; int_mac='' ; int_mtu='' ; ext_ifname='' ; ifmac='' ; ifmtu=''
  int_ipv4="$(xmlstarlet sel -t -v "${selpath}/ipv4/@address" "${IMD_PATH}")"
  int_mac="$(xmlstarlet sel -t -v "${selpath}/mac/@address" "${IMD_PATH}")"
  [[ "${int_ipv4}" ]] && [[ "${int_mac}" ]] && {
    {
      printf '%s\n' '[Match]'
      printf 'MACAddress=%s\n' "${int_mac}"

      printf '%s\n' '[Network]'
      printf 'Address=%s\n' "${int_ipv4}"

      int_mtu="$(xmlstarlet sel -t -v "${selpath}/mtu/@size" "${IMD_PATH}")"
      [[ "${int_mtu}" ]] && printf '[Link]\nMTUBytes=%s\n' "${int_mtu}"
    } > "/etc/systemd/network/${b}.network"

    {
      printf '%s\n' '[Match]'
      printf 'MACAddress=%s\n' "${int_mac}"

      printf '%s\n' '[Link]'
      printf 'Name=%s\n' "${b}"
    } > "/etc/systemd/network/${b}.link"

    # HACK. rename the interface now if needed.
    for f in /sys/class/net/*/address ; do
      read -r ifmac < "${f}"
      [[ "${ifmac}" == "${int_mac}" ]] && {
        ext_ifname="${f%/address}"
        ext_ifname="${ext_ifname##*/}"
        # if it's already the name, evaporate into noop
        [[ "${ext_ifname}" == "${b}" ]] && ext_ifname=''
      }
    done
    [[ "${ext_ifname}" ]] && {
      /usr/bin/ip link set "${ext_ifname}" down
      /usr/bin/ip link set "${ext_ifname}" name "${b}"
      /usr/bin/ip link set "${b}" up
    }

    # ditto MTU!
    [[ -e "/sys/class/net/${b}/mtu" ]] && read -r ifmtu < "/sys/class/net/${b}/mtu"
    [[ "${int_mtu}" ]] && {
      /usr/bin/ip link set "${b}" mtu "${int_mtu}"
    }
  }
done

[[ "${router_id}" ]] && {
  printf 'router id %s;\n' "${router_id}" > /etc/bird/router_id.conf
  chown bird:bird /etc/bird/router_id.conf

  # check for ospf areas assigned to interfaces
  ospf_areas='' ; ospf_areas="$(xmlstarlet sel -t -v 'metadata/domain/devices/interface[@type="bridge"]/ospf/@area' "${IMD_PATH}")"
  [[ "${ospf_areas[*]}" ]] && {
    {
      ospf_seen=()
      # write the ospf protocol section
      printf 'protocol ospf {\n  export where match_route();\n'
      for area in ${ospf_areas} ; do
        # write an area section
        case " ${ospf_seen[*]} " in
          *" ${area} "*) continue ;;
        esac
        printf '  area %s {\n    stub no;\n' "${area}"
        # process interfaces for the area
        ospf_ifs=''
        ospf_ifs="$(xmlstarlet sel -t -v 'metadata/domain/devices/interface[@type="bridge"][ospf/@area="'"${area}"'"]/source/@bridge' "${IMD_PATH}")"
        for iface in ${ospf_ifs} ; do
          printf '    interface "%s" {\n' "${iface}"
          # now, check for authentications...
          ospf_keyids=''
          ospf_keyids="$(xmlstarlet sel -t -v 'metadata/router/ospf[@area="'"${area}"'"]/authentication/@key' "${IMD_PATH}")"
          [[ "${ospf_keyids[*]}" ]] && printf '      authentication cryptographic;\n'
          for keyid in ${ospf_keyids} ; do
            ospf_pass=''
            ospf_pass="$(xmlstarlet sel -t -v 'metadata/router/ospf[@area="'"${area}"'"]/authentication[@key="'"${keyid}"'"]/@password' "${IMD_PATH}")"
            [[ "${ospf_pass}" ]] && printf '      password "%s" { id %s; };\n' "${ospf_pass}" "${keyid}"
          done
          printf '      type broadcast;\n    };\n'
        done
        printf '  };\n'
        ospf_seen=("${ospf_seen[@]}" "${area}")
      done
      # close the ospf proto section
      printf '}\n'
    } >> /etc/bird/ospf_areas.conf
    chown bird:bird /etc/bird/ospf_areas.conf
  }
}

for f in /usr/lib/untrustedhost/imd/* ; do
  [[ -x "${f}" ]] && { "${f}" || { umount /run/imd/source ; unlock ; exit 1 ; } ; }
done

umount /run/imd/source

unlock
