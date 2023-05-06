#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN-PNW-w2] BASEDIR variable not defined"
	exit -1
fi

if [ -z $1 ]; then
	echo "****Error: [RUN-PNW-w2] INIT argument not specified"
	exit -1
fi
INIT=$1
echo "[RUN-PNW-w2] INITIALIZATION: $INIT"
shift

if [ -z $1 ]; then
	echo "****Error: [RUN-PNW-w2] current+N argument not specified"
	exit
fi
N=$1
if [ $N == 0 ]
then
	N=""
	echo "[RUN-PNW-w2] Forecast day: current"
else
	N="+$N"
	echo "[RUN-PNW-w2] Forecast day: $N"
fi
shift

#Nested window RASP run for FT_EBEY
if $WXTOFLY_RUN/run_rasp_nested.sh "PNW${N}" "FT_EBEY${N}" "$WXTOFLY_RUN/PARAMETERS/rasp.run.parameters.FT_EBEY${N}.${INIT}z" ; 
then
	$WXTOFLY_RUN/run_background_task.sh $WXTOFLY_RUN/run_tasks_w2.sh "FT_EBEY${N}"
else
	echo "****Error: [RUN-PNW-w2] Rasp run failed"
	$WXTOFLY_RUN/run_update_status.sh ERROR "Rasp run failed"
fi
