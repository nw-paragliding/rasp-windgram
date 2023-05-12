#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [BACKGROUD-TASK] BASEDIR variable not defined"
	exit
fi
if [ -z $1 ]; then
	echo "****Error: [BACKGROUD-TASK] RUNSCRIPT not defined"
	exit
fi
if [ ! -f $1 ]; then
	echo "****Error: [BACKGROUD-TASK] RUNSCRIPT $1 not found"
	exit
fi
RUNSCRIPT=$(realpath $1)
echo "[BACKGROUD-TASK] RUNSCRIPT: $RUNSCRIPT"

#remove the script name from arguments
shift

if [ -z $1 ]; then
	echo "****Error: [BACKGROUD-TASK] REGION not specified"
	exit
fi
REGION=$1
echo "[BACKGROUD-TASK] REGION: $REGION"

LOGFILE=$(basename $RUNSCRIPT)
LOGFILE=$WXTOFLY_LOG"/"${LOGFILE%.*}"."$REGION
COUNTER=0
while [ -e $LOGFILE"."$COUNTER".out" ]; do
	 let COUNTER+=1 
done
LOGFILE=$LOGFILE"."$COUNTER".out"

echo "[BACKGROUD-TASK] LOGFILE: $LOGFILE"

echo "[BACKGROUD-TASK] Starting background task $TASKNAME ("$(basename $RUNSCRIPT)")"
echo "[BACKGROUD-TASK] Starting background task $TASKNAME ("$(basename $RUNSCRIPT)")" &>$LOGFILE

$WXTOFLY_RUN/run_background_task_add_time.sh "$RUNSCRIPT" "$LOGFILE" $REGION &
