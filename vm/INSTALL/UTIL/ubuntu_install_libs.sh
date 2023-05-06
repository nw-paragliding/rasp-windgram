#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

OS=$(lsb_release -si)
if [[ $OS != "Ubuntu" ]]; then
	print_error "This script supports Ubuntu only "
	exit -1
fi

function install_package {
	LIB=$1
	PACKAGE=$2
	if [[ ! -f $LIB ]]; then
		echo "Installing $PACKAGE ..."
		sudo apt-get install -y $PACKAGE
		if [[ $? != 0  ]]; then
			print_error "Error installing package"
			exit -1
		else
			print_ok "Package installed"
		fi
	fi
	if [[ ! -f $LIB ]]; then
		print_error "Lib $LIB not found. Invalid package"
		exit -1
	fi	
}

function install_package_i386 {
	LIB=$1
	PACKAGE=$2
	if [[ ! -f $LIB ]]; then
		echo "Installing $PACKAGE ..."
		sudo apt-get install -y $PACKAGE:i386
		if [[ $? != 0  ]]; then
			print_error "Error installing package"
			exit -1
		else
			print_ok "Package installed"
		fi
	fi
	
	if [[ ! -f $LIB ]]; then
		print_error "Lib $LIB not found. Invalid package"
		exit -1
	fi	
}

install_package_i386 "/lib/i386-linux-gnu/libz.so.1" "zlib1g"

source /etc/os-release

if [[ VERSION_ID == "14"* ]]
then
	install_package "/usr/lib/libiomp5.so" "libiomp-dev"
else
	install_package "/usr/lib/x86_64-linux-gnu/libiomp5.so" "libiomp-dev"
fi

#missing on default install of Server
install_package "/usr/lib/x86_64-linux-gnu/libXaw.so.7" "libxaw7"
install_package "/usr/lib/x86_64-linux-gnu/libXmu.so.6" "libxmu6"
install_package "/usr/lib/x86_64-linux-gnu/libXt.so.6" "libxt6"
install_package "/usr/lib/x86_64-linux-gnu/libSM.so.6" "libsm6"
install_package "/usr/lib/x86_64-linux-gnu/libICE.so.6" "libice6"