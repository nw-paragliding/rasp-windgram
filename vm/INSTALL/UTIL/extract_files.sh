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

function extract_file {

	print_default "Extracting $1"
	
	if [ ! -f $1 ]
	then
		print_error "File $1 does not exist"
		exit -1
	fi

	if ! (tar xvzf $1 -C $BASEDIR)
	then
		print_error "Extracting $1 failed"
		exit -1
	fi
}

extract_file $SOURCE_DIR/RASP.tgz
extract_file $SOURCE_DIR/UTIL.tgz
extract_file $SOURCE_DIR/WRF.tgz
extract_file $SOURCE_DIR/WXTOFLY.tgz

print_default "All files extracted"