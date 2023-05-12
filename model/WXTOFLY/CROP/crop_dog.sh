#!/bin/bash
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="PNW"
DOMAIN="d2"
FOCUS="dog"
PARAM="press"

WIDTH=310
HEIGHT=310

x=300
y=800

STARTLEVEL=850
LOWESTLEVEL=940

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}
