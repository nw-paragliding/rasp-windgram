#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN] BASEDIR variable not defined"
	exit
fi

USEDPCENT=$(df -l --output=pcent $BASEDIR | grep -vE '^Use')
USED=${USEDPCENT/\%/}

if [ $USED -ge 75 ]; then
	$WXTOFLY_RUN/run_update_status.sh WARNING "Disk is $USEDPCENT full"
	echo "[RUN-DISK-CHECK] ****Warning: Disk is $USEDPCENT full."
elif [ $USED -ge 90 ]; then
	$WXTOFLY_RUN/run_update_status.sh ERROR "Disk is $USEDPCENT full. RASP runs will not start"
	echo "****Error: [RUN-DISK-CHECK] Disk is $USEDPCENT full. RASP runs will not start"
	exit -1
else
	echo "[RUN-DISK-CHECK] Current disk usage is $USEDPCENT"
fi
