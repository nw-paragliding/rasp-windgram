#!/bin/bash
if [ -z $WXTOFLY_UPLOAD_ROOT ]; then
	echo "****Error: WXTOFLY_UPLOAD_ROOT variable not defined"
	exit
fi
if [ -z $WXTOFLY_UPLOAD_SERVER ]; then
	echo "****Error: WXTOFLY_UPLOAD_SERVER variable not defined"
	exit
fi
if [ -z $WXTOFLY_UPLOAD_USERNAME ]; then
	echo "****Error: WXTOFLY_UPLOAD_USERNAME variable not defined"
	exit
fi
if [ ! -f ~/.netrc ]; then
	echo "****Error: ~/.netrc file not found"
	exit
fi

UPLOADCHANNEL="DEFAULT"
if [ ! -z $1 ]; then
	UPLOADCHANNEL=$1
fi

UPLOADDIR=$WXTOFLY_UPLOAD_ROOT/$UPLOADCHANNEL

#repeatedly search for files to upload
#exit when no files found
let COUNT=0
let TOTALCOUNT=0
let TOTALBYTES=0
while : ; 
do
	echo "[$(date +%x-%X)] Entering upload loop"
	FOUNDFILE=0
	let COUNT=0
	for FILE in $(find $UPLOADDIR -type f ! -name "*.queue" ); 
	do
		if [[ $FILE == *".upload" ]]; then
			echo "****Error: Found orphaned upload file $FILE"
			continue
		fi

		FOUNDFILE=1
		
		#rename file - atomic operation
		if ! mv $FILE $FILE.upload ; then
			echo "****Error: Unable to rename file $FILE"
			continue
		fi
		
		UPLOADPATH=$(dirname $FILE)
		UPLOADPATH=${UPLOADPATH#$UPLOADDIR}
		if [[ $UPLOADPATH == "/"* ]]; then
			UPLOADPATH=${UPLOADPATH:1}
		fi
		
		URL=$WXTOFLY_UPLOAD_SERVER
		if [ ${URL:(-1)} != "/" ]; then 
			URL=$URL"/"
		fi
		if [[ $URL == "ftp://"* ]]; then
			URL=${URL#"ftp://"}
		fi
		URL=${URL}${UPLOADPATH}/$(basename $FILE)
		URL="ftp://"${WXTOFLY_UPLOAD_USERNAME}"@"${URL}

		echo "--> $URL"
		RESPONSE=$(curl -n -T $FILE.upload --write-out %{http_code} --silent --output /dev/null $URL)
		
		if [ $RESPONSE == "226" ]; then
			echo "  <-- OK ($RESPONSE)"
			((COUNT+=1))
			SIZE=$(du -b $FILE.upload | cut -f1)
			((TOTALBYTES+=SIZE))
			if ! rm $FILE.upload; then
				echo "****Error: Unable to remove $FILE.upload"
			fi
		else
			echo "  <-- ****ERROR ($RESPONSE)"
			if [ -e $FILE ]; then
				rm -f $FILE.upload
			else
				mv $FILE.upload $FILE
			fi
			sleep 5
		fi
		
		sleep 1
	done

	#done with single pass
	if [ $FOUNDFILE == 0 ]; then
		echo "[$(date +%x-%X)] No more files to upload - exiting"
		echo "[$(date +%x-%X)] Total uploaded: $TOTALCOUNT files"
		echo "[$(date +%x-%X)] Total uploaded: "$(numfmt --to=iec-i $TOTALBYTES)"B"
		$WXTOFLY_RUN/run_update_status.sh OK "[$UPLOADCHANNEL] Uploaded $TOTALCOUNT files ("$(numfmt --to=iec-i $TOTALBYTES)"B) in "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)
		
		#this will allow to count the total over the whole run
		RUNTOTALFILES=0
		if [ -e $WXTOFLY_LOG/total_uploaded_files.$UPLOADCHANNEL ]; then
			RUNTOTALFILES=$(cat $WXTOFLY_LOG/total_uploaded_files.$UPLOADCHANNEL)
		fi
		((RUNTOTALFILES=RUNTOTALFILES+TOTALCOUNT))
		echo $RUNTOTALFILES > $WXTOFLY_LOG/total_uploaded_files.$UPLOADCHANNEL
		RUNTOTALBYTES=0
		if [ -e $WXTOFLY_LOG/total_uploaded_bytes.$UPLOADCHANNEL ]; then
			RUNTOTALBYTES=$(cat $WXTOFLY_LOG/total_uploaded_bytes.$UPLOADCHANNEL)
		fi
		((RUNTOTALBYTES=RUNTOTALBYTES+TOTALBYTES))
		echo $RUNTOTALBYTES > $WXTOFLY_LOG/total_uploaded_bytes.$UPLOADCHANNEL
		exit
	else
		#wait and restart loop
		echo "[$(date +%x-%X)] Uploaded: $COUNT files"
		(( TOTALCOUNT+=COUNT ))
		sleep 30
		echo "[$(date +%x-%X)] Searching for more files to upload"
	fi
done

echo "Duration: "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)