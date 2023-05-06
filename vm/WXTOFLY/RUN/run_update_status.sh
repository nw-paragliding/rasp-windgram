#!/bin/bash

#add a new list to status CSV

if [ -z $BASEDIR ]; then
	echo "****Error: BASEDIR variable not defined"
	exit
fi

if [ -z $1 ]; then
	echo "****Error: MESSAGETYPE argument not specified"
	exit
fi
MESSAGETYPE=${1^^}

if [ $MESSAGETYPE != "ERROR" ] && [ $MESSAGETYPE != "OK" ] && [ $MESSAGETYPE != "WARNING" ]; then
	echo "****Error: MESSAGETYPE $MESSAGETYPE invalid"
	exit
fi

if [ -z "$2" ]; then
	echo "****Error: MESSAGE argument not specified"
	exit
fi
MESSAGE="$2"

STATUSFILE=$WXTOFLY_LOG/status.csv
TIMESTAMP=$(date +"%Y/%m/%d %H:%M:%S")

STATUS_LOCK_FILE=$WXTOFLY_LOG/.statuslock

function get_status_lock {
    for i in {1..30}; do
        if ( set -o noclobber; echo "$$" > "${STATUS_LOCK_FILE}") 2> /dev/null;
        then
            #this will cause the lock file to be deleted in case of other exit
            trap 'rm -f "${STATUS_LOCK_FILE}"; exit $?' INT TERM EXIT
            return 0
        else
            sleep $((($RANDOM % 10) + 1 ))
        fi
    done
    echo "Failed to aquire lock ${STATUS_LOCK_FILE} after 30 attempts" >&2
    return 1
}

function release_status_lock {
    rm -f "${STATUS_LOCK_FILE}"
    trap - INT TERM EXIT
}

get_status_lock
if [ ! -e $STATUSFILE ]; then
	echo "time,type,message" >>$STATUSFILE
fi
printf "%s,%s,%s\n" "$TIMESTAMP" "$MESSAGETYPE" "${MESSAGE/,/-}" >>$STATUSFILE
if [ ! -z $WXTOFLY_UPLOAD_ENABLED ] && [ $WXTOFLY_UPLOAD_ENABLED == "YES" ]; 
then
	$WXTOFLY_RUN/run_upload_status.sh
fi
release_status_lock
