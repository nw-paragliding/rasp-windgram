#!/bin/bash

[ -z $1 ] && echo "No mount point specified" && exit 1
MOUNTPOINT=$1
echo "MOUNTPOINT: $MOUNTPOINT"

[ -z $2 ] && echo "No server specified" && exit 1
SERVER=$2

[ -z $3 ] && echo "No share specified" && exit 1
SHARE=$3
echo "SHARE: $SHARE"

if [ ! -z $4 ]; then
	USERNAME=$4
fi

[ ! -z $USERNAME ] && [ -z $5 ] && echo "Password not specified" && exit 1
PASSWORD=$5

if ! dpkg -s cifs-utils &>/dev/null ; then
	echo "Installing cifs-utils package"
	sudo apt-get install cifs-utils
fi

if [ ! -d $MOUNTPOINT ]; then
	echo "Creating mount point"
	if ! sudo mkdir $MOUNTPOINT ; then
		echo "Unable to create mount point"
	fi
fi

FSOPTIONS="guest,uid=1000,iocharset=utf8"
if [ ! -z $USERNAME ]; then
	echo "username=$USERNAME" >$HOME/.smbcredentials
	echo "password=$PASSWORD" >> $HOME/.smbcredentials
	chmod 600 $HOME/.smbcredentials
	FSOPTIONS="$HOME/.smbcredentials,iocharset=utf8,sec=ntlm"
fi

echo "echo \"\" >>/etc/fstab" | sudo bash
echo "echo \"\\\\\\\\$SERVER\\\\$SHARE $MOUNTPOINT cifs $FSOPTIONS 0 0\" >>/etc/fstab" | sudo bash

if sudo mount -a ; then
	echo "Setup complete"
	
	while true; do
		read -p "Restart required. Restart now (y/n)?" yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit;;
			* ) echo "Hit 'y' or 'n'";;
		esac
	done
else
	echo "Setup failed"
fi

