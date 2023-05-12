#!/bin/bash

#converts status CSV to JSON and uploads it to the website

$WXTOFLY_UTIL/csv2json.sh $WXTOFLY_LOG/status.csv > $WXTOFLY_TEMP/status.json
if ! $WXTOFLY_UTIL/upload.sh $WXTOFLY_TEMP/status.json html/status/$(hostname) ; then
	echo "****Error: [RUN] Status JSON not uploaded"
fi
	echo "[RUN] Status uploaded"
rm -f $WXTOFLY_TEMP/status.json