COMMON_SCRIPTS = $(shell find scripts/common -type f)
base-image/image: base.json $(COMMON_SCRIPTS)
	packer build base.json

dterm-image/image: base-image/image dterm.json scripts/install-dterm.sh
	packer build dterm.json

edger/image: dterm-image/image edger.json scripts/edger.sh
	packer build edger.json

hose/image: dterm-image/image hose.json scripts/hose.sh
	packer build hose.json
