#!/usr/bin/env bash

command -v jq >/dev/null 2>&1 || exit 1
command -v uuidgen >/dev/null 2>&1 || exit 1

# ext class fs can use full uuid
rootfs_uuid="$(uuidgen)"
# vfat uses a truncated uuid
bootfs_id="$(uuidgen)"
bootfs_id="${bootfs_id%%-*}"
# partition id also uses a truncated uuid
partition_id="$(uuidgen)"
partition_id="${partition_id%%-*}"
# rock64 uses an ext2 partition, so full uuid it is
rk64_bootfs_uuid="$(uuidgen)"
rk64_partition_id="$(uuidgen)"
rk64_partition_id="${rk64_partition_id%%-*}"

# jq here is making sure we play nice ;)
lc=0
{
	printf '%s' '{'
	for k in rootfs_uuid bootfs_id partition_id rk64_bootfs_uuid rk64_partition_id ; do
		[[ "${lc}" -gt 0 ]] && printf '%s' ','
		printf '"%s":' "${k}"
		printf '"%s"' "${!k}"
		(( lc++ ))
	done
	printf '%s' '}'
} | jq .
