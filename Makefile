.DELETE_ON_ERROR:

DISPLAY := ''
export DISPLAY

COMMON_SCRIPTS = $(shell find scripts/common -type f)
GLOVES_SECRETS = $(shell find secrets/gloves -type f)

LITE_FILES = $(shell find files/lite -path files/lite/cache -prune -o -print -type f)
LITE_SCRIPTS = $(shell find scripts/lite -type f)
NETDATA_SCRIPTS = $(shell find scripts/netdata -type f)
NETDATA_FILES = $(shell find files/netdata -path files/netdata/cache -prune -o -print -type f)
STANDARD_SCRIPTS = $(shell find scripts/standard -type f)
STANDARD_FILES = $(shell find files/standard -path files/standard/cache -prune -o -print -type f)
XFCE_SCRIPTS = $(shell find scripts/xfce -type f)
XFCE_FILES = $(shell find files/xfce -path files/xfce/cache -prune -o -print -type f)

pi-uuids.json:
	-rm pi-uuids.json
	./scripts/genuuid-json.sh > pi-uuids.json

images/upstream/sheevaplug-s1.img.xz: scripts/sheevaplug-stage1.sh
	-rm images/upstream/sheevaplug-s1.img
	./scripts/sheevaplug-stage1.sh

images/upstream/pi-s1.img: packer_templates/pi-stage1.json pi-uuids.json
	-rm images/upstream/pi-s1.img*
	packer build -var-file=pi-uuids.json packer_templates/pi-stage1.json

images/lite/pi.img: packer_templates/lite.json pi-uuids.json $(LITE_FILES) $(LITE_SCRIPTS)
	-rm -rf images/lite/pi.img*
	packer build -var-file=pi-uuids.json -only=pi packer_templates/lite.json

images/lite/sheeva.img: packer_templates/lite.json $(LITE_FILES) $(LITE_SCRIPTS) images/upstream/sheevaplug-s1.img.xz
	-rm -rf images/lite/sheeva.img*
	packer build -only=sheeva packer_templates/lite.json

images/netdata/pi.img: packer_templates/netdata.json $(NETDATA_SCRIPTS) images/lite/pi.img.xz
	-rm -rf images/netdata/pi.img*
	packer build -only=pi packer_templates/netdata.json

images/netdata/sheeva.img: packer_templates/netdata.json $(NETDATA_SCRIPTS) images/lite/sheeva.img.xz
	-rm -rf images/netdata/sheeva.img*
	packer build -only=sheeva packer_templates/netdata.json

images/standard/pi.img: packer_templates/standard.json $(STANDARD_SCRIPTS) $(STANDARD_FILES) images/netdata/pi.img.xz
	-rm -rf images/standard/pi.img*
	packer build -only=pi packer_templates/standard.json

images/standard/sheeva.img: packer_templates/standard.json $(STANDARD_SCRIPTS) $(STANDARD_FILES) images/netdata/sheeva.img.xz
	-rm -rf images/standard/sheeva.img*
	packer build -only=sheeva packer_templates/standard.json

images/xfce/pi.img: packer_templates/xfce.json $(XFCE_SCRIPTS) $(XFCE_FILES) images/standard/pi.img.xz
	-rm -rf images/xfce/pi.img*
	packer build -only=pi packer_templates/xfce.json

%.img.xz: %.img
	xz -T0 $<

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
