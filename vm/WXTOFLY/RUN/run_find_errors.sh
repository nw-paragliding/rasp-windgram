#!/bin/bash

TEMPFILE=$WXTOFLY_TEMP/errors

for FILE in $(find $WXTOFLY_LOG -type f ! -name "status.csv"); do
	grep "****Error" $FILE >$TEMPFILE
	if [ -s $TEMPFILE ]; then
		echo "$FILE"
		echo "-------------------------------------------------"
		cat $TEMPFILE
		echo ""
	fi
done

rm -f $TEMPFILE
