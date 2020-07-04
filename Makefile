.DELETE_ON_ERROR:

DISPLAY := ''
export DISPLAY

COMMON_SCRIPTS = $(shell find scripts/common -type f)
GLOVES_SECRETS = $(shell find secrets/gloves -type f)

LITE_FILES = $(shell find files/lite -type f)
LITE_SCRIPTS = $(shell find scripts/lite -type f)

images/lite/pi.img: packer_templates/lite.json $(LITE_FILES) $(LITE_SCRIPTS)
	-rm -rf images/lite/pi.img
	packer build -only=pi packer_templates/lite.json

netdata-image/image: lite-image/image netdata.json scripts/netdata.sh
	-rm -rf netdata-image
	packer build netdata.json

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

aerator/image: hose/image aerator.json
	-rm -rf aerator
	packer build aerator.json

gloves/image: xfce-image/image gloves.json scripts/gloves.sh $(GLOVES_SECRETS)
	-rm -rf gloves
	packer build gloves.json

trowel/image: xfce-image/image trowel.json scripts/trowel.sh $(TROWEL_SECRETS)
	-rm -rf trowel
	packer build trowel.json
