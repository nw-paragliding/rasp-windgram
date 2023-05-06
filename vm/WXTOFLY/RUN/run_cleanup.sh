#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [CLEANUP] BASEDIR variable not defined"
	exit
fi

if [ -z $1 ]; then
	echo "****Error: [CLEANUP] INIT variable not defined"
	exit
fi
INIT=$1

echo "[CLEANUP] Start run cleanup"

INITHR=$(printf "%02d" $INIT)
echo "[CLEANUP] Removing $BASEDIR/RASP/RUN/ETA/GRIB/nam.t${INITHR}z*"
rm -f $BASEDIR/RASP/RUN/ETA/GRIB/nam.t${INITHR}z*

echo "[CLEANUP] Removing files from $BASEDIR/RASP/RUN/OUT"
find $BASEDIR/RASP/RUN/OUT -type f -delete

echo "[CLEANUP] Removing files from $BASEDIR/RASP/HTML"
find $BASEDIR/RASP/HTML -type f -delete
#find $BASEDIR/WRF/WRFV2/RASP -type f -name "*wrfout*" -delete

echo "[CLEANUP] Finished run cleanup"
