#!/usr/bin/env bash

# builds on imd
. /usr/lib/untrustedhost/shellib/imd.bash

return_siaddr() {
        local addrs=()
        addrs=($(getaddrsv4 "${1}"))
        hx="$(ipcalc "${addrs[0]}"|awk '$1 == "HostMax:" { print $2 }')"
        printf 'SIADDR=%s\n' "${hx}"
}
