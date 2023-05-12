#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

if [ -z "$1" ]
  then
    echo "NCL upgrade tar.gz not provided"
	exit -1
fi

if [ ! -f "$1" ]
  then
    echo "NCL upgrade tar.gz $2 does not exist"
	exit -1
fi
NCLTARGZ=$(realpath $1)
print_default "NCL tar.gz: $NCLTARGZ"

CURRENTDIR=$(pwd)

NCARG_ROOT=$BASEDIR/UTIL/NCARG
echo "Extracting $2 to NCARG_ROOT=$NCARG_ROOT"
#Extract new package

if (tar xvzf $NCLTARGZ -C $NCARG_ROOT)
then
	print_ok "$2 successfully extracted"
else
	print_error "Unable to extract files from $2"
	exit -1
fi
