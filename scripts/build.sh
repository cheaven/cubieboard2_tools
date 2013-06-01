#!/bin/bash

OUTPUT_DIR=${PWD}/output
LINUX_DIR=${PWD}/linux-sunxi
TOOLS_DIR=${PWD}/tools
ROOTFS_DIR=${PWD}/rootfs
ROOTFS_ADDON_DIR=${ROOTFS_DIR}/rootfs_addon
SCRIPTS_DIR=${TOOLS_DIR}/scripts
MKBOOTIMG=${TOOLS_DIR}/pack/pctools/linux/android/mkbootimg

O_K_DIR=${OUTPUT_DIR}/kernel
O_RAMROOTFS_DIR=${OUTPUT_DIR}/ramrootfs
O_ROOTFS_DIR=${OUTPUT_DIR}/rootfs

CROSS_COMPILE=arm-linux-gnueabi-
#CROSS_COMPILE=arm-none-linux-gnueabi-

build_linux()
{
	cd ${LINUX_DIR}
	make -C ${LINUX_DIR} ARCH=arm cubieboard2_defconfig
	make -C ${LINUX_DIR} ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} kernelrelease
	make -C ${LINUX_DIR}/arch/arm/mach-sun7i/pm/standby ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} KDIR=${LINUX_DIR} all
	make -C ${LINUX_DIR} ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j4 uImage modules
	${CROSS_COMPILE}objcopy -R .note.gnu.build-id -S -O binary ${LINUX_DIR}/vmlinux ${O_K_DIR}/bImage
	cp ${LINUX_DIR}/arch/arm/boot/uImage ${O_K_DIR}

	(
	make -C ${LINUX_DIR}/modules/nand ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} \
		LICHEE_MOD_DIR=${O_RAMROOTFS_DIR} LICHEE_KDIR=${LINUX_DIR} install
	)

	make -C ${LINUX_DIR} ARCH=arm modules_install INSTALL_MOD_PATH=${O_K_DIR}/modules
	make -C ${LINUX_DIR} ARCH=arm firmware_install INSTALL_FW_PATH=${O_K_DIR}/firmware
	cd -
}

build_prepare()
{
    sudo rm -rf ${OUTPUT_DIR}
    mkdir -p ${O_K_DIR} ${O_RAMROOTFS_DIR} ${O_ROOTFS_DIR}
    cp ${ROOTFS_DIR}/rootfs_skel.cpio.gz ${O_RAMROOTFS_DIR}/
}

build_rootfs_addon()
{
    (cd ${ROOTFS_ADDON_DIR}; tar -c * |tar -xv -C ${O_ROOTFS_DIR})
    cp -rf ${O_K_DIR}/modules/* ${O_ROOTFS_DIR}/
    cp -rf ${O_K_DIR}/firmware ${O_ROOTFS_DIR}/lib/
}

#rm -rf ${OUTPUT_DIR}
#mkdir -pv ${OUTPUT_DIR}/lib/firmware
build_prepare
build_linux

#Put nand driver to ramdisk
sudo ${SCRIPTS_DIR}/repack ${O_RAMROOTFS_DIR}

#Create android style boot image
${MKBOOTIMG} --kernel ${O_K_DIR}/bImage \
    --ramdisk ${O_RAMROOTFS_DIR}/rootfs.cpio.gz \
    --board "sun7i" \
    --base 0x40000000 \
    -o ${OUTPUT_DIR}/boot.img

build_rootfs_addon

${SCRIPTS_DIR}/create_boot_img.sh $1 ${OUTPUT_DIR}/rootfs.ext4 ${O_ROOTFS_DIR}
${SCRIPTS_DIR}/create_livesuit_image.sh ${TOOLS_DIR} ${OUTPUT_DIR}
