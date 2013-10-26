#!/bin/bash

OUTPUT_DIR=${PWD}/output
LINUX_DIR=${PWD}/linux-sunxi
TOOLS_DIR=${PWD}/tools
ROOTFS_DIR=${PWD}/rootfs
ROOTFS_ADDON_DIR=${ROOTFS_DIR}/rootfs_addon
SCRIPTS_DIR=${TOOLS_DIR}/scripts
MKBOOTIMG=${TOOLS_DIR}/pack/pctools/linux/android/mkbootimg
CONFIG_DIR=${TOOLS_DIR}/kernel_config
RPUSBDISPDRV_DIR=${PWD}/rpusbdisp/drivers/linux-driver
RPUSBDISPTOOL_DIR=${PWD}/rpusbdisp/tools/arm_suite/
O_K_DIR=${OUTPUT_DIR}/kernel
O_RAMROOTFS_DIR=${OUTPUT_DIR}/ramrootfs
O_ROOTFS_DIR=${OUTPUT_DIR}/rootfs

CROSS_COMPILE=arm-linux-gnueabi-
#CROSS_COMPILE=arm-none-linux-gnueabi-

build_linux()
{
        cp -f  ${CONFIG_DIR}/* ${LINUX_DIR}/arch/arm/configs/
	cd ${LINUX_DIR}
	make -C ${LINUX_DIR} ARCH=arm robopeak_std_with_rpusbdisp_defconfig
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


build_rpusbdisp()
{
    cd ${RPUSBDISPDRV_DIR}
    make KERNEL_SOURCE_DIR=${LINUX_DIR} ARCH=arm CROSS_COMPILE=${CROSS_COMPILE}
    make KERNEL_SOURCE_DIR=${LINUX_DIR} ARCH=arm install INSTALL_MOD_PATH=${O_K_DIR}/modules
    cd -
}

build_rpusbdisp_tool()
{
    # copy config file
    mkdir -p ${O_ROOTFS_DIR}/etc/rpusbdisp
    mkdir -p ${O_ROOTFS_DIR}/etc/init
    mkdir -p ${O_ROOTFS_DIR}/etc/init.d
    cp -f $RPUSBDISPTOOL_DIR/scripts/rpusbdispd.sh ${O_ROOTFS_DIR}/etc/rpusbdisp/
    chmod +x ${O_ROOTFS_DIR}/etc/rpusbdisp/*.sh 
    cp -f $RPUSBDISPTOOL_DIR/scripts/rpusbdispd ${O_ROOTFS_DIR}/etc/init.d/
    chmod +x ${O_ROOTFS_DIR}/etc/init.d/rpusbdispd
    cp -f $RPUSBDISPTOOL_DIR/conf/rpusbdisp.conf ${O_ROOTFS_DIR}/etc/init/
    cp -f $RPUSBDISPTOOL_DIR/conf/10-disp.conf ${O_ROOTFS_DIR}/etc/rpusbdisp/
}

#rm -rf ${OUTPUT_DIR}
#mkdir -pv ${OUTPUT_DIR}/lib/firmware
build_prepare
build_linux
build_rpusbdisp

#Put nand driver to ramdisk
sudo ${SCRIPTS_DIR}/repack ${O_RAMROOTFS_DIR}


#Create android style boot image
${MKBOOTIMG} --kernel ${O_K_DIR}/bImage \
    --ramdisk ${O_RAMROOTFS_DIR}/rootfs.cpio.gz \
    --board "sun7i" \
    --base 0x40000000 \
    -o ${OUTPUT_DIR}/boot.img


build_rootfs_addon
build_rpusbdisp_tool

${SCRIPTS_DIR}/create_boot_img.sh $1 ${OUTPUT_DIR}/rootfs.ext4 ${O_ROOTFS_DIR}
${SCRIPTS_DIR}/create_livesuit_image.sh ${TOOLS_DIR} ${OUTPUT_DIR}
