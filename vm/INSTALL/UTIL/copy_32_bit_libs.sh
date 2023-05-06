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

LIB_DIR="$BASEDIR/UTIL/LIB"

if [ ! -d "$LIB_DIR" ]
then
	if ! (mkdir -p $LIB_DIR)
	then
		print_error "Unable to create $LIB_DIR"
		exit -1
	fi
fi

#http://www.pgroup.com
echo "Copying 32-bit libs"
if ! (cp -f $BASEDIR/UTIL/PGI/libpgc.so $LIB_DIR) ;
then
	print_error "Unable to copy $BASEDIR/UTIL/PGI/libpgc.so"
	exit -1
fi

if ! (cp -f $BASEDIR/UTIL/PGI/libguide.so $LIB_DIR) ;
then
	print_error "Unable to copy $BASEDIR/UTIL/PGI/libguide.so"
	exit -1
fi

if ! (cp -f $SOURCE_DIR/libpng12.so.0 $LIB_DIR) ;
then
	print_error "Unable to copy $SOURCE_DIR/libpng12.so.0"
	exit -1
fi
