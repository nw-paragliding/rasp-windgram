#!/bin/bash

#generates a heartbeat JSON and uploads it to the website

if [ -z $BASEDIR ]; then
	if [ -z $1 ]; then
		echo "****Error: [HEARTBEAT] BASEDIR variable not defined"
		exit
	fi
	BASEDIR=$1
	if [ ! -f $BASEDIR/WXTOFLY/wxtofly.env ]; then
		echo "****Error: [HEARTBEAT] $BASEDIR/WXTOFLY/wxtofly.env not found"
		exit
	fi
	source $BASEDIR/WXTOFLY/wxtofly.env
fi

HEARTBEATFILE=$WXTOFLY_TEMP/heartbeat.json

USEDPCENT=$(df -l --output=pcent $BASEDIR | grep -vE '^Use')
USED=${USEDPCENT/\%/}

echo "{" >$HEARTBEATFILE
echo " \"timestamp\":"$(date +%s)"," >>$HEARTBEATFILE
echo " \"disk_usage\":"${USED/ /} >>$HEARTBEATFILE
echo "}" >>$HEARTBEATFILE

if ! $WXTOFLY_UTIL/upload.sh $HEARTBEATFILE html/status/$(hostname) ; then
	echo "****Error: [HEARTBEAT] Heartbeat JSON not uploaded"
fi
rm -f $HEARTBEAT