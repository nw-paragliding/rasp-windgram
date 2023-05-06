#!/bin/bash
CURRENTDIR=$(pwd)

if [ ! -z  $2  ]; then
	BASEDIR=$2
	if [ ! -d $BASEDIR ]; then
		echo "BASEDIR does not exists."
		exit
	fi
fi

if [ -z ${BASEDIR+x} ]; then
	echo "BASEDIR variable not defined. Execute from same window as run.rasp."
	exit -1
fi
echo "BASEDIR: $BASEDIR"

if [ -z  $1  ]; then
    echo "Error: Domain not defined. Use one of the values below:"
    ls $BASEDIR/RASP/RUN/OUT* |grep -i -v WINDOW
    exit -1
fi

DOMAIN=$1
domain=$(echo $DOMAIN |tr [:upper:] [:lower:])
if [ ! -d $BASEDIR/WRF/wrfsi/domains/$DOMAIN ]; then
    echo "Error: Invalid domain. Use one of the values below:"
    ls $BASEDIR/RASP/RUN/OUT* |grep -i -v WINDOW
    exit -1
fi
echo "DOMAIN: $DOMAIN"
echo ""

function find_errors {
	FILE=$1
	ERRORFOUND=0
	echo "$FILE"
	if [ -f $FILE ]; then
		grep -i error $FILE | while read -r line ; do
			if [[ $line == ">  ###"* ]]; then
			  continue
			fi
			if [[ $line == *"no detected error"* ]]; then
			  continue
			fi
			echo "$(tput setaf 1)$line$(tput sgr 0)"
			ERRORFOUND=1
		done
	else
		echo "$(tput setaf 3)Warning: File not found.$(tput sgr 0)"
	fi
	if [[ $ERRORFOUND -eq 0 ]]; then
		echo "$(tput setaf 2)No errors found$(tput sgr 0)"
	fi
	echo ""
}

function search_files {
	REGEX=$1
	SEARCHPATH=$2
	PATTERN=$3
	ERRORFOUND=0
	echo "Search $SEARCHPATH/$PATTERN for ""'"$REGEX"'"
	if [ -d $SEARCHPATH ]; then
		egrep -i "$REGEX" -A8 -B4 $SEARCHPATH/$PATTERN | while read -r line ; do
			echo "$(tput setaf 1)$line$(tput sgr 0)"
			ERRORFOUND=1
		done
	else
		echo "$(tput setaf 3)Warning: Path not found.$(tput sgr 0)"
	fi
	if [[ $ERRORFOUND -eq 0 ]]; then
		echo "$(tput setaf 2)No errors found$(tput sgr 0)"
	fi
	echo ""
}

function check_stderr {
	FILE=$1
	echo "$FILE"
	if [ -f $FILE ]; then
		fsize=$(stat -c%s "$FILE")
		if [ $fsize -gt 0 ]; then
			echo "File content:$(tput setaf 1)"
			cat $FILE
			echo "$(tput setaf 0)"
		else
			echo "$(tput setaf 2)No errors found$(tput sgr 0)"
		fi
	else
		echo "$(tput setaf 3)Warning: File not found.$(tput sgr 0)"
	fi
	echo ""
}

find_errors $BASEDIR/RASP/RUN/rasp.$domain.printout
check_stderr $BASEDIR/RASP/RUN/rasp.$domain.stderr

search_files "error|stop" $BASEDIR//RASP/RUN  rasp.$domain.stdout

search_files "error|stop" $BASEDIR/WRF/wrfsi/extdata/log '*.stdout'

search_files "error|stop" $BASEDIR/WRF/wrfsi/domains/$DOMAIN/log '*'
search_files "error|stop" $BASEDIR/WRF/wrfsi/domains/$DOMAIN-WINDOW/log '*'

search_files "error|stop" $BASEDIR/WRF/WRFV2/RASP/$DOMAIN 'real.out.*'
search_files "error|stop" $BASEDIR/WRF/WRFV2/RASP/$DOMAIN-WINDOW 'real.out.*'

search_files "error|stop" $BASEDIR/WRF/WRFV2/RASP/$DOMAIN '*.out*'
search_files "error|stop" $BASEDIR/WRF/WRFV2/RASP/$DOMAIN-WINDOW '*.out*'

search_files "stop|fatal|error" $BASEDIR/WRF/NCL rasp.ncl.out.$DOMAIN.*
search_files "stop|fatal|error" $BASEDIR/WRF/NCL rasp.ncl.out.$DOMAIN-WINDOW.*

