#!/bin/bash

if [ -z $BASEDIR ]; then
	echo "****Error: BASEDIR variable not defined"
	exit
fi

TEMPLATE_DIR=$BASEDIR/WRF/wrfsi/templates
if [ ! -e $TEMPLATE_DIR ]
then
	echo "****Error: TEMPLATE_DIR does not exist"
	exit -1
fi

echo "["
FIRST_REGION=1
for FILE in $(find $TEMPLATE_DIR -type f -name "nest_info.txt")
do
	REGION=$(dirname $FILE)
	REGION=${REGION##*/}

	if [ $FIRST_REGION == 1 ]
	then
		FIRST_REGION=0
	else
		echo ","
	fi
	echo "{"
	echo "  \"region\":\"$REGION\","
	echo "  \"domains\":["
	
	HEADER=1
	FIRST=1
	while read LINE; do

		if [ $HEADER == 1 ]
		then
			HEADER=0
			continue
		fi
		
		LINE=$(echo $LINE | sed -e "s/,/ /g" -e "s/:/ /g")
		
		IFS=' ' read -r DOMAIN NX NY SPACE PA RA LLI LLJ URI URJ PTS CENT_LAT CENT_LON TAIL <<<$LINE
		
		if [ $FIRST == 1 ]
		then
			FIRST=0
		else
			echo "    ,"
		fi
		SPACE=$(printf "%#1.3f" $SPACE)
		SPACE=${SPACE/./}
		echo "    {\"domain\":\"$DOMAIN\","
		echo "     \"NX\":$NX,"
		echo "     \"NY\":$NY,"
		echo "     \"SPACE\":$SPACE,"
		echo "     \"PA\":$PA,"
		echo "     \"RA\":$RA,"
		echo "     \"LLI\":$LLI,"
		echo "     \"LLJ\":$LLJ,"
		echo "     \"URI\":$URI,"
		echo "     \"URJ\":$URJ,"
		echo "     \"PTS\":$PTS,"
		echo "     \"CENT_LAT\":$CENT_LAT,"
		echo "     \"CENT_LON\":$CENT_LON}"

	done < $FILE

	echo "  ]"
	echo "}"
	
done

echo "]"
