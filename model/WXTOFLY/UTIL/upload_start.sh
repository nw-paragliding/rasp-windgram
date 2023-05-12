#!/bin/bash

if [ -z $WXTOFLY_UPLOAD_ENABLED ] || [ $WXTOFLY_UPLOAD_ENABLED != "YES" ]; 
then
	exit
fi

UPLOADCHANNEL="DEFAULT"
if [ ! -z $1 ]; then
	UPLOADCHANNEL=$1
fi

UPLOAD_LOCK_FILE=$WXTOFLY_LOG/.$UPLOADCHANNEL.uploadlock

if ( set -o noclobber; echo "$$" > "${UPLOAD_LOCK_FILE}") 2> /dev/null;
then
	#this will cause the lock file to be deleted in case of other exit
	trap 'rm -f "${UPLOAD_LOCK_FILE}"; exit $?' INT TERM EXIT

	#lock acquired - do upload
	
	$WXTOFLY_UTIL/upload_all.sh $UPLOADCHANNEL &>>$WXTOFLY_LOG/upload.log

	#release lock
    rm -f "${UPLOAD_LOCK_FILE}"
    trap - INT TERM EXIT
fi