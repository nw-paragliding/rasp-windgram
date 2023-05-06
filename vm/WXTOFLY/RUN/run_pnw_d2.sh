#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN-PNW-d2] BASEDIR variable not defined"
	exit -1
fi

if [ -z $1 ]; then
	echo "****Error: [RUN-PNW-d2] INIT argument not specified"
	exit -1
fi
INIT=$1
echo "[RUN-PNW-d2] INITIALIZATION: $INIT"
shift

if [ -z $1 ]; then
	echo "****Error: [RUN-PNW-d2] current+N argument not specified"
	exit
fi
N=$1
if [ $N == 0 ]
then
	N=""
	echo "[RUN-PNW-d2] Forecast day: current"
else
	N="+$N"
	echo "[RUN-PNW-d2] Forecast day: $N"
fi
shift

#do coarse non-window run for PNW
if ! $WXTOFLY_RUN/run_rasp.sh "PNW${N}" "$WXTOFLY_RUN/PARAMETERS/rasp.run.parameters.PNW${N}.${INIT}z.0" ; then
	echo "****Error: [RUN-PNW-d2] Rasp run failed"
	$WXTOFLY_RUN/run_update_status.sh ERROR "Rasp run failed"
	exit -1
fi

$WXTOFLY_RUN/run_background_task.sh $WXTOFLY_RUN/run_tasks_d2.sh "PNW${N}"
