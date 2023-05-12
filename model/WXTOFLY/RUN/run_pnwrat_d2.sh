#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN-PNWRAT-d2] BASEDIR variable not defined"
	exit -1
fi

if [ -z $1 ]; then
	echo "****Error: [RUN-PNWRAT-d2] INIT argument not specified"
	exit -1
fi
INIT=$1
echo "[RUN-PNWRAT-d2] INITIALIZATION: $INIT"
shift

if [ -z $1 ]; then
	echo "****Error: [RUN-PNWRAT-d2] current+N argument not specified"
	exit
fi
N=$1
if [ $N == 0 ]
then
	N=""
	echo "[RUN-PNWRAT-d2] Forecast day: current"
else
	N="+$N"
	echo "[RUN-PNWRAT-d2] Forecast day: $N"
fi
shift

if $WXTOFLY_RUN/run_rasp.sh "PNWRAT${N}" "$WXTOFLY_RUN/PARAMETERS/rasp.run.parameters.PNWRAT${N}.${INIT}z" ; 
then
	$WXTOFLY_RUN/run_background_task.sh $WXTOFLY_RUN/run_tasks_d2.sh "PNWRAT${N}"
else
	echo "****Error: [RUN-PNWRAT-d2] Rasp run failed"
	$WXTOFLY_RUN/run_update_status.sh ERROR "Rasp run failed"
	exit
fi
