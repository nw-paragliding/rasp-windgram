#!/bin/bash
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error:  BASEDIR variable not defined"
	exit
fi

REGION="TIGER"
DOMAIN="w2"
FOCUS="tiger"
PARAM="press"

WIDTH=365
HEIGHT=356

x=380
y=500

STARTLEVEL=850
LOWESTLEVEL=990

$WXTOFLY_CROP/crop.sh ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${x} ${y} ${STARTLEVEL} ${LOWESTLEVEL}
