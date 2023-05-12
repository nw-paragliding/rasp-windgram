#!/bin/bash
SECONDS=0
echo "[RASP] Start $0 $@"

if ! $WXTOFLY_RUN/run_check_disk.sh ; then
	echo "****Error: [RASP] Unable to start run"
	exit -1
fi

if [ -z $BASEDIR ]; then
	echo "****Error: [RASP] BASEDIR variable not defined"
	exit -1
fi

if [ -z $1 ]; then
	echo "****Error: [RASP] REGION variable not defined"
	exit -1
fi
REGION=$1
region=${REGION,,}
echo "[RASP-$REGION] REGION: $REGION"
shift

if [ -z $1 ]; then
	echo "****Error: [RASP-$REGION] Parameter file not specified"
	exit -1
fi
PARAMFILE=$1
if [ ! -f $PARAMFILE ]; then
	echo "****Error: [RASP-$REGION] Parameter file $PARAMFILE not found"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$REGION]: Unable to start run - parameter file not found"
	exit -1
fi
echo "[RASP-$REGION] PARAMFILE: $PARAMFILE"
shift

cp $PARAMFILE $BASEDIR/RASP/RUN/rasp.run.parameters.${REGION}
if [ $? != 0 ] ; then
	echo "****Error: [RASP-$REGION] Unable to copy parameter file"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$REGION]: Unable to start run"
	exit -1
fi

#update status before run
$WXTOFLY_RUN/run_update_status.sh OK "[RASP-$REGION]: Starting RASP run"

#run run.rasp from BASEDIR/RASP/RUN directory
CURRENTDIR=$(pwd)
cd $BASEDIR/RASP/RUN
RETCODE=0
echo "[RASP-$REGION] Running $BASEDIR/RASP/RUN/run.rasp $REGION $@"
$BASEDIR/RASP/RUN/run.rasp $REGION $@
RETCODE=$?
cd $CURRENTDIR

LOGFILENAME=$(basename $PARAMFILE)
LOGFILENAME=${LOGFILENAME/run.parameters./}
#check whether stderr is non-zero
#stderr is always created
if [ -s $BASEDIR/RASP/RUN/rasp.${region}.stderr ]; then 
	echo "****Error: [RASP-$REGION] Errors detected during rasp run"
	$WXTOFLY_RUN/run_update_status.sh WARNING "[RASP-$REGION]: Detected errors during RASP run"
	mv -f $BASEDIR/RASP/RUN/rasp.${region}.stderr $WXTOFLY_LOG/$LOGFILENAME.stderr
fi

#check run.rasp exit code 
if [ $RETCODE != 0 ] ; then
	echo "****Error: [RASP-$REGION] run.rasp exited with error code $RETCODE"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$REGION]: Run failed with non-ze exit code"
	exit -1
fi

#check if print out exists and is non-zero lenght
if [ ! -f $BASEDIR/RASP/RUN/rasp.${region}.printout ] || [ ! -s $BASEDIR/RASP/RUN/rasp.${region}.printout ]; then 
	echo "****Error: [RASP-$REGION] rasp."${region}".printout output not found"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$REGION]: Run failed - no output file generated"
	exit -1 
else
	mv -f $BASEDIR/RASP/RUN/rasp.${region}.printout $WXTOFLY_LOG/$LOGFILENAME.printout
fi

#check if printout indicates run failed
if grep -q "ERROR EXIT" "$WXTOFLY_LOG/$LOGFILENAME.printout" ; then
	echo "****Error: [RASP-$REGION] ERROR EXIT found in rasp."${region}".printout"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$REGION]: Run failed with ERROR EXIT"
	exit -1 
fi

#update status
echo "[RASP-$REGION] Duration: "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)
$WXTOFLY_RUN/run_update_status.sh OK "[RASP-$REGION]: Finished run in "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)