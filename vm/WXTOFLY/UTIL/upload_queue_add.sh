#!/bin/bash
if [ -z $1 ]; then
	echo "****Error: [UPLOAD] No file to upload specified"
	exit
fi
UPLOADFILE=$1
if [ ! -f $UPLOADFILE ]; then
	echo "****Error: [UPLOAD] File $1 does not exist"
	exit
fi

if [ -z $2 ]; then
	echo "****Error: [UPLOAD] No upload path specified"
	exit
fi
UPLOADPATH=$2

UPLOADCHANNEL="DEFAULT"
if [ ! -z $3 ]; then
	UPLOADCHANNEL=$3
fi

UPLOADDIR=$WXTOFLY_UPLOAD_ROOT/$UPLOADCHANNEL/$UPLOADPATH

if [ ! -d $UPLOADDIR ]; then
	if ! mkdir -p $UPLOADDIR; then
		echo "****Error: [UPLOAD] Unable to create upload folder $UPLOADDIR"
		exit
	fi
fi

QUEUEFILE=$UPLOADDIR/$(basename $UPLOADFILE)
TEMPQUEUEFILE=$UPLOADDIR/$(basename $UPLOADFILE).queue

#removes old file
if [ -f $QUEUEFILE ]
then
	if ! rm $QUEUEFILE; then
		echo "****Error: [UPLOAD] Unable to remove file $QUEUEFILE"
	fi
fi

#copy to a temp file
if ! cp -f $UPLOADFILE $TEMPQUEUEFILE;
then
	echo "****Error: [UPLOAD] Copying file to $WXTOFLY_UPLOAD_ROOT/$2"
	exit
else
	echo "[UPLOAD] File $1 queued for upload"
fi

#rename file - this is atomic operation
if ! mv $TEMPQUEUEFILE $QUEUEFILE ; then
	echo "****Error: [UPLOAD] Atomic rename failed"
	exit
fi

if [ ! -z $WXTOFLY_UPLOAD_ENABLED ] && [ $WXTOFLY_UPLOAD_ENABLED == "YES" ]; 
then
	$WXTOFLY_UTIL/upload_start.sh $UPLOADCHANNEL &
fi
