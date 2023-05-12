#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN] BASEDIR variable not defined"
	exit
fi
echo "[RUN] BASEDIR: $BASEDIR"

if [ ! -f $BASEDIR/WXTOFLY/wxtofly.env ]; then
	echo "****Error: [RUN] $BASEDIR/WXTOFLY/wxtofly.env not found"
	exit
fi
source $BASEDIR/WXTOFLY/wxtofly.env

#Delete old folders before timestamp is added
LOG_RETENTION=3
if [ -d $WXTOFLY_LOG ]; then
	echo "[CLEANUP] Removing logs older then $LOG_RETENTION days"
	for ITEM in $(find $WXTOFLY_LOG/* -ctime +${LOG_RETENTION})
	do
		rm -rf $ITEM
	done
fi

UPLOAD_RETENTION=3
if [ -d $WXTOFLY_UPLOAD_ROOT ]; then
	echo "[CLEANUP] Removing upload folders older then $UPLOAD_RETENTION days"
	for ITEM in $(find $WXTOFLY_UPLOAD_ROOT/* -ctime +${UPLOAD_RETENTION})
	do
		rm -rf $ITEM
	done
fi

#Add timestamp to log and upload locations
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
export WXTOFLY_LOG="${WXTOFLY_LOG}/${TIMESTAMP}"
if [ ! -d $WXTOFLY_LOG ]; then
	mkdir $WXTOFLY_LOG
fi
export WXTOFLY_UPLOAD_ROOT="${WXTOFLY_UPLOAD_ROOT}/${TIMESTAMP}"
if [ ! -d $WXTOFLY_UPLOAD_ROOT ]; then
	mkdir $WXTOFLY_UPLOAD_ROOT
fi

#Perform run
LOGFILE=$WXTOFLY_LOG"/wxtofly.out"
echo "[RUN] LOGFILE: $LOGFILE"
echo "[RUN] UPLOAD ROOT: $WXTOFLY_UPLOAD_ROOT"
echo "[RUN] Running $RUNSCRIPT" &>$LOGFILE
echo "[RUN] Start Time: "$(date +"%x %X") &>>$LOGFILE
$WXTOFLY_RUN/run_wxtofly.sh $@ &>>$LOGFILE
echo "[RUN] End Time: "$(date +"%x %X") &>>$LOGFILE
echo "[RUN] Duration: "$($WXTOFLY_UTIL/print_duration.sh $SECONDS) &>>$LOGFILE
	