ifneq ($(DKMS_KERNEL_VERSION),)
KERNELVER = $(DKMS_KERNEL_VERSION)
else 
KERNELVER ?= $(shell uname -r) 
endif 
 
# allow to build for other headers
KERNEL_SRC ?= /lib/modules/$(KERNELVER)/build

obj-m += xt_cgroup.o

all:
	make -C $(KERNEL_SRC) M=$(CURDIR) modules

clean:
	make -C $(KERNEL_SRC) M=$(CURDIR) clean

install:
	make -C $(KERNEL_SRC) M=$(CURDIR) modules_install
