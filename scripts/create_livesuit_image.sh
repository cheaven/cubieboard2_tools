#!/bin/bash

TOOLS_DIR=$1
OUTPUT_DIR=$2

LINUX_TOOLS_DIR=${TOOLS_DIR}/pack/pctools/linux
O_PACK_DIR=${OUTPUT_DIR}/pack

U_BOOT_IMAGE=
BOOT_IMAGE=${OUTPUT_DIR}/boot.img
ROOTFS_IMAGE=${OUTPUT_DIR}/rootfs.ext4

IMAGES_DIR=${PWD}/images

export PATH=${LINUX_TOOLS_DIR}/mod_update:${LINUX_TOOLS_DIR}/eDragonEx:${LINUX_TOOLS_DIR}/fsbuild200:${LINUX_TOOLS_DIR}/android:$PATH 
function do_prepare()
{
    [ -d ${O_PACK_DIR} ] && rm -rf ${O_PACK_DIR}
    mkdir ${O_PACK_DIR}

    cp -r ${TOOLS_DIR}/pack/chips/sun7i/eFex ${O_PACK_DIR}
    cp -r ${TOOLS_DIR}/pack/chips/sun7i/eGon ${O_PACK_DIR}
    cp -r ${TOOLS_DIR}/pack/chips/sun7i/wboot ${O_PACK_DIR}
}

function do_parse()
{
    [ -f ${O_PACK_DIR}/sys_partition.fex ] && script_parse -f ${O_PACK_DIR}/sys_partition.fex
    [ -f ${O_PACK_DIR}/sys_config.fex ] && script_parse -f ${O_PACK_DIR}/sys_config.fex
}

function do_pack_cb()
{
    echo "Start Generating image for cb"
    cp -f ${TOOLS_DIR}/pack/chips/sun7i/configs/linux/default/* ${O_PACK_DIR}/
    cp -f ${TOOLS_DIR}/pack/chips/sun7i/configs/linux/cubieboard/*.fex ${O_PACK_DIR}/
    cp -f ${TOOLS_DIR}/pack/chips/sun7i/configs/linux/cubieboard/*.cfg ${O_PACK_DIR}/ 2>/dev/null
    
    do_parse

    cp -rf ${O_PACK_DIR}/eFex/split_xxxx.fex ${O_PACK_DIR}/wboot/bootfs ${O_PACK_DIR}/wboot/bootfs.ini ${O_PACK_DIR}
    cp -f ${O_PACK_DIR}/eGon/boot0_nand.bin   ${O_PACK_DIR}/boot0_nand.bin
    cp -f ${O_PACK_DIR}/eGon/boot1_nand.bin   ${O_PACK_DIR}/boot1_nand.fex
    cp -f ${O_PACK_DIR}/eGon/boot0_sdcard.bin ${O_PACK_DIR}/boot0_sdcard.fex
    cp -f ${O_PACK_DIR}/eGon/boot1_sdcard.bin ${O_PACK_DIR}/boot1_sdcard.fex

    (
    cd ${O_PACK_DIR}
    #cp ${IMAGES_DIR}/u-boot.bin bootfs/linux/
    
    busybox unix2dos sys_config.fex
    busybox unix2dos sys_partition.fex
    script sys_config.fex
    script sys_partition.fex
    
    cp sys_config.bin bootfs/script.bin
    update_mbr sys_partition.bin 4
    
    update_boot0 boot0_nand.bin   sys_config.bin NAND
    update_boot0 boot0_sdcard.fex sys_config.bin SDMMC_CARD
    update_boot1 boot1_nand.fex   sys_config.bin NAND
    update_boot1 boot1_sdcard.fex sys_config.bin SDMMC_CARD

    fsbuild bootfs.ini split_xxxx.fex
    mv bootfs.fex bootloader.fex

    u_boot_env_gen env.cfg env.fex
    
    ln -s ${BOOT_IMAGE} boot.fex
    ln -s ${ROOTFS_IMAGE} rootfs.fex

    dragon image.cfg sys_partition.fex
    cd ..
    )
}

do_prepare
do_pack_cb
