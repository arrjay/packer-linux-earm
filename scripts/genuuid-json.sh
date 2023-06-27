#!/usr/bin/env bash

command -v jq >/dev/null 2>&1 || exit 1
command -v uuidgen >/dev/null 2>&1 || exit 1

uuidgen_trunc () {
 out="$(uuidgen)"
 out="${out%%-*}"
 printf '%s\n' "${out}"
}

# ext class fs can use full uuid
pi_rootfs_uuid="$(uuidgen)"
# vfat uses a truncated uuid
pi_bootfs_id="$(uuidgen_trunc)"
# partition id also uses a truncated uuid
pi_disk_id="$(uuidgen_trunc)"
# rock64 uses an ext2 partition, so full uuid it is
rock64_bootfs_uuid="$(uuidgen)"
rock64_imdfs_id="$(uuidgen_trunc)"
rock64_disk_id="$(uuidgen_trunc)"
# espressobin gets a boot fs, imd and disk...
espressobin_bootfs_uuid="$(uuidgen)"
espressobin_imdfs_id="$(uuidgen_trunc)"
espressobin_disk_id="$(uuidgen_trunc)"

# jq here is making sure we play nice ;)
lc=0
{
	printf '%s' '{'
	for k in pi_rootfs_uuid pi_bootfs_id pi_disk_id \
		 rock64_bootfs_uuid rock64_imdfs_id rock64_disk_id \
		 espressobin_bootfs_uuid espressobin_imdfs_id espressobin_disk_id ; do
		[[ "${lc}" -gt 0 ]] && printf '%s' ','
		printf '"%s":' "${k}"
		printf '"%s"' "${!k}"
		(( lc++ ))
	done
	printf '%s' '}'
} | jq .
