setenv load_addr_r "0x9000000"
setenv kernel_addr_r "0x00800000"
setenv ramdisk_addr_r "0x01100000"
#setenv fdt_addr_r "0x00ff0000"
#setenv fdtfile "kirkwood-sheevaplug.dtb"

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum} ${prefix}sheevaEnv.txt ; then
        ext2load ${devtype} ${devnum} ${load_addr_r} ${prefix}sheevaEnv.txt
        env import -t ${load_addr_r} ${filesize}
fi

# we need the DTB up first to set up chosen
#ext2load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
#fdt addr ${fdt_addr_r} 0x40000
#fdt resize
#fdt chosen

# load linux, initrd now.
ext2load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}uImage
#fdt set /chosen linux,initrd-start ${ramdisk_addr_r}
ext2load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd
#fdt set /chosen linux,initrd-end ${filesize} # 6b73e3

# finally, set the bootargs
setenv bootargs console=${linux_console} cmdline.mtdparts=${mtdparts} root=${linux_rootdev} ${extraargs}
#fdt set /chosen bootargs "${bootargs}"

bootm ${kernel_addr_r} ${ramdisk_addr_r}
# bootm ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
