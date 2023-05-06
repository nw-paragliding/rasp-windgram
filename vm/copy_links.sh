#!/bin/bash

if [ -z $1 ]
then
	echo "BASEDIR argument not specified"
	exit -1
fi
BASEDIR=${1%/}
echo "BASEDIR=$BASEDIR"
if [ ! -d $BASEDIR ];
then
	echo "$BASEDIR does not exist"
	exit -1
fi

LINKS_DIR=$BASEDIR/LINKS

for l in $(find $BASEDIR -type l)
do

	echo $l

	DIR=$(dirname $l)
	DIR=${DIR/$BASEDIR/$LINKS_DIR}
	
	mkdir -p $DIR

	cp -pd $l $DIR/$(basename $l)

done

CD=$(pwd)
cd $LINKS_DIR
tar cvzf $BASEDIR/all_links.tgz RASP UTIL WRF
cd $CD
