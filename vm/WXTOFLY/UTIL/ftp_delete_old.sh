#!/bin/bash
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

if [ -z $1 ]
then
	echo "****Error: FTP_PATH not specified"
	exit
fi
FTP_PATH="html/"$1
echo "[FTP] FTP_PATH=$FTP_PATH"

WXTOFLY_UPLOAD_SERVER=wxtofly.net
URI="ftp://$WXTOFLY_UPLOAD_USERNAME@$WXTOFLY_UPLOAD_SERVER/$FTP_PATH/"
echo "[FTP] URI=$URI"

TODAY_UTC=$(date -u +%Y-%m-%d)
TODAY_UTC=$(date -d "$TODAY_UTC" +%s)

for FILE in `curl -n -l -s $URI | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}_"`;
do
	
	#check wheather date represented by the folder is older than today
	FILE_TIMESTAMP=${FILE:0:10}
	FILE_DATE=$(date -d "$FILE_TIMESTAMP" +%s)
	if [ $TODAY_UTC -gt $FILE_DATE ]
	then
		echo "[FTP] Deleting ${FILE}"
		curl -n -s ${URI} -X "DELE /${FTP_PATH}/${FILE}"
	fi
done
