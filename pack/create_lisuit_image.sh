#!/bin/bash

ROOT_DIR=${PWD}
TOOLS_DIR=${ROOT_DIR}/pctools/linux
OUT_DIR=${ROOT_DIR}/out
IMAGES_DIR=${PWD}/images

export PATH=${TOOLS_DIR}/mod_update:${TOOLS_DIR}/eDragonEx:${TOOLS_DIR}/fsbuild200:${TOOLS_DIR}/android:$PATH 

function do_prepare()
{
    [ -d ${OUT_DIR} ] && rm -rf ${OUT_DIR}
    mkdir ${OUT_DIR}

    cp -r chips/sun7i/eFex ${OUT_DIR}
    cp -r chips/sun7i/eGon ${OUT_DIR}
    cp -r chips/sun7i/wboot ${OUT_DIR}
}

function do_parse()
{
    [ -f out/sys_partition.fex ] && script_parse -f out/sys_partition.fex
    [ -f out/sys_config.fex ] && script_parse -f out/sys_config.fex
}

function do_pack_cb()
{
    echo "Start Generating image for cb"
    cp -f chips/sun7i/configs/linux/default/* out/
    cp -f chips/sun7i/configs/linux/cubieboard/*.fex out/
    cp -f chips/sun7i/configs/linux/cubieboard/*.cfg out/ 2>/dev/null
    
    do_parse

    cp -rf ${OUT_DIR}/eFex/split_xxxx.fex ${OUT_DIR}/wboot/bootfs ${OUT_DIR}/wboot/bootfs.ini ${OUT_DIR}
    cp -f ${OUT_DIR}/eGon/boot0_nand.bin   ${OUT_DIR}/boot0_nand.bin
    cp -f ${OUT_DIR}/eGon/boot1_nand.bin   ${OUT_DIR}/boot1_nand.fex
    cp -f ${OUT_DIR}/eGon/boot0_sdcard.bin ${OUT_DIR}/boot0_sdcard.fex
    cp -f ${OUT_DIR}/eGon/boot1_sdcard.bin ${OUT_DIR}/boot1_sdcard.fex

    (
    cd ${OUT_DIR}
    cp ${IMAGES_DIR}/u-boot.bin bootfs/linux/
    
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
    
    ln -s ${IMAGES_DIR}/boot.img boot.fex
    ln -s ${IMAGES_DIR}/rootfs.ext4 rootfs.fex

    dragon image.cfg sys_partition.fex
    cd ..
    )
}

do_prepare
do_pack_cb
