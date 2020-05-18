#!/bin/bash

#The purpose of this script is to bind all non-boot GPUs to the vfio driver in PopOS 20.04

CPU=$(lscpu | grep GenuineIntel | rev | cut -d ' ' -f 1 | rev )

INTEL="0"

if [ "$CPU" = "GenuineIntel" ]
	then
	INTEL="1"
fi

echo "Please wait"

IDS="vfio-pci.ids=\""
BOOTGPU=""

#Identify a boot GPU

for i in $(find /sys/devices/pci* -name boot_vga); do

if [ $(cat $i) -eq 1 ]; then
BOOTGPU_PART=`lspci -n | grep $(echo $i | rev | cut -d '/' -f 2 | rev | cut -d ':' -f2,3,4)`
BOOTGPU=$(echo $BOOTGPU_PART | cut -d ' ' -f 3)

fi
done

#Identify any non-boot GPUs

for i in $(find /sys/devices/pci* -name boot_vga); do


if [ $(cat $i) -eq 0 ]; then
GPU=`echo $(dirname $i) | cut -d '/' -f6 | cut -d ':' -f 2,3,4 `
GPU_ID=$(echo `lspci -n | grep $GPU | cut -d ':' -f 3,4 | cut -d ' ' -f 2`)

#If a boot GPU has the same id as a non-boot GPU, then terminate 

if [ $GPU_ID = $BOOTGPU ]

	then
		printf "ERROR! \nYour boot/primary GPU has the same id as one of the GPUs you are trying to bind to vfio-pci!\n"
		exit 1

fi

#Identify the audio function of detected GPUs

AUDIO=$(echo $GPU | sed -e "s/0$/1/")

#Build a string that will be passed to kernelstub

IDS+=$(echo $GPU_ID)
IDS+=","
IDS+=$(echo `lspci -n | grep $AUDIO | cut -d ':' -f 3,4 | cut -d ' ' -f 2`)

#Add commas to separate the ids

IDS+=","
fi

done

#A lazy way of removing any commas that remain at the end of the string

IDS=$(echo "$IDS" | sed 's/,,$//')
IDS=$(echo "$IDS" | sed 's/,$//')
IDS+="\""

#Back up old kernel options

OLD_OPTIONS=`cat /boot/efi/loader/entries/Pop_OS-current.conf | grep options | cut -d ' ' -f 4-`

#Execute kernelstub resulting in GRUB being updated with vfio-pci.ids="..."

if [ $INTEL = 1 ]
	then
	kernelstub --add-options intel_iommu=on
	else
	kernelstub --add-options amd_iommu=on
fi

kernelstub --add-options $IDS

apt install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager ovmf

#Create an uninstall script

echo "kernelstub -o \"$OLD_OPTIONS\"" > uninstall.sh
chmod +x uninstall.sh


clear
echo "Success! Non-primary GPUs were bound to vfio-pci. Please reboot your computer!"
