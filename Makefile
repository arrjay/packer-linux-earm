.DELETE_ON_ERROR:

.ONESHELL:

.NOTPARALLEL:

.INTERMEDIATE: %.img images/upstream/sheeva.img images/upstream/rock64.img

.PRECIOUS: %.img.xz

DISPLAY := ''
export DISPLAY

CURRENT_USER = $(shell id -u)
CURRENT_GROUP = $(shell id -g)

COMMON_SCRIPTS = $(shell find scripts/common -type f)
GLOVES_SECRETS = $(shell find secrets/gloves -type f)

ARMBIAN_MOD_SCRIPTS = $(shell find scripts/armbian-mod -type f)
LITE_FILES = $(shell find files/lite -path files/lite/cache -prune -o -print -type f)
LITE_SCRIPTS = $(shell find scripts/lite -type f)
NETDATA_SCRIPTS = $(shell find scripts/netdata -type f)
NETDATA_FILES = $(shell find files/netdata -path files/netdata/cache -prune -o -print -type f)
STANDARD_SCRIPTS = $(shell find scripts/standard -type f)
STANDARD_FILES = $(shell find files/standard -path files/standard/cache -prune -o -print -type f)
XFCE_SCRIPTS = $(shell find scripts/xfce -type f)
XFCE_FILES = $(shell find files/xfce -path files/xfce/cache -prune -o -print -type f)
IMD_FILES = $(shell find vendor/imd -type f)
YKMAN_SCRIPTS = $(shell find files/ykman -type f)
YKMAN_FILES = $(shell find files/ykman -path files/ykman/cache -prune -o -print -type f)
MISCSCRIPT_FILES = $(shell find vendor/misc-scripts -type f)
KEYMAT_FILES = $(shell find vendor/keymat -type f)

pi-uuids.json: scripts/genuuid-json.sh
	-rm pi-uuids.json
	./scripts/genuuid-json.sh > pi-uuids.json

%.img.xz.json : %.img.xz
	md5sum $< | awk '{ printf "{ \"dynamic_checksum\": \"%s\" }",$$1 }' > $@

%.img.xz : %.img
	xz -T0 $<

images/upstream/sheeva.img: scripts/sheevaplug-stage1.sh
	-rm images/upstream/sheeva.img*
	./scripts/sheevaplug-stage1.sh

images/upstream/rock64.img: packer_templates/armbian_mod.pkr.hcl $(ARMBIAN_MOD_SCRIPTS)
	-rm images/upstream/rock64.img*
	sudo packer build -only=arm-image.rock64 packer_templates/armbian_mod.pkr.hcl
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/upstream/rock64.img

images/upstream/pi.img:
	echo "packer will directly handle downloading/caching the pi image, creating empty file"
	touch images/upstream/pi.img

images/lite/%.img.xz : images/lite/%.img
	xz -T0 $<

images/lite/%.img: images/upstream/%.img.xz.json packer_templates/lite.pkr.hcl pi-uuids.json $(LITE_FILES) $(LITE_SCRIPTS)
	-rm images/lite/$(@F)*
	sudo packer build -var-file=pi-uuids.json -var-file=$< -only=arm-image.$(@F:.img=) packer_templates/lite.pkr.hcl
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) $@

images/netdata/pi.img.xz: packer_templates/netdata.json $(NETDATA_SCRIPTS) images/lite/pi.img.xz
	-rm -rf images/netdata/pi.img*
	sudo packer build -only=pi packer_templates/netdata.json
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/netdata/pi.img
	xz -T0 images/netdata/pi.img

images/netdata/sheeva.img.xz: packer_templates/netdata.json $(NETDATA_SCRIPTS) images/lite/sheeva.img.xz
	-rm -rf images/netdata/sheeva.img*
	sudo packer build -only=sheeva packer_templates/netdata.json
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/netdata/sheeva.img
	xz -T0 images/netdata/sheeva.img

images/standard/pi.img.xz: packer_templates/standard.json $(STANDARD_SCRIPTS) $(IMD_FILES) $(STANDARD_FILES) images/netdata/pi.img.xz
	-rm -rf images/standard/pi.img*
	sudo packer build -only=pi packer_templates/standard.json
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/standard/pi.img
	xz -T0 images/standard/pi.img

images/standard/sheeva.img.xz: packer_templates/standard.json $(STANDARD_SCRIPTS) $(IMD_FILES) $(STANDARD_FILES) images/netdata/sheeva.img.xz
	-rm -rf images/standard/sheeva.img*
	sudo packer build -only=sheeva packer_templates/standard.json
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/standard/sheeva.img
	xz -T0 images/standard/sheeva.img

images/xfce/pi.img.xz: packer_templates/xfce.json $(XFCE_SCRIPTS) $(XFCE_FILES) images/standard/pi.img.xz
	-rm -rf images/xfce/pi.img*
	sudo packer build -only=pi packer_templates/xfce.json
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/xfce/pi.img
	xz -T0 images/xfce/pi.img

images/ykman/pi.img.xz: packer_templates/ykman.json $(YKMAN_SCRIPTS) $(MISCSCRIPT_FILES) $(KEYMAT_FILES) $(YKMAN_FILES) images/xfce/pi.img.xz
	-rm -rf images/ykman/pi.img*
	sudo packer build -only=pi packer_templates/ykman.json
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) images/ykman/pi.img
	xz -T0 images/ykman/pi.img

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
