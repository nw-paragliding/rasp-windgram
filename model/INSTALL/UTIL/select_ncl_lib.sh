#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

MODE="AUTO"

if [ -z $1 ];
then
	MODE="AUTO"
else
	MODE=$1
fi

MODE=${MODE^^}

print_cyan "Selecting NCL libs"
print_default "MODE: $MODE"

NCL_DIR=$BASEDIR/WRF/NCL
if [ ! -d "$NCL_DIR" ]
then
	print_error "$NCL_DIR not found"
	exit -1
fi

NCL_LIB_DIR="$NCL_DIR/LIB"
if [ ! -d "$NCL_LIB_DIR" ]
then
	print_error "$NCL_LIB_DIR not found"
	exit -1
fi

if ! (rm -f $NCL_DIR/ncl_jack_fortran.so $NCL_DIR/wrf_user_fortran_util_0.so)
then
	print_error "Unable to delete old libs"
	exit -1
fi

function create_link_ncl_jack {
	if [ ! -f "$NCL_LIB_DIR/$1" ]
	then
		print_error "Lib $NCL_LIB_DIR/$1 does not exist"
		exit -1
	fi
	
	print_default "ncl_jack_fortran.so --> $1"
	
	if ! (ln -sf "LIB/$1" "$NCL_DIR/ncl_jack_fortran.so")
	then
		print_error "Unable to create link to $1"
		exit -1
	fi
}
function create_link_wrf_user {
	if [ ! -f "$NCL_LIB_DIR/$1" ]
	then
		print_error "Lib $NCL_LIB_DIR/$1 does not exist"
		exit -1
	fi
	
	print_default "wrf_user_fortran_util_0.so --> $1"

	if ! (ln -sf "LIB/$1" "$NCL_DIR/wrf_user_fortran_util_0.so")
	then
		print_error "Unable to create link to $1"
		exit -1
	fi
}

case "$MODE" in

	AUTO)
	create_link_ncl_jack "ncl_jack_fortran.so"
	create_link_wrf_user "wrf_user_fortran_util_0-64bit.so"
	;;
	
	*)
	print_error "Invalid MODE value: $MODE"
	exit -1
	;;
	
esac
