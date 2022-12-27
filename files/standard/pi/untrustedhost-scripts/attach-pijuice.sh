#!/usr/bin/env bash

# we're not handed any arguments.
# if you have more than one pijuice attached...how? why?

# we're going to use the same pieces as attach-hidups
# but they're...static.
mkdir -p /run/untrustedhost/nut/ups.conf.d
mkdir -p /run/untrustedhost/nut/discovered-ups.xml.d

vendorid=pijuice
serialno=builtin

echo '<ups/>' | xmlstarlet ed -s 'ups' -t 'attr' -n 'vendor' -v "${vendorid}" \
                  -s 'ups' -t 'attr' -n 'serial' -v "${serialno}" \
                  -s 'ups' -t 'attr' -n 'name' -v "${vendorid}-${serialno}" \
  > "/run/untrustedhost/nut/discovered-ups.xml.d/pijuice.xml"

cat <<EOF>"/run/untrustedhost/nut/ups.conf.d/${vendorid}-${serialno}.conf"
[${vendorid}-${serialno}]
  driver       = pijuice
  port         = /dev/i2c-1
  pollinterval = 2
EOF

# modify nut's conf.xml so that pijuice is *always* your builtin ups...
# deal with no xml config existing first.
[ -s /run/untrustedhost/nut/conf.xml ] || { printf '%s\n' '<nut/>' > /run/untrustedhost/nut/conf.xml ; }

# do I already have the builtin pijuice as an explicit ups in the config? if so, don't touch it.
xmlpath="nut/ups[@vendor=\"${vendorid}\"][@serial=\"${serialno}\"]"
pval="$(xmlstarlet sel -t -v "${xmlpath}/@powervalue" /run/untrustedhost/nut/conf.xml)"
[[ "${pval}" ]] || {
  # do I already have the pijuice defined at all?
  xmled_args=()
  upsnode="$(xmlstarlet sel -t -c "${xmlpath}" /run/untrustedhost/nut/conf.xml)"
  [[ "${upsnode}" ]] || xmled_args=("${xmled_args[@]}" '--subnode' '/nut' '--type' 'elem' '-n' "ups-$$"
                                                       '--subnode' "/nut/ups-$$" '--type' 'attr' '-n' 'vendor' '-v' "${vendorid}"
                                                       '--subnode' "/nut/ups-$$" '--type' 'attr' '-n' 'serial' '-v' "${serialno}"
                                                       '--rename'  "/nut/ups-$$" '-v' 'ups')
  xmled_args=("${xmled_args[@]}" '--subnode' "${xmlpath}" '--type' 'attr' '-n' 'powervalue' '-v' '1')
  tfile="$(mktemp)"
  xmlstarlet ed "${xmled_args[@]}" < /run/untrustedhost/nut/conf.xml > "${tfile}"
  mv "${tfile}" /run/untrustedhost/nut/conf.xml
}
