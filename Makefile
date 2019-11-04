COMMON_SCRIPTS = $(shell find scripts/common -type f)
base-image/image: base.json $(COMMON_SCRIPTS)
	-rm -rf base-image
	packer build base.json

dterm-image/image: base-image/image dterm.json scripts/install-dterm.sh
	-rm -rf dterm-image
	packer build dterm.json

xfce-image/image: dterm-image/image xfce.json scripts/install-xfce.sh
	-rm -rf xfce-image
	packer build xfce.json

edger/image: dterm-image/image edger.json scripts/edger.sh
	-rm -rf edger
	packer build edger.json

hose/image: dterm-image/image hose.json scripts/hose.sh
	-rm -rf hose
	packer build hose.json

gloves/image: xfce-image/image gloves.json scripts/gloves.sh
	-rm -rf gloves
	packer build gloves.json
