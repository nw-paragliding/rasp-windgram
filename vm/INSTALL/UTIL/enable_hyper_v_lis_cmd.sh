#!/bin/bash

if ! grep -q "hv_vmbus" "/etc/initramfs-tools/modules"; then
	while true; do
		read -p "Enable Hyper-V modules (y/n)?" yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit;;
			* ) echo "Hit 'y' or 'n'";;
		esac
	done
	
	sudo echo "" >> /etc/initramfs-tools/modules
	sudo echo "hv_vmbus" >> /etc/initramfs-tools/modules
	sudo echo "hv_storvsc" >> /etc/initramfs-tools/modules
	sudo echo "hv_blkvsc" >> /etc/initramfs-tools/modules
	sudo echo "hv_netvsc" >> /etc/initramfs-tools/modules

	sudo update-initramfs -u
	
	sudo apt install linux-cloud-tools-virtual -y

	while true; do
		read -p "Restart required. Restart now (y/n)?" yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit;;
			* ) echo "Hit 'y' or 'n'";;
		esac
	done
	
	sudo shutdown -r now

else
	echo "Hyper-V modules already enabled"
	lsmod | grep hv
fi
