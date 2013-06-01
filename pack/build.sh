#!/bin/bash

OUT_ROOT=${PWD}/out
LINUX_ROOT=${PWD}/linux-sunxi
TOOLS_ROOT=${PWD}/sunxi-tools

CROSS_COMPILE=arm-linux-gnueabi-
#CROSS_COMPILE=arm-none-linux-gnueabi-

build_tools()
{
	make -C ${TOOLS_ROOT} all
	${TOOLS_ROOT}/fex2bin sunxi-boards/sys_config/a20/cubieboard2.fex ${OUT_ROOT}/script.bin
}

build_linux()
{
	cd ${LINUX_ROOT}
	make -C ${LINUX_ROOT} ARCH=arm cubieboard2_defconfig
	make -C ${LINUX_ROOT} ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} kernelrelease
	make -C ${LINUX_ROOT}/arch/arm/mach-sun7i/pm/standby ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} KDIR=${LINUX_ROOT} all
	make -C ${LINUX_ROOT} ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j4 uImage modules
	${CROSS_COMPILE}objcopy -R .note.gnu.build-id -S -O binary ${LINUX_ROOT}/vmlinux ${OUT_ROOT}/bImage
	cp ${LINUX_ROOT}/arch/arm/boot/uImage ${OUT_ROOT}

	(
	#export LANG=en_US.UTF-8
	#unset LANGUAGE
	#make -C ${LINUX_ROOT}/modules/mali LICHEE_MOD_DIR=${OUT_ROOT} LICHEE_KDIR=${LINUX_ROOT} install
	make -C ${LINUX_ROOT}/modules/nand ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} \
		LICHEE_MOD_DIR=${OUT_ROOT} LICHEE_KDIR=${LINUX_ROOT} install
	)

	make -C ${LINUX_ROOT} ARCH=arm modules_install INSTALL_MOD_PATH=${OUT_ROOT}
	make -C ${LINUX_ROOT} ARCH=arm firmware_install INSTALL_FW_PATH=${OUT_ROOT}/lib/firmware
	make -C ${LINUX_ROOT} ARCH=arm headers_install INSTALL_HDR_PATH=${OUT_ROOT}/header

	cd -
}

build_post()
{
	cp ${OUT_ROOT}/bImage pack/images/
	cp ${OUT_ROOT}/nand.ko pack/images/
	rm -rf pack/images/target/lib/modules pack/images/target/lib/firmware
	rm -rf pack/images/target/vendor/*
	cp -v ${OUT_ROOT}/*.ko pack/images/target/vendor/
	cp -r ${OUT_ROOT}/lib/* pack/images/target/lib/
}

rm -rf ${OUT_ROOT}
mkdir -pv ${OUT_ROOT}/lib/firmware
#build_tools
build_linux
build_post


(cd pack/images; ./create_boot_img.sh)
(cd pack; ./create_lisuit_image.sh)
