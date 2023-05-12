#!/bin/bash
RUNSCRIPT=$1
shift
LOGFILE=$1
shift

##this indicates to other processes a background tasks are in progress
echo "$$" >$WXTOFLY_LOG/.background_task_flag

echo "[BACKGROUD-TASK] Start Time: "$(date +"%x %X") &>>$LOGFILE
bash $RUNSCRIPT $@ &>>$LOGFILE
echo "[BACKGROUD-TASK] End Time: "$(date +"%x %X") &>>$LOGFILE
echo "[BACKGROUD-TASK] Duration: "$($WXTOFLY_UTIL/print_duration.sh $SECONDS) &>>$LOGFILE

rm -f $WXTOFLY_LOG/.background_task_flag
