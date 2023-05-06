#!/bin/bash
if [ ! -f $1 ]; then
	echo "****Error: [ARCHIVE] File $1 does not exist"
	exit
fi

if [ ! -z $WXTOFLY_ARCHIVE_ENABLED ] && [ $WXTOFLY_ARCHIVE_ENABLED == "YES" ]; then
	if [ ! -d $WXTOFLY_ARCHIVE_ROOT/$2 ]; then
		mkdir -p $WXTOFLY_ARCHIVE_ROOT/$2
		if [ $? != 0 ]; then
			echo "****Error: [ARCHIVE] Unable to create upload folder $WXTOFLY_ARCHIVE_ROOT/$2"
			exit
		fi
	fi
	mv -f $1 $WXTOFLY_ARCHIVE_ROOT/$2
	if [ $? != 0 ]; then
		echo "****Error: [ARCHIVE] Moving file to $WXTOFLY_ARCHIVE_ROOT/$2"
	else
		echo "[ARCHIVE] File $1 moved to $WXTOFLY_ARCHIVE_ROOT/$2"
	fi
fi
