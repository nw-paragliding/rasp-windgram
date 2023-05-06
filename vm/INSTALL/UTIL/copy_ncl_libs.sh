#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

if [ -z $1 ]
then
	print_error "SOURCE_DIR argument not specified"
	exit -1
fi
SOURCE_DIR=$1
if [ ! -d $SOURCE_DIR ];
then
	print_error "$SOURCE_DIR does not exist"
	exit -1
fi

LIB_DIR="$BASEDIR/WRF/NCL/LIB"
if [ ! -d "$LIB_DIR" ]
then
	if ! (mkdir -p $LIB_DIR)
	then
		print_error "Unable to create $LIB_DIR"
		exit -1
	fi
fi

if ! (ls $SOURCE_DIR/*.*)
then
	print_error "$SOURCE_DIR is empty"
	exit -1
fi

print_default "Copying NCL libraries"

if ! (cp -f $SOURCE_DIR/*.* $LIB_DIR/)
then
	print_error "Unable to copy NCL libs to $LIB_DIR"
	exit -1
fi

print_default "NCL libraries copied to $LIB_DIR"