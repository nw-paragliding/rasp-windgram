#!/bin/bash
if [ -z $BASEDIR ]; then
	echo "****Error: [CONFIG] BASEDIR variable not defined"
	exit -1
fi

if [ $WXTOFLY_DOWNLOAD_RUN_CONFIG != 'YES' ]
then
	echo "[CONFIG] Run configuration download disabled"
	exit
fi

echo "[CONFIG] Obtaining new run configuration"
rm -f $WXTOFLY_TEMP/run.conf

HTTP_CODE=$(curl "http://${WXTOFLY_UPLOAD_SERVER}/status/"$(hostname)"/run.conf" --output $WXTOFLY_TEMP/run.conf --silent --write-out %{http_code})
if [ $HTTP_CODE != 200 ]
then
	echo "[CONFIG] Run config file not available. Server responded $HTTP_CODE"
	exit -1
fi

if [ ! -e $WXTOFLY_TEMP/run.conf ]
then
	echo "****Error: [CONFIG] Failed to download run.conf"
	exit -1
fi

DIFF=$(diff $WXTOFLY_TEMP/run.conf $WXTOFLY_CONFIG/run.conf)
if [ "$DIFF" != "" ] 
then
	echo "[CONFIG] Run configuration updated"
	mv -f $WXTOFLY_TEMP/run.conf $WXTOFLY_CONFIG/run.conf
fi

rm -f $WXTOFLY_TEMP/run.conf
