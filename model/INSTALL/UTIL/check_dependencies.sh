#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

install=false
if [ "$1" == "install" ]; then 
	install=true
fi

source /etc/os-release
OS=${ID,,}
echo "Detected OS: $OS"

if [ $OS != "ubuntu" ] && [ $install == "true" ]; 
then
	print_error "OS not supported"
	exit -1
fi

which perl
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "Perl is installed"
else
	print_red "Perl not installed"
	if [ $install = true ]; then
		echo "Installing Perl ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y perl
		elif [ $OS == "fedora" ]; then
			sudo yum install -y perl
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

which curl
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "curl is installed"
else
	print_red "curl not installed"
	if [ $install = true ]; then
		echo "Installing curl ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y curl
		elif [ $OS == "fedora" ]; then
			sudo yum install -y curl
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

which cpan
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "cpan is installed"
else
	print_red "cpan not installed"
	if [ $install = true ]; then
		echo "Installing curl ..."
		if [ $OS == "fedora" ]; then
			sudo yum install -y perl-CPAN
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

which zip
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "zip is installed"
else
	print_red "zip not installed"
	if [ $install = true ]; then
		echo "Installing zip ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y zip
		elif [ $OS == "fedora" ]; then
			sudo yum install -y zip
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

which gzip
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "gzip is installed"
else
	print_red "gzip not installed"
	if [ $install = true ]; then
		echo "Installing gzip ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y gzip
		elif [ $OS == "fedora" ]; then
			sudo yum install -y gzip
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

perl -e 'use Tk'
haveTk=$?
if [[ $haveTk -eq 0  ]] 
then
	print_ok "Tk is installed" 
else
	print_red "Tk is not installed" 
	if [ $install = true ]; then
		echo "Installing Tk ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y perl-tk
		elif [ $OS == "fedora" ]; then
			sudo yum install perl-Tk
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

perl -e 'use Proc::Background'
haveprbkg=$?
if [[ $haveprbkg -eq 0  ]]; then
	print_ok "libproc-background-perl is installed"
else
	print_red "libproc-background-perl is not installed" 
	if [ $install = true ]; then
		echo "Installing libproc-background-perl ..."
		
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y libproc-background-perl
		elif [ $OS == "fedora" ]; then
			sudo cpan Proc::Background
		else
			echo "Don't know how to install on $OS"
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

which convert
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "convert is installed"
else
	print_red "convert not installed"
	if [ $install = true ]; then
		echo "Installing imagemagick ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y imagemagick 
		fi
		if [ $OS == "fedora" ]; then
			sudo yum install -y ImageMagick 
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

which ncdump
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "netcdf is installed"
else
	print_red "netcdf not installed"
	if [ $install = true ]; then
		echo "Installing netcdf ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y netcdf-bin 
		fi
		if [ $OS == "fedora" ]; then
			sudo yum install -y netcdf 
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

#Used in scripts
which realpath
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "realpath is installed"
else
	print_red "realpath not installed"
	if [ $install = true ]; then
		echo "Installing realpath ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y realpath
		fi
		if [ $OS == "fedora" ]; then
			sudo yum install -y realpath 
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

#CRON service - for scheduling runs
which cron
have=$?
if [[ $have -eq 0  ]]; then
	print_ok "cron is installed"
else
	print_red "cron not installed"
	if [ $install = true ]; then
		echo "Installing cron ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y cron
		fi
		if [ $OS == "fedora" ]; then
			sudo yum install -y cron 
		fi
		if [[ $? != 0  ]]; then
			print_error "Install failed"
			exit -1
		fi
	fi
fi

#Check CRON is running
if (( $(ps -ef | grep -v grep | grep cron | wc -l) > 0 ))
then
	print_ok "cron service is running"
else
	print_red "cron service is not running "
	sudo service cron start
fi
