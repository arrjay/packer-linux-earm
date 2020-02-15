#!/usr/bin/env bash

# run a script in support/imd/<foo>.sh and save output to packer_cache/imd/<foo>.xml

mkdir -p packer_cache/imd

[[ -e "./support/imd/${TARGET}.sh" ]] && "./support/imd/${TARGET}.sh" > "packer_cache/imd/${TARGET}.xml"
