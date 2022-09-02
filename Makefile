.DELETE_ON_ERROR: %.img

.ONESHELL:

# used to coerce INTERMEDIATE to ignore .img files not existing, and .PRECIOUS to keep compressed versions
TARGETS := rock64 pi sheeva
TYPES := upstream lite netdata standard
IMAGES := $(addprefix images/, $(foreach targ, $(TARGETS), $(addsuffix /$(targ).img, $(TYPES))))
COMPRESSED_IMAGES := $(addsuffix .xz, $(IMAGES))

.NOTPARALLEL:

.INTERMEDIATE: $(IMAGES) images/lite/cache/resolv.conf

.PRECIOUS: $(COMPRESSED_IMAGES)

# turn off DISPLAY as a matter of course (forces packer to always be headless)
DISPLAY := ''
export DISPLAY

# arm-image builder actually runs as root, so this will let us chown files back.
CURRENT_USER = $(shell id -u)
CURRENT_GROUP = $(shell id -g)

COMMON_SCRIPTS = $(shell find scripts/common -type f)
GLOVES_SECRETS = $(shell find secrets/gloves -type f)

# dependencies to the packer templates
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

# filesystem/disk UUIDs for when we scramble the pi/rock64 image
fs-uuids.json: scripts/genuuid-json.sh
	-rm pi-uuids.json
	./scripts/genuuid-json.sh > fs-uuids.json

# for any given compressed image, make a dynamic_checksum varfile
# so that we can reference it in a packer template
# this works around arm-image not understanding "none" as a checksum
%.img.xz.json : %.img.xz
	mkdir -p $(@D)
	md5sum $< | awk '{ printf "{ \"dynamic_checksum\": \"%s\" }",$$1 }' > $@

# compress images
%.img.xz : %.img
	-rm $@
	xz -T0 $<

#  upstream images are the weird ones - they've all got their own recipes
images/upstream/sheeva.img: scripts/sheevaplug-stage1.sh
	-rm $@*
	./scripts/sheevaplug-stage1.sh

images/upstream/rock64.img: packer_templates/armbian_mod.pkr.hcl fs-uuids.json $(ARMBIAN_MOD_SCRIPTS)
	-rm $@*
	sudo packer build -only=arm-image.rock64 -var-file=fs-uuids.json packer_templates/armbian_mod.pkr.hcl || rm $@
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) $@

images/upstream/pi.img:
	-rm $@*
	echo "packer will directly handle downloading/caching the pi image, creating empty file"
	touch $@

# we stuff a copy of resolv.conf in lite's cache
files/lite/cache/resolv.conf:
	cat /etc/resolv.conf > files/lite/cache/resolv.conf

# compress lite images
images/lite/%.img.xz : images/lite/%.img
	-rm $@
	xz -T0 $<

# create lite images
images/lite/%.img: images/upstream/%.img.xz.json packer_templates/lite.pkr.hcl fs-uuids.json $(LITE_FILES) $(LITE_SCRIPTS) files/lite/cache/resolv.conf
	-rm images/lite/$(@F)*
	sudo packer build -var-file=fs-uuids.json -var-file=$< -only=arm-image.$(@F:.img=) packer_templates/lite.pkr.hcl || rm $@
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) $@

# compress netdata images
images/netdata/%.img.xz : images/netdata/%.img
	-rm $@
	xz -T0 $<

images/netdata/%.img: images/lite/%.img.xz.json packer_templates/netdata.pkr.hcl $(NETDATA_SCRIPTS)
	-rm images/netdata/$(@F)*
	sudo packer build -var-file=$< -only=arm-image.$(@F:.img=) packer_templates/netdata.pkr.hcl || rm $@
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) $@

# standard images
images/standard/%.img.xz : images/standard/%.img
	-rm $@
	xz -T0 $<

images/standard/%.img: images/netdata/%.img.xz.json packer_templates/standard.pkr.hcl $(STANDARD_SCRIPTS) $(IMD_FILES) $(STANDARD_FILES)
	-rm -rf images/standard/$(@F)*
	sudo packer build -var-file=$< -only=arm-image.$(@F:.img=) packer_templates/standard.pkr.hcl || rm $@
	sudo chown $(CURRENT_USER):$(CURRENT_GROUP) $@

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
