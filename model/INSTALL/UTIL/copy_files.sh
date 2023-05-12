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

#copy files to $BASEDIR
if ! (rsync -rv $SOURCE_DIR"/" $BASEDIR"/" );
then
	echo "Unable to copy files"
	exit -1
fi

echo "Extracting symbolic links"
if [ ! -e $BASEDIR/all_links.tgz ]
then
	echo "$BASEDIR/all_links.tgz does not exist"
	exit -1
fi
tar xvzf $SOURCE_DIR/all_links.tgz -C $BASEDIR
