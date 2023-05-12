#!/bin/bash

shopt -s expand_aliases
# Must set this option, else script will not expand aliases.

echo "$0 $@"

if [ -z $1 ]; then
	echo "****Error: REGION not specified"
	exit
fi
if [ -z $2 ]; then
	echo "****Error: DOMAINID not specified"
	exit
fi
if [ -z $3 ]; then
	echo "****Error: TIME not specified"
	exit
fi

#region name without -WINDOW for window runs
REGION=${1^^}
#d2/w2
DOMAINID=$2
#UTC forecast hour
TIME=${3/Z/}

alias echo_ok='echo "[HOOK-$REGION-$DOMAINID-${TIME}Z] "'
alias echo_error='echo "****Error: [HOOK-$REGION-$DOMAINID-${TIME}Z] "'

echo_ok "REGION=$REGION"

#check whether uploading of RASP plots is enable for this region
#not all plots are displayed on the website
if [ ! -e $WXTOFLY_CONFIG/rasp_plot_upload.conf ]
then
	echo_error "Upload config file $WXTOFLY_CONFIG/rasp_plot_upload.conf not found"
fi
if ! (grep -q $REGION $WXTOFLY_CONFIG/rasp_plot_upload.conf); 
then
	echo_ok "Uploading RASP plots not enabled for region"
	exit
fi

echo_ok "DOMAINID=$DOMAINID"
echo_ok "TIME=$TIME"

OFFSET=$(echo $(date +%z |sed -e 's/-0//'))
let "IMAGETIME=$TIME - $OFFSET"

if [[ $IMAGETIME -lt 1000 ]]; then
	IMAGETIME="0$IMAGETIME" 
fi
echo_ok "IMAGETIME=$IMAGETIME"

#claim maps
ANNOTATE_ENABLED=0

#I am not sure why TJ was doing this
#text is placed inside the map and only for some files
#it will be disabled using ANNOTATE_ENABLED variable
#to turn in back on set ANNOTATE_ENABLED to 1
if [ ANNOTATE_ENABLED == 1 ]
then
	if [[ $REGION  == "PNW"  ]]; then
		
		echo_ok "Processing images for $REGION"

		FORECASTDATE=$(date -u +"%a %d %b")
		echo_ok "FORECAST DATE=$FORECASTDATE"
		PUBLISHEDTIME=$(date +"%a %H:%M %p %Z") 
		echo_ok "PUBLISHED TIME: $PUBLISHEDTIME"
		
		TEMPFILE=$WXTOFLY_TEMP/temp.png

		for FILE in $BASEDIR/RASP/HTML/PNW/FCST/tenmwind*.curr.${IMAGETIME}lst.${DOMAINID}.png;
		do 
			if [ ! -e $FILE ]; then
				echo_error "No files found - $BASEDIR/RASP/HTML/PNW/FCST/tenmwind.curr.${IMAGETIME}lst.${DOMAINID}.png"
				break
			fi
			FORECASTTIME=$(echo $FILE |sed -e 's#^.*curr.##g' -e 's#lst.*##g' -e 's#\([0-2][0-9]\)\(00\)#\1:\2#g')
			convert $FILE\
			 -pointsize 14 -annotate +229+545 "Forcast for ${FORECASTTIME} ${FORECASTDATE}"  \
			 -pointsize 12 -annotate +229+788 "TJ Olney's RASP maps " \
			 -pointsize 12 -annotate +228+800 "Issued 3X daily "\
			 -pointsize 12 -annotate +228+810 "Published: ${PUBLISHEDTIME}"\
			 -pointsize 12 -annotate +228+820 "More weather stuff at:"\
			 -pointsize 13 -annotate +228+832 "wxtofly.net/ip.html" $TEMPFILE;
			if [ $? == 0 ]; then
				mv -f $TEMPFILE $FILE
				echo_ok "File $FILE annotated"
				echo_ok "FORECAST TIME: $FORECASTTIME"
			else
				echo_error "Annotating file $FILE"
			fi
		done

		for FILE in $BASEDIR/RASP/HTML/PNW/FCST/sfcwind*.curr.${IMAGETIME}lst.${DOMAINID}.png;
		do
			if [ ! -e $FILE ]; then
				echo_error "No files found - $BASEDIR/RASP/HTML/PNW/FCST/sfcwind*.curr.${IMAGETIME}lst.${DOMAINID}.png"
				break
			fi
			FORECASTTIME=$(echo $FILE |sed -e 's#^.*curr.##g' -e 's#lst.*##g' -e 's#\([0-2][0-9]\)\(00\)#\1:\2#g')
			convert $FILE  -pointsize 12 -annotate +229+600 "TJ Olney's RASP maps " \
			-pointsize 14 -annotate +225+630 "wxtofly.net" \
			-pointsize 12 -annotate +225+800 "Issued 3Xdaily  Published: ${PUBLISHEDTIME}"\
			-pointsize 12 -annotate +228+820 "More weather stuff at:"\
			-pointsize 12 -annotate +228+830 "wxtofly.net/ip.html" $TEMPFILE;
			if [ $? == 0 ]; then
				mv -f $TEMPFILE $FILE
				echo_ok "File $FILE annotated"
				echo_ok "FORECAST TIME: $FORECASTTIME"
			else
				echo_error "Annotating file $FILE"
			fi
		done
		
		rm -f $TEMPFILE
	fi
fi

find $BASEDIR/RASP/HTML/$REGION/FCST -name "previous*.*" -delete

echo_ok "Uploading plots for $REGION"
for FILE in $BASEDIR/RASP/HTML/${REGION}/FCST/*.${IMAGETIME}lst.${DOMAINID}.png; 
do
	if [ ! -e $FILE ]; then
		echo_error "****Error: No files to upload - $BASEDIR/RASP/HTML/PNW/FCST/*.${IMAGETIME}lst.${DOMAINID}.png"
		break
	fi
	$WXTOFLY_UTIL/upload_queue_add.sh $FILE html/RASP/$REGION/FCST "RASP"
done
