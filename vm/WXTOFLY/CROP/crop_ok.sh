#!/bin/bash
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="PNW"
DOMAIN="d2"
FOCUS="ok"
PARAM="press"

WIDTH=410
HEIGHT=500

x=570
y=115

STARTLEVEL=500
LOWESTLEVEL=850

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}
