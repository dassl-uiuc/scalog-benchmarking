#!/bin/bash

disk="sda4"
# mount /dev/sda4 and create fs
sudo mkfs.ext4 /dev/sda4
mkdir -p ~/scalog-storage
if sudo grep -qs "/dev/$disk" /proc/mounts; then
    sudo umount /dev/$disk
fi
sudo mkfs.ext4 /dev/$disk
sudo mount /dev/$disk ~/scalog-storage
sudo chown JiyuHu23 ~/scalog-storage
rm -rf ~/scalog-storage/*

# sudo umount /dev/$disk