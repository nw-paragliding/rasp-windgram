#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

if [ -z $1 ]
then
	print_error "Install utility not specified"
	exit -1
fi
UTIL=$1
UTIL_SRCIPT=$(dirname $0)"/"${UTIL}".sh"
shift

if [ ! -e $UTIL_SRCIPT ]
then
	print_error "Install utility $UTIL_SRCIPT not found"
	exit -1
fi

#crete installation log dir
INSTALL_LOG_DIR=$BASEDIR/INSTALL/LOG
if [ ! -d $INSTALL_LOG_DIR ]
then
	mkdir -p $INSTALL_LOG_DIR
fi

SCRIPT_STAMP=$INSTALL_LOG_DIR/$UTIL
if [ $UTIL == "fix_basedir" ] || [ ! -e $SCRIPT_STAMP ]
then
	print_blue "Running $UTIL.sh"
	if ! (bash $UTIL_SRCIPT $@);
	then
		print_error "Running $UTIL.sh failed"
		exit -1
	fi
	print_blue "Done"
	echo ""
	touch $SCRIPT_STAMP
fi
