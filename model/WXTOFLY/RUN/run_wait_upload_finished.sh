#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [RUN] BASEDIR variable not defined"
	exit
fi

if [ $WXTOFLY_UPLOAD_ENABLED != "YES" ]; 
then
	exit
fi

LASTCOUNT=0
LOOPCOUNT=3

echo "[RUN] Waiting for all files to be uploaded"

while : ; 
do
	COUNT=0
	for FILE in $(find $WXTOFLY_UPLOAD_ROOT -type f ! -name "*.upload" ); 
	do
		((COUNT++))
	done
	
	#all files uploaded
	if [ $COUNT == 0 ];
	then
		#sleep to make sure any remaining uploads are finished
		sleep 60
		echo "[RUN] All files uploaded"
		$WXTOFLY_RUN/run_update_status.sh OK "All files uploaded"
		break
	#The same count could indicate offline state
	elif [ $COUNT == $LASTCOUNT ];
	then
		#offline
		if [ $LOOPCOUNT == 0 ]; then
			echo "****Error: [RUN] system appears offline"
			break
		fi
		((LOOPCOUNT--))
		sleep 300
	else
		LASTCOUNT=$COUNT
		LOOPCOUNT=3
		sleep 300
	fi
done

RUNTOTALFILES=0
for FILE in $(find $WXTOFLY_LOG -type f -name "total_uploaded_files*"); 
do
	if [ -e $FILE ]; then
		COUNT=$(cat $FILE)
		((RUNTOTALFILES=RUNTOTALFILES+COUNT))
	fi
done

RUNTOTALBYTES=0
for FILE in $(find $WXTOFLY_LOG -type f -name "total_uploaded_bytes*"); 
do
	if [ -e $FILE ]; then
		COUNT=$(cat $FILE)
		((RUNTOTALBYTES=RUNTOTALBYTES+COUNT))
	fi
done

echo "[RUN] Total uploaded: $RUNTOTALFILES files"
$WXTOFLY_RUN/run_update_status.sh OK "[UPLOAD] Total files: $RUNTOTALFILES"
echo "[RUN] Total uploaded: "$(numfmt --to=iec-i $RUNTOTALBYTES)"B"
$WXTOFLY_RUN/run_update_status.sh OK "[UPLOAD] Total size: "$(numfmt --to=iec-i $RUNTOTALBYTES)"B"
