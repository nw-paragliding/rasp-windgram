#!/bin/bash
SECONDS=0

echo "[RASP-NESTED] Start $0 $@"

if ! $WXTOFLY_RUN/run_check_disk.sh ; then
	echo "****Error: [RASP-NESTED] Unable to start run"
	exit -1
fi

if [ -z $BASEDIR ]; then
	echo "****Error: [RASP-NESTED] BASEDIR variable not defined"
	exit -1
fi

if [ -z $1 ]; then
	echo "****Error: [RASP-NESTED] PARENTREGION variable not defined"
	exit -1
fi
PARENTREGION=$1
echo "[RASP-NESTED] PARENTREGION: $PARENTREGION"
shift

if [ -z $1 ]; then
	echo "****Error: [RASP-NESTED] REGION variable not defined"
	exit -1
fi
REGION=$1
region=${REGION,,}
echo "[RASP-NESTED] REGION: $REGION"
shift

if [ -z $1 ]; then
	echo "****Error: [RASP-$PARENTREGION.$REGION] Parameter file not specified"
	exit -1
fi
PARAMFILE=$1
if [ ! -f $PARAMFILE ]; then
	echo "****Error: [RASP-$PARENTREGION.$REGION] Parameter file $PARAMFILE not found"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$PARENTREGION.$REGION]: Unable to start run - parameter file not found"
	exit -1
fi
echo "[RASP-$PARENTREGION.$REGION] PARAMFILE: $PARAMFILE"
shift

cp $PARAMFILE $BASEDIR/RASP/RUN/rasp.run.parameters.${REGION}
if [ $? != 0 ] ; then
	echo "****Error: [RASP-$PARENTREGION.$REGION] Unable to copy parameter file"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$PARENTREGION.$REGION]: Unable to start run"
	exit -1
fi

#update status before run
$WXTOFLY_RUN/run_update_status.sh OK "[RASP-$PARENTREGION.$REGION]: Starting nested run"

#run run.rasp from BASEDIR/RASP/RUN directory
CURRENTDIR=$(pwd)
cd $BASEDIR/RASP/RUN
RETCODE=0
$BASEDIR/RASP/RUN/run.rasp2 $REGION -w $PARENTREGION
RETCODE=$?
cd $CURRENTDIR

LOGFILENAME=$(basename $PARAMFILE)
LOGFILENAME=${LOGFILENAME/rasp.run.parameters/rasp2}

#check whether stderr is non-zero
#stderr is always created
if [ -s $BASEDIR/RASP/RUN/rasp2.${region}.stderr ]; then 
	echo "****Error: [RASP-$PARENTREGION.$REGION] Errors detected during rasp run"
	$WXTOFLY_RUN/run_update_status.sh WARNING "[RASP-$PARENTREGION.$REGION]: Detected errors in nested RASP run"
	mv -f $BASEDIR/RASP/RUN/rasp2.${region}.stderr $WXTOFLY_LOG/$LOGFILENAME.stderr
fi

#check run.rasp exit code 
if [ $RETCODE != 0 ] ; then
	echo "****Error: [RASP-$PARENTREGION.$REGION] run.rasp2 exited with error code $RETCODE"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$PARENTREGION.$REGION]: Run failed with non-zero exit code"
	exit -1
fi

#check if print out exists and is non-zero lenght
if [ ! -f $BASEDIR/RASP/RUN/rasp2.${region}.printout ] || [ ! -s $BASEDIR/RASP/RUN/rasp2.${region}.printout ]; then 
	echo "****Error: [RASP-$PARENTREGION.$REGION] rasp2."${region}".printout output not found"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$PARENTREGION.$REGION]: Run failed - no output file generated"
	exit -1
else
	mv -f $BASEDIR/RASP/RUN/rasp2.${region}.printout $WXTOFLY_LOG/$LOGFILENAME.printout
fi

#check if printout indicates run failed
if grep -q "ERROR EXIT" "$WXTOFLY_LOG/$LOGFILENAME.printout" ; then
	echo "****Error: [RASP-$PARENTREGION.$REGION] ERROR EXIT found in rasp2."${region}".printout"
	$WXTOFLY_RUN/run_update_status.sh ERROR "[RASP-$PARENTREGION.$REGION]: Run failed with ERROR EXIT"
	exit -1 
fi

#update status
echo "[RASP-$PARENTREGION.$REGION] Duration: "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)
$WXTOFLY_RUN/run_update_status.sh OK "[RASP-$PARENTREGION.$REGION]: Finished nested run in "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)
