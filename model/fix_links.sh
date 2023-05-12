#!/bin/bash

if [ -z $1 ]
then
	echo "BASEDIR argument not specified"
	exit -1
fi
BASEDIR=${1%/}

for l in $(find $BASEDIR/WRF/WRFV2 -type l); 
do 
	target=$(readlink $l)

	if [[ $target == "$BASEDIR"* ]]
	then
		echo $l
		echo "--> $target"
		newtarget=${target/$BASEDIR\/WRF\/WRFV2\/RASP/..}
		echo "--> $newtarget"
		ln -sf "$newtarget" "$l"
	fi
done

CD=$(pwd)
for l in $(find $BASEDIR/WRF/wrfsi -type l); 
do 
	target=$(readlink $l)

	if [[ $target == "$BASEDIR"* ]]
	then
		echo $l
		echo "--> $target"
		newtarget=${target/$BASEDIR\/WRF\/wrfsi\/domains/..\/..}
		echo "--> $newtarget"
		cd $(dirname $l)
		ln -sf "$newtarget" "$(basename $l)"
		cd $CD
	fi
done

for l in $(find $BASEDIR -type l); 
do 
	target=$(readlink $l)
	cd $(dirname $l)
	if [ ! -e $target ]
	then
		echo "***Broken link $l"
		echo "--> $target"
	fi
	cd $CD

	if [[ $target == "$BASEDIR"* ]]
	then
		echo $l
		echo "--> $target"
	fi
done

