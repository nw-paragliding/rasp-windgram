#!/bin/bash
#echo "USAGE: getcropgeneric REGION  DOMAIN  FOCUS PARAM  [WIDTH] [HEIGHT] [xoffset] [yoffset] [STARTLEVEL] [LOWESTLEVEL] "
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="FRASER"
DOMAIN="w2"
FOCUS="bridal"
PARAM="press"

WIDTH=400
HEIGHT=400

x=550
y=330

STARTLEVEL=850
LOWESTLEVEL=1000

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}
