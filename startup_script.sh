#!/bin/bash
yum -y install gdisk mdadm
sgdisk -n 1:2048:+500M /dev/nvme0n1
for i in {2..6} ; do sgdisk -R /dev/nvme0n${i} /dev/nvme0n1; done
for i in {1..6} ; do sgdisk -G /dev/nvme0n${i}; done
lsblk
export DEVICE_NVME_LIST
for i in {1..6} ; do export DEVICE_NVME_LIST="$DEVICE_NVME_LIST /dev/nvme0n${i}"; done
mdadm --create /dev/md/raid10_nvme --run --level=10 --raid-devices=6 $DEVICE_NVME_LIST
mdadm --detail /dev/md/raid10_nvme
# autoboot
mkdir -p /etc/mdadm
mdadm --detail --scan > /etc/mdadm/mdadm.conf
