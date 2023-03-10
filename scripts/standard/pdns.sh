#!/usr/bin/env bash

set -e

case "${PACKER_BUILD_NAME}" in
  sheeva) exit 0 ;;
esac

printf '%s\n' "pdns-backend-sqlite3 pdns-backend-sqlite3/dbconfig-install boolean false" \
     | debconf-set-selections

apt-get install pdns-backend-sqlite3 sqlite3 uuid
systemctl disable pdns

mkdir -p /usr/lib/untrustedhost/share

cp /usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql \
   /usr/lib/untrustedhost/share/schema.sqlite3.sql
