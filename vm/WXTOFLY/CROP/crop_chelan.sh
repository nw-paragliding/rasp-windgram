#!/bin/bash
#echo "USAGE: getcropgeneric REGION  DOMAIN  FOCUS PARAM  [WIDTH] [HEIGHT] [xoffset] [yoffset] [STARTLEVEL] [LOWESTLEVEL] "
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="PNW"
DOMAIN="d2"
FOCUS="chelan"
PARAM="press"

WIDTH=410
HEIGHT=710

x=570
y=400

STARTLEVEL=500
LOWESTLEVEL=890

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}
