#!/bin/bash
SCRIPT_DIR=$(dirname $0)

INSTALL_UTIL_DIR=$SCRIPT_DIR/UTIL
if [ ! -d $INSTALL_UTIL_DIR ]
then
	echo "****Error: Install util dir $INSTALL_UTIL_DIR not found"
	exit -1
fi

source $INSTALL_UTIL_DIR/output_util.sh

if [ -z $1 ];
then
	print_error "BASEDIR argument not specified"
	exit -1
else
	export BASEDIR=${1%/}
fi
if [ ! -d $BASEDIR ];
then
	if ! (mkdir -p $BASEDIR);
	then
		print_error "Unable to create BASEDIR $BASEDIR"
		exit -1
	fi
fi

echo ""
print_yellow "Installing WXTOFLY"
print_default "------------------"
echo ""
print_default "BASEDIR=$BASEDIR"
echo ""

#copy files from remote location or extract from local TGZ files
if (df $SCRIPT_DIR | grep -q "/dev/");
then
	if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh extract_files "$SCRIPT_DIR/SOURCE" );
	then
		exit
	fi
else
	if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh copy_files "$SCRIPT_DIR/../" );
	then
		exit
	fi
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh copy_run_config);
then
	exit
fi

#enable 32-bit support needed by some old utilities
if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh enable_32_bit_support);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh check_dependencies install);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh gen_locale);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh create_rasp_env);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh config_access);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh fix_basedir $BASEDIR/WXTOFLY/wxtofly.env);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh install_ncl $SCRIPT_DIR/DOWNLOAD/NCL/ncl_ncarg-6.3.0.Linux_Debian7.8_x86_64_nodap_gcc472.tar.gz);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh copy_32_bit_libs $SCRIPT_DIR/LIB/i386);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh copy_ncl_libs $SCRIPT_DIR/LIB/NCL);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh config_ld);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh select_ncl_lib);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh create_util_links);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh create_symbolic_links);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh setup_domains);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh ubuntu_install_libs);
then
	exit
fi

if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh fix_basedir $BASEDIR/WRF/wrfsi);
then
	exit
fi

print_yellow  "Instalation check"
if ! (bash $INSTALL_UTIL_DIR/run_install_util.sh check_libs);
then
	print_error "Installation failed!"
	exit
else
	print_ok "Installation check OK!"
fi

echo ""
print_yellow  "Install configuration"
print_default "---------------------"
echo ""
bash $INSTALL_UTIL_DIR/create_cron_job.sh
echo ""
bash $INSTALL_UTIL_DIR/setup_upload.sh


echo ""
print_yellow  "Installation complete"
print_default "---------------------"
echo ""


