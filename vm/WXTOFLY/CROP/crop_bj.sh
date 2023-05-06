#!/bin/bash
#echo "USAGE: getcropgeneric REGION  DOMAIN  FOCUS PARAM  [WIDTH] [HEIGHT] [xoffset] [yoffset] [STARTLEVEL] [LOWESTLEVEL] "
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="PNW"
DOMAIN="w2"
FOCUS="bj"
PARAM="press"

WIDTH=365
HEIGHT=356

x=500
y=180

STARTLEVEL=700
LOWESTLEVEL=990

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}
