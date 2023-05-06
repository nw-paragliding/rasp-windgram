#!/bin/bash
## 12hrs=720min 18hr=1080m 24hr=1380m 6h=360m
## run from cron every 6 hours.
## delete any images, text, or data +18hrs old 
echo "[CLEANUP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error: [CLEANUP] BASEDIR variable not defined"
	exit
fi

find $BASEDIR/RASP/RUN -name "*printout*" -mmin +7200 -delete
find $BASEDIR/RASP/RUN -name "*stderr" -mmin +7200 -delete
find $BASEDIR/RASP/RUN/OUT  -wholename "*/OUT/*.*" -mmin +1800 -delete
find $BASEDIR/RASP/RUN/OUT  -wholename "*/OUT/*/previous*.*"  -delete

find $BASEDIR/RASP/HTML  -wholename "*/FCST/*.*" -mmin +1800 -delete
## delete any previous* files
find $BASEDIR/RASP/HTML  -wholename "*/FCST/previous*.*"  -delete

find $BASEDIR/WRF/  -name "previous*terp" -mmin +1800 -delete
find $BASEDIR/WRF/  -name "previous*wrf*out*" -mmin +1800 -delete

find $BASEDIR/RASP/RUN/ETA -name "*grib*" -mtime +2 -delete