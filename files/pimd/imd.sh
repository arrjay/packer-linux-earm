#!/usr/bin/env bash

mkdir -p /run/imd

IMD_FILE="MDDATA.XML"
IMD_RUN="/run/imd"
IMD_MOUNT="/boot/imd"
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

[[ -f "${IMD_PATH}" ]] || { unlock ; exit 0 ; }

# at this point we have a metadata file, try pulling things from it
xml_hn=$(xmlstarlet sel -t -v 'metadata/domain/name' < "${IMD_PATH}")
[[ "${xml_hn}" != '' ]] && { hostnamectl set-hostname "${xml_hn}" ; }

router_id=$(xmlstarlet sel -t -v metadata/router/@id "${IMD_PATH}")

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
  [[ -x "${f}" ]] && { "${f}" || { unlock ; exit 1 ; } ; }
done

unlock
