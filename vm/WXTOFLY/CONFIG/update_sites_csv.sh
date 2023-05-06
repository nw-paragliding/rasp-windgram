#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [CONFIG] BASEDIR variable not defined"
	exit -1
fi

if [ $WXTOFLY_DOWNLOAD_RUN_CONFIG != 'YES' ]
then
	echo "[CONFIG] Sites CSV download disabled"
	exit
fi

echo "[CONFIG] Obtaining new sites CSV"
rm -f $WXTOFLY_TEMP/sites.csv

HTTP_CODE=$(curl "http://${WXTOFLY_UPLOAD_SERVER}/status/sites.csv" --output $WXTOFLY_TEMP/sites.csv --silent --write-out %{http_code})
if [ $HTTP_CODE != 200 ]
then
	echo "[CONFIG] Sites CSV not available. Server responded $HTTP_CODE"
	exit -1
fi

if [ ! -e $WXTOFLY_TEMP/sites.csv ]
then
	echo "****Error: [CONFIG] Failed to download sites.csv"
	exit -1
fi

DIFF=$(diff $WXTOFLY_TEMP/sites.csv $WXTOFLY_CONFIG/sites.csv)
if [ "$DIFF" != "" ] 
then
	echo "[CONFIG] sites CSV updated"
	mv -f $WXTOFLY_TEMP/sites.csv $WXTOFLY_CONFIG/sites.csv
fi

rm -f $WXTOFLY_TEMP/sites.csv
