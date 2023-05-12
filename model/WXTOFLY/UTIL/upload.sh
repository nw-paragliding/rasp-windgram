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

[ -z $1 ] && echo "****Error: file to upload not specified" && exit 1
FILE=$1
[ -z $2 ] && echo "****Error: upload path not specified" && exit 1
UPLOADPATH=$2

if [[ $UPLOADPATH == "/"* ]]; then
	UPLOADPATH=${UPLOADPATH:1}
fi
		
URL=$WXTOFLY_UPLOAD_SERVER
if [ ${URL:(-1)} != "/" ]; then 
	URL=$URL"/"
fi
if [[ $URL == "ftp://"* ]]; then
	URL=${URL#"ftp://"}
fi
URL=${URL}${UPLOADPATH}/$(basename $FILE)
URL="ftp://"${WXTOFLY_UPLOAD_USERNAME}"@"${URL}

echo "--> $URL"
RESPONSE=$(curl -n -T $FILE --write-out %{http_code} --silent --output /dev/null $URL)

if [ $RESPONSE == "226" ]; then
	echo "  <-- OK ($RESPONSE)"
else
	echo "  <-- ****ERROR ($RESPONSE)"
	
	#attempt to refresh connection
	if [ $RESPONSE == "000" ]
	then
	
		echo "Refreshing connection"
		
		nmcli n off
		
		if ! (nmcli n on);
		then
			echo "****ERROR: Failed to enable networking"
		fi
	
		sleep 30
	fi

	exit 1
fi
