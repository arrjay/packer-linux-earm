#!/usr/bin/env bash

### this file is designed to be sourced not run.

err() {
  echo "${*}" 1>&2
}

lock() {
  local path="${1:-/tmp/.scriptlock}" retry="${2:-0}"
  lockfile-create -r "${retry}" -p "${path}" && return 0
  err "ERROR: Can't get lock at ${path}"
  return 1
}

unlock() {
  local path="${1:-/tmp/.scriptlock}"
  lockfile-remove "${path}" && return 0
  err "ERROR: Not your lock at ${path}"
  return 1
}
