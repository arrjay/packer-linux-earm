#!/usr/bin/env bash
set -x

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# upgrade avahi if we have avahi debs available.
[[ -f "${PFSRC}/cache/${PACKER_BUILD_NAME}/avahi_debs.tar.xz" ]] || exit 0

cd /tmp || exit 1
tar xf "${PFSRC}/cache/${PACKER_BUILD_NAME}/avahi_debs.tar.xz"

installed="$(mktemp)"

dpkg -l|awk '$1 == "ii" { split($2,a,":") ; print a[1] }' > "${installed}"
available_files=(./debs/*)

files_to_install=()
packages_to_hold=()

for file in "${available_files[@]}" ; do
  pkgname="${file#./debs/}"
  pkgname="${pkgname%%_*}"
  grep -qF "${pkgname}" "${installed}" && {
    files_to_install=("${files_to_install[@]}" "${file}")
    packages_to_hold=("${packages_to_hold[@]}" "${pkgname}")
  }
done

[[ "${packages_to_hold[*]}" ]] && {
  dpkg -i "${files_to_install[@]}"
  {
    for pkgname in "${packages_to_hold[@]}" ; do
      printf '%s hold\n' "${pkgname}"
    done
  } | dpkg --set-selections
}

apt-get install -f
