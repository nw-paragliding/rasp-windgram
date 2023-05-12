#!/bin/bash

#Arguments: CSV_FILE DATA_SOURCE_DATA_SOURCE_DOMAIN SITE_DATA_SOURCE_DOMAIN
# CSV_FILE - csv file to read list of sites
# DATA_SOURCE_DATA_SOURCE_DOMAIN - specifies which domain to use for reading wrfout data files
# SITE_DATA_SOURCE_DOMAIN - specifies for which domain to select sites from the csv

echo "[WINDGRAMS] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error: [WINDGRAMS] BASEDIR variable not defined"
	exit -1
fi

#site list CSV
CSV_FILE=$WXTOFLY_CONFIG/sites.csv
if [ ! -e $CSV_FILE ]
then
	echo "****Error: [WINDGRAMS] CSV file $CSV_FILE not found"
	exit -1
fi
echo "[WINDGRAMS] CSV_FILE=$CSV_FILE"

#domain - the data source dir with wrfout files
#it should be REGION name 1st stage and REGION-WINDOW for window runs
if [[ -z $1 ]]; then
	echo "****Error: [WINDGRAMS] DATA_SOURCE_DOMAIN argument not specified"
	exit -1
fi
DATA_SOURCE_DOMAIN=${1^^}
echo "[WINDGRAMS] DATA_SOURCE_DOMAIN=$DATA_SOURCE_DOMAIN"
shift

if [ -z $1 ]; then
	echo "****Error: [WINDGRAMS] SITE_REGION argument not specified"
	exit
fi
SITE_REGION=${1^^}
echo "[WINDGRAMS] SITE_REGION=$SITE_REGION"
shift

if [ -z $1 ]; then
	echo "****Error: [WINDGRAMS] SITE_DOMAIN argument not specified"
	exit
fi
SITE_DOMAIN=${1^^}
echo "[WINDGRAMS] SITE_DOMAIN=$SITE_DOMAIN"
shift

SITE_LIST_CSV=$WXTOFLY_TEMP/site_list.csv
rm -f $SITE_LIST_CSV
# prepare csv site list for windgram script
# !!!IMPORTANT - make sure the CSV has \n on the last line otherwise will not be read
while IFS=',' read -r STATE AREA SITE LAT LON REGION DOMAIN; do

	#remove possible non-printable characters at the end of the line
	DOMAIN=$(echo $DOMAIN | sed -e "s/[^[:print:]]//g")
	
	if [[ ( $SITE_REGION == $REGION ) && ( $SITE_DOMAIN == "ALL" || $SITE_DOMAIN == $DOMAIN ) ]]; 
	then
		echo "$SITE $LAT $LON" >>$SITE_LIST_CSV
	fi
done < $CSV_FILE

#grid - only used for grid info on the windgram plots
GRID="d2"
if [[ $DATA_SOURCE_DOMAIN == *"-WINDOW" ]]
then
	GRID="w2"
fi
echo "[WINDGRAMS] GRID=$GRID"

#relative humidity for windgram plots	
RHCUT=94 
echo "[WINDGRAMS] RHCUT=$RHCUT"

#output directory for windgram plots
OUTPUT_DIR="$WXTOFLY_WINDGRAMS/OUT/$DATA_SOURCE_DOMAIN/$GRID"
if [ ! -d $OUTPUT_DIR ]; then 
	mkdir -p $OUTPUT_DIR
else
	rm -f $OUTPUT_DIR/*.*
fi
echo "[WINDGRAMS] OUTPUT_DIR=$OUTPUT_DIR"

#determine pressure top for windgram plots
case $DATA_SOURCE_DOMAIN in

	PNW) PTOP=30;;
	
	PNW-WINDOW) PTOP=28;;
	
	FRASER-WINDOW) PTOP=28;;
	
	TIGER-WINDOW) PTOP=28;;
	
	FT_EBEY-WINDOW) PTOP=28;;
	
	PNWRAT) PTOP=32;;
	
	PNWRAT-WINDOW) PTOP=32;;
	
	*) PTOP=30
esac
echo "[WINDGRAMS] PTOP=$PTOP"

#NCL windgrams script
NCLFILE=$WXTOFLY_WINDGRAMS/windgrams.ncl
if [[ ! -f $NCLFILE ]]; then
	echo "****Error: [WINDGRAMS] NCL file $NCLFILE not found"
	exit -1
fi
echo "[WINDGRAMS] NCLFILE = $NCLFILE"

LOGFILE=${WXTOFLY_LOG}"/"$(basename $NCLFILE)"."${DATA_SOURCE_DOMAIN}".out"
echo "[WINDGRAMS] LOGFILE = $LOGFILE"

echo "[WINDGRAMS] Running: $BASEDIR/UTIL/ncl $NCLFILE outputDir=\"$OUTPUT_DIR\" siteListCsv=\"$SITE_LIST_CSV\" wrfDomain=\"$DATA_SOURCE_DOMAIN\" grid=\"$GRID\" ptop=$PTOP type=\"png\" rhcut=$RHCUT"
$BASEDIR/UTIL/ncl $NCLFILE outputDir=\"$OUTPUT_DIR\" siteListCsv=\"$SITE_LIST_CSV\" wrfDomain=\"$DATA_SOURCE_DOMAIN\" grid=\"$GRID\" ptop=$PTOP type=\"png\" rhcut=$RHCUT &>$LOGFILE
#rm -f $SITE_LIST_CSV

echo "[WINDGRAMS] Checking for errors"

if [ ! -e $LOGFILE ]
then
	echo "****Error: [WINDGRAMS] NCL output not found"
	exit -1
fi

ERRORFOUND=0
while read -r line ; 
do
	if [ "$line" ]; then
		echo "****Error: [WINDGRAMS] $line"
		ERRORFOUND=1
	fi
done <<< "$(egrep -i "fatal|error|stop" $LOGFILE)"

#do not exit - we have windgram plots
if [[ $ERRORFOUND -eq 0 ]]; then
	echo "[WINDGRAMS] No errors detected in NCL output"
fi


#Process plots
TEMPFILE=$WXTOFLY_TEMP/temp.gif

for FILE in $OUTPUT_DIR/*_windgram.png
do
	if [ ! -e $FILE ]; then
		echo "*** Error: [WINDGRAMS] no windgram files generated"
		exit -1
	fi
	
	echo "[WINDGRAMS] Processing $FILE"
	
	#reduce the image file size
	convert $FILE -depth 4 $TEMPFILE
	convert $TEMPFILE $FILE
	
	$WXTOFLY_UTIL/upload_queue_add.sh $FILE "html/windgrams" "WINDGRAMS"
	
	#old site support
	#rename windgrams and upload to root for current day only
	if [[ $DATA_SOURCE_DOMAIN != *"+"* ]]
	then
		NEWFILE=$OUTPUT_DIR/${FILE#*_}
		mv -f $FILE $NEWFILE
		$WXTOFLY_UTIL/upload_queue_add.sh $NEWFILE html "WINDGRAMS"
	fi
done
rm -f $TEMPFILE

echo "[WINDGRAMS] Finished $0"
