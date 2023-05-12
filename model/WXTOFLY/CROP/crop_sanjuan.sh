#!/bin/bash
#echo "USAGE: getcropgeneric REGION  DOMAIN  FOCUS PARAM  [WIDTH] [HEIGHT] [xoffset] [yoffset] [STARTLEVEL] [LOWESTLEVEL] "
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="PNW"
DOMAIN="d2"
FOCUS="sanjuan"
PARAM="press"

WIDTH=320
HEIGHT=345

x=224
y=345

STARTLEVEL=990
LOWESTLEVEL=1000

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}