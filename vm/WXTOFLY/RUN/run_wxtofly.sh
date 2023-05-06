#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN] BASEDIR variable not defined"
	exit -1
fi
echo "[RUN] BASEDIR: $BASEDIR"

if [ -z $1 ]; then
	echo "****Error: [RUN] INIT argument not specified"
	exit -1
fi
INIT=$1
echo "[RUN] INITIALIZATION: $INIT"
shift

#Time limit for this run
NOW=$(date +%s)
#5hrs (18000sec) time limit 
#assume next job would interfere with next run
#if it took more than 1hrs
((MAX_TIME=NOW+18000))

$WXTOFLY_RUN/run_update_status.sh OK "Starting run for ${INIT}z"

$WXTOFLY_RUN/run_cleanup.sh $INIT

$WXTOFLY_CONFIG/update_run_conf.sh
$WXTOFLY_CONFIG/update_sites_csv.sh

#remove any possible locks from previous runs
rm -f $WXTOFLY_LOG/.WINDGRAMS.uploadlock
rm -f $WXTOFLY_LOG/.BLIPSPOT.uploadlock
rm -f $WXTOFLY_LOG/.RASP.uploadlock
rm -f $WXTOFLY_LOG/.DEFAULT.uploadlock
rm -f $WXTOFLY_LOG/.CROP.uploadlock
rm -f $WXTOFLY_LOG/.statuslock

#read all lines from run.conf
#jobs should looks like:
# INITz-REGION
# INITz-REGION-WINDOW
# INITz-REGION+N
# INITz-REGION+N-WINDOW
while read -r LINE || [[ -n $LINE ]]; do

	if [[ $(date +%s) -gt $MAX_TIME ]]; 
	then
		echo "****Error: [RUN] Run time limit exceeded"
		$WXTOFLY_RUN/run_update_status.sh ERROR "Run time limit exceeded - run aborted"
		break
	fi

	#skip comments and empty lines
	[[ $LINE = \#* ]] && continue
	[[ ${#LINE} -le 1 ]] && continue
	
	#remove any non printable characters
	LINE=$(echo $LINE | sed 's/[^[:print:]]//g')
	RUN_JOB=$LINE
	
	#skip jobs for other initialization times
	[[ "${RUN_JOB^^}" != "${INIT}Z-"* ]] && continue
	
	echo "[RUN] RUN JOB: $RUN_JOB"
	$WXTOFLY_RUN/run_update_status.sh OK "[RUN] Starting job $RUN_JOB"
	
	#remove the initialization part
	RUN_JOB=${RUN_JOB#*-}
	
	IS_WINDOW=0
	if [[ $RUN_JOB == *"-WINDOW" ]]
	then
		IS_WINDOW=1
		echo "[RUN] IS_WINDOW: $IS_WINDOW"
		RUN_JOB=${RUN_JOB/-WINDOW/}
	fi
	
	FCST_DAY=0
	if [[ $RUN_JOB == *"+"* ]]
	then
		FCST_DAY=${RUN_JOB#*+*}
		RUN_JOB=${RUN_JOB%*+*}
	fi
	
	echo "[RUN] FCST_DAY: $FCST_DAY"
	
	case $RUN_JOB in
		PNW)
		if [ $IS_WINDOW == 0 ]
		then
			if ! ($WXTOFLY_RUN/run_pnw_d2.sh $INIT $FCST_DAY)
			then
				echo "****Error: [RUN] Script error for job $LINE"
			fi
		else
			if ! ($WXTOFLY_RUN/run_pnw_w2.sh $INIT $FCST_DAY)
			then
				echo "****Error: [RUN] Script error for job $LINE"
			fi
		fi
		;;
		
		TIGER)
		if ! ($WXTOFLY_RUN/run_pnw_tiger_w2.sh $INIT $FCST_DAY)
		then
			echo "****Error: [RUN] Script error for job $LINE"
		fi
		;;
		
		FRASER)
		if ! ($WXTOFLY_RUN/run_pnw_fraser_w2.sh $INIT $FCST_DAY)
		then
			echo "****Error: [RUN] Script error for job $LINE"
		fi
		;;
		
		FT_EBEY)
		if ! ($WXTOFLY_RUN/run_pnw_ft_ebey_w2.sh $INIT $FCST_DAY)
		then
			echo "****Error: [RUN] Script error for job $LINE"
		fi
		;;
		
		PNWRAT)
		if [ $IS_WINDOW == 0 ]
		then
			if ! ($WXTOFLY_RUN/run_pnwrat_d2.sh $INIT $FCST_DAY)
			then
				echo "****Error: [RUN] Script error for job $LINE"
			fi
		else
			echo "****Error: [RUN] Job $LINE not implemented"
		fi
		;;
		
		*)
		echo "****Error: [RUN] Invalid job name: $LINE"
		;;
	
	esac
	
done < $WXTOFLY_CONFIG/run.conf

#wait for background jobs
#set max wait time 6hrs (21600sec) from run start
((MAX_TIME=NOW+21600))
echo "[RUN] Waiting for background tasks to finish"
while [ -e $WXTOFLY_LOG/.background_task_flag ];
do
	#sleep 1 minute
	sleep 60
	
	if [[ $(date +%s) -gt $MAX_TIME ]]; 
	then
		break
	fi
done
echo "[RUN] Background tasks finished"

#extract errors from all log files for easy diagnostics
ERRORSFILE=$WXTOFLY_TEMP"/wxtofly.err"
$WXTOFLY_RUN/run_find_errors.sh >$ERRORSFILE
if [ ! -s $ERRORSFILE ]; then
	rm -f $ERRORSFILE
else
	mv -f $ERRORSFILE $WXTOFLY_LOG"/wxtofly.err"
	$WXTOFLY_RUN/run_update_status.sh WARNING "Errors found in run log files"
fi

$WXTOFLY_RUN/run_update_status.sh OK "Finished run in "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)
echo "[RUN] Duration: "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)

#now wait for all files to be uploaded
$WXTOFLY_RUN/run_wait_upload_finished.sh

#remove old files on FTP server
#do this at the end so that different machines run it at different times
$WXTOFLY_UTIL/ftp_delete_old.sh "windgrams"
$WXTOFLY_UTIL/ftp_delete_old.sh "blipspots"
