#!/bin/bash

# converts blipspot text output to CSV

if [ -z $1 ]; then
	>&2 echo "****Error: [BLIPSPOT] File not specified" 
	exit -1
fi
BLIPSPOT_FILE=$1
if [ ! -e $BLIPSPOT_FILE ]
then
	>&2 echo "****Error: [BLIPSPOT] Blipspot file $BLIPSPOT_FILE not found"
	exit -1
fi
shift

BLIP_TIME_START=0
BLIP_DATA_START=0
JSON_START=0
VALUES=()
COLUMNS=0
ROWS=0
IFS='' 
while read LINE || [[ -n $LINE ]]; do

	LINE=$(echo $LINE | sed 's/[^[:print:]]//g')
	[[ ${#LINE} -le 1 ]] && continue
	
	if [ $BLIP_TIME_START == 0 ]
	then 
		if [[ $LINE == "------------------------------"* ]]; 
		then
			# Start reading time section
			BLIP_TIME_START=1
			echo "["
			continue
		else
			continue;
		fi
	else
		if [ $BLIP_DATA_START == 0 ]
		then
			if [[ $LINE == "------------------------------"* ]]
			then
				# Start reading data section
				BLIP_DATA_START=1
				continue
			else
				if [ $JSON_START == 0 ]
				then
					JSON_START=1
				else
					echo "},"
				fi
				LINE=$(echo "$LINE" | sed -e "s/^ *//g" -e "s/ *$//g" -e "s/  */,/g")
			fi
		else
			if [[ $LINE == "------------------------------"* ]]
			then
				# Done reading data section
				echo "}"
				echo "]"
				break
			else
				echo "},"
				LINE=$(echo "$LINE" | sed -e "s/^ *//g" -e "s/ *$//g" -e "s/   */,/g")
			fi
		fi
		
		echo "{"
		NAME=${LINE%%,*}
		echo "   \"name\":\"$NAME\","
		VALUES=$(echo $LINE | sed -e "s/ *//g")
		VALUES=${VALUES#*,*}
		VALUES=${VALUES%*,*}
		VALUES=$(echo $VALUES | sed -e "s/,/\",\"/g")
		echo "   \"values\":[\""$VALUES"\"]"
	fi

done < $BLIPSPOT_FILE



