#!/bin/bash

ROOTFS_TARBALL=$1
OUTPUT_IMAGE=$2
OUTPUT_DIR=`dirname $2`
ROOTFS_ADDON_DIR=$3
TARGET_TMP_DIR=${OUTPUT_DIR}/_tmp_dsfjk321_target

make_rootfs()
{
    echo "Make rootfs"
    local rootfs=$(readlink -f "$1")
    local output=$(readlink -f "$2")
    local fsizeinbytes=$(gzip -lq "$rootfs" | awk -F" " '{print $2}')
    local fsizeMB=$(expr $fsizeinbytes / 1024 / 1024 + 250)
    local target=${TARGET_TMP_DIR}

    echo "Make linux.ext4 (size="$fsizeMB")"
    mkdir -p $target
    rm -f ${output}
    dd if=/dev/zero of=${output} bs=1M count="$fsizeMB"
    mkfs.ext4 -F ${output}
    sudo mount ${output} $target -o loop

    cd $target
    echo "Unpacking $rootfs"
    sudo tar xzf $rootfs
    if [ -d ./etc ]; then
        echo "Standard rootfs"
	(cd ${ROOTFS_ADDON_DIR}/; tar -c *) |sudo tar -xv
        # do nothing
    elif [ -d ./binary/boot/filesystem.dir ]; then
        echo "Linaro rootfs"
        sudo mv ./binary/* .
        sudo rm -rf ./binary
	(cd ${ROOTFS_ADDON_DIR}/; tar -c *) |sudo tar -xv
    else
        die "Unsupported rootfs"
    fi
    cd - > /dev/null

    sudo umount $target
    sudo sudo rm -rf $target
}

make_rootfs $1 $2
