#!/bin/bash

# mount /dev/sda4 and create fs
# sudo mkfs.ext4 /dev/sda4
mkdir -p ~/scalog-storage
if sudo grep -qs "/dev/sda4" /proc/mounts; then
    sudo umount /dev/sda4
fi
sudo mount /dev/sda4 ~/scalog-storage
sudo rm -rf ~/scalog-storage/*
sudo chown JiyuHu23 ~/scalog-storage
rm -rf ~/scalog-storage/*