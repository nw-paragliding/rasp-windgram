#!/bin/bash

#Arguments: CSV_FILE DATA_SOURCE_REGION DATA_SOURCE_GRID SITE_DOMAIN
# CSV_FILE - csv file to read list of sites
# DATA_SOURCE_REGION - specifies which region to use for reading data files
# DATA_SOURCE_GRID - specifies for which grid to select sites from the csv
# SITE_DOMAIN - specifies which region to select sites from the csv

echo "[BLIPSPOT] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error: [BLIPSPOT] BASEDIR variable not defined"
	exit -1
fi

CSV_FILE=$WXTOFLY_CONFIG/sites.csv
if [ ! -e $CSV_FILE ]
then
	echo "****Error: [BLIPSPOT] CSV file $CSV_FILE not found"
	exit -1
fi
echo "[BLIPSPOT] CSV_FILE=$CSV_FILE"

if [ -z $1 ]; then
	echo "****Error: [BLIPSPOT] DATA_SOURCE_REGION argument not specified"
	exit -1
fi
DATA_SOURCE_REGION=${1^^}
echo "[BLIPSPOT] DATA_SOURCE_REGION=$DATA_SOURCE_REGION"
shift

if [ -z $1 ]; then
	echo "****Error: [BLIPSPOT] DATA_SOURCE_GRID argument not specified"
	exit
fi
DATA_SOURCE_GRID=$1
echo "[BLIPSPOT] DATA_SOURCE_GRID=$DATA_SOURCE_GRID"
shift

if [ -z $1 ]; then
	echo "****Error: [BLIPSPOT] SITE_REGION argument not specified"
	exit
fi
SITE_REGION=${1^^}
echo "[BLIPSPOT] SITE_REGION=$SITE_REGION"
shift

if [ -z $1 ]; then
	echo "****Error: [BLIPSPOT] SITE_DOMAIN argument not specified"
	exit
fi
SITE_DOMAIN=${1^^}
echo "[BLIPSPOT] SITE_DOMAIN=$SITE_DOMAIN"
shift

OUTPUT_DIR="$WXTOFLY_BLIPSPOT/OUT/$DATA_SOURCE_REGION/$DATA_SOURCE_GRID" 
if [ ! -d $OUTPUT_DIR ]; then
	mkdir -p $OUTPUT_DIR
	if [ $? != 0 ]; then
		echo "****Error: [BLIPSPOT] Unable to create output dir $OUTPUT_DIR"
		exit -1 
	fi
else
	rm -f $OUTPUT_DIR/*.*
fi

ARRAY_SITES=()
ARRYS_WLONS=()
ARRAY_WLATS=()

#load only sites matching region and grid
#!!!IMPORTANT - make sure the CSV has \n on the last line otherwise will not be read
while IFS=',' read -r STATE AREA SITE LAT LON REGION DOMAIN; do
	
	DOMAIN=$(echo $DOMAIN | sed -e "s/[^[:print:]]//g")
	if [[ ( $SITE_REGION == $REGION ) && ( $SITE_DOMAIN == "ALL" || $SITE_DOMAIN == $DOMAIN ) ]]; 
	then
		ARRAY_SITES+=("$SITE")
		ARRYS_WLONS+=("$LON")
		ARRAY_WLATS+=("$LAT")
	fi
done < $CSV_FILE

SITES_COUNT=${#ARRAY_SITES[@]}
echo "[BLIPSPOT] Loaded $SITES_COUNT sites from $CSV_FILE"
if [ $SITES_COUNT == 0 ]
then
	echo "****Error: [BLIPSPOT] no sites found for region $SITE_DOMAIN"
	exit -1
fi

RET_CODE=0

#loop through all sites
for ((i=0; i < $SITES_COUNT; i++))
do
	#determine whether to process this site
	SITE_NAME=${ARRAY_SITES[$i]}
	
	echo "[BLIPSPOT] Processing site $SITE_NAME, Region: $DATA_SOURCE_REGION"
	DATA_SOURCE_DIR="$BASEDIR/RASP/HTML/$DATA_SOURCE_REGION/FCST/";
	echo "[BLIPSPOT] Data source dir: $DATA_SOURCE_DIR"

	#check any data files are present
	if ! ls $DATA_SOURCE_DIR/*.curr*.*lst.$DATA_SOURCE_GRID.data &> /dev/null; 
	then
		echo "****Error: [BLIPSPOT] No data files found"
		continue
	fi
	
	TEMP_STDOUT=$WXTOFLY_TEMP/extract.blipspot.out
	TEMP_STDERR=$WXTOFLY_TEMP/extract.blipspot.stderr
	echo "[BLIPSPOT] Running: $BASEDIR/RASP/UTIL/extract.blipspot.PL $DATA_SOURCE_REGION $SITE_NAME $DATA_SOURCE_GRID 0 ${ARRAY_WLATS[$i]} ${ARRYS_WLONS[$i]} 1"
	if ! $BASEDIR/RASP/UTIL/extract.blipspot.PL $DATA_SOURCE_REGION $SITE_NAME $DATA_SOURCE_GRID 0 ${ARRAY_WLATS[$i]} ${ARRYS_WLONS[$i]} 1 >$TEMP_STDOUT 2>$TEMP_STDERR ;  then
		echo "****Error: [BLIPSPOT] Running extract.blipspot.PL failed"
	fi

	#some errors are ok
	if [ -e $TEMP_STDERR ] && [ -s $TEMP_STDERR ];
	then
		echo "****Error: [BLIPSPOT] Errors found while runnning extract.blipspot.PL"
		cp -f $TEMP_STDERR $WXTOFLY_LOG/extract.blipspot.${DATA_SOURCE_REGION}.${SITE_NAME}.$DATA_SOURCE_GRID.err
		RET_CODE=-1
	fi
	
	if [ ! -s $TEMP_STDOUT ];
	then
		echo "****Error: [BLIPSPOT] extract.blipspot.PL did not generate output"
		RET_CODE=-1
		continue;
	else
		cp -f $TEMP_STDOUT $OUTPUT_DIR"/blipspot"$SITE_NAME".txt"
	fi
	
	#convert to JSON
	FCST_DATE=$(date -u +%Y-%m-%d)
	[[ $DATA_SOURCE_REGION == *"+1" ]] && FCST_DATE=$(date -d "+1 day" -u +%Y-%m-%d)
	[[ $DATA_SOURCE_REGION == *"+2" ]] && FCST_DATE=$(date -d "+2 day" -u +%Y-%m-%d)
	[[ $DATA_SOURCE_REGION == *"+3" ]] && FCST_DATE=$(date -d "+3 day" -u +%Y-%m-%d)
	BLIPSPOT_JSON=$OUTPUT_DIR"/"$FCST_DATE"_blipspot_"$SITE_NAME".json"
	if ! ($WXTOFLY_BLIPSPOT/blipspot_to_json.sh $TEMP_STDOUT >$BLIPSPOT_JSON)
	then
		echo "****Error: [BLIPSPOT] Unable to convert blipspot data to JSON"
	else
		$WXTOFLY_UTIL/upload_queue_add.sh $BLIPSPOT_JSON html/blipspots "BLIPSPOT"
	fi
	
	#this will parse the tmp output and create the blipspot${ARRAY_SITES[$i]}.html file with headers and footers etc.
	OUTFILE=$OUTPUT_DIR"/blipspot"$SITE_NAME".html"

	echo "<!DOCTYPE html ><meta charset="utf-8"><html><head> <title>Blipspot for $site at $lat $lon</title>"  >$OUTFILE
	cat $WXTOFLY_BLIPSPOT/blipheader.html >>$OUTFILE
	echo "<h3><font color=#8800EE ><u>For $site</u></font>  Boundary Layer* Information Prediction for Soaring Potential Over Time Blipspot for<a href=\"http://maps.google.com/maps?f=q&hl=en&q=$lat,$lon&t=p\" title=\"google map\"> $lat  $lon</a></h3> from TJ's <a href=http://wxtofly.net/RASP/PNW/index.html >RASP forecasts </a>" >>$OUTFILE
	
	#create header
	grep BLIPSPOT $TEMP_STDOUT |sed -e 's#\(BLIPSPOT for \)\([0-9]*.*--\)#\1<b><big>\2<\/big><\/b>#g' -e 's#d2#<b>4km</b> res.#g' -e 's#w2#<b>1.3km</b> res.#g' >$WXTOFLY_TEMP/header
	echo "&nbsp;&nbsp; &rarr; "$(date +"%b %d %H:%M %Z")" <span class=\"info\">"$(date -u +"for %A ")"</span> " >>$WXTOFLY_TEMP/header
	echo "<a class=\"awindgram\" href="$SITE_NAME"_iwindgram.html title=\"Windgram for $site\"> "$SITE_NAME" Windgram </a>" >>$WXTOFLY_TEMP/header

	cat $WXTOFLY_TEMP/header >>$OUTFILE
	rm -f $WXTOFLY_TEMP/header
	
	echo "<table>" >>$OUTFILE
	
	cat $TEMP_STDOUT |grep -v '\-\-\-\-\-\-\-\-\-\-\-\-\-' \
		|tr -s " " " " |sed -e 's#\([a-zA-Z\.]\) #\1_#g'|sed  -e 's#lst_#lst #g' -e 's#IME_#IME #g' \
		-e 's#h_F#h F#' -e 's#_\([0-9]\)# \1#g'   -e 's#_-# -#g' -e 's#^ ##' -e 's#_$##g'  -e '# #</td><td class="bl">#g' \
		-e 's#$#</td></tr>#'  -e 's# #</td><td class="bl">#g' -e 's#^#<tr><td class="bl">#g' \
		-e '/^.*Wind_Sp_Kt/s#<tr>#<tr class="sphilite">#' \
		-e '/^.*BL_Cloud_/s#<tr>#<tr class="clhilite">#' \
		-e '/^.*MaxSoar_clds/s#<tr>#<tr class="bhilite">#' \
		-e '/^.*MaxSoar_AGL/s#<tr>#<tr class="bhilite">#' \
		-e '/^.*rain/s#<tr>#<tr class="rhilite">#' \
		-e '/^.*10M_Wind_Dir/s#<tr>#<tr class="direction">#' \
		-e '/10M_Wind_Dir/s#\([0-9]\+\)\(<\)#<script type=text/javascript>document.write(direction[parseInt((\1+11.25)/22.5)]);</script><br>\1\&deg;\2#g' \
		>$WXTOFLY_TEMP/outtemp

	TIMEZONE=$(date +%Z)
	cat $WXTOFLY_TEMP/outtemp | egrep -v 'BLIPSPOT' | sed -e 's#W\*#Up_Velocity fpm#g' \
		-e 's#Hcrit#Max_soar_alt#g' \
		-e 's#Depth#Depth_AGL#g' \
		-e 's#ForecastPd_#ForecastPd<br>\&nbsp; #'  | sed -e "s#lst#<small>$TIMEZONE\&nbsp;</small>#g" \
		-e 's#_AGL_AGL#_AGL#g' \
		-e 's#Max_soar_alt_Depth_AGL_#AGL_Lift_to#' \
		-e 's#Hour_#by#' \
		-e 's#Sfc.Temp_=#When_sfc_temp= #g' \
		-e 's#---#<small>unlikely</small>#g' \
		-e 's#td_cl#td cl#g' \
		-e '/^.*Up_Velocity/s#<tr>#<tr class="bhilite">#g'   \
		-e '/Bouy\/Shr_Ratio/s#\([1-9][0-9]\)#<font color=crimson><b>\1</b></font>#g' \
		-e '/ForecastPd/s#<td#<th#g' \
		-e '/ForecastPd/s#\.0h#hrs#g' \
		-e '/VALID/s#2000#20 #g' \
		-e '/VALID/s#1000#10 #g' \
		-e '/VALID/s#0000#0 #g' \
		-e '/VALID/s#00# #g' \
		-e '/rigger/s#<tr#</table><table><tr#g' \
		-e '/Up_Velocity/s#\([4-9][0-9][0-9]\)#<font color=crimson><u><b>\1</b></u></font>#g' \
		-e '/Up_Velocity/s#\([3][5-9][0-9]\)#<font color=lightcoral><b>\1</b></font>#g' \
		-e 's/Converge/<a href="http:\/\/www.drjack.info\/BLIP\/INFO\/SSA_CONVENTION_TALK\/convergence_resolution.page.html" title=" Note that convergence line dynamics occur on a much smaller scale than is resolved by the model - for example, the actual upward motion has a width on the order of 100 m compared with typical model resolutions of 12-20 km.  Model convergence must be spread over a GRID cell rather than the actual convergence line width, so the model will greatly under-predict the magnitude of this upward motion.">Convergence<\/a>/g' \
		>$WXTOFLY_TEMP/outtemp2

	cat $WXTOFLY_TEMP/outtemp2 >>$OUTFILE
	
	rm -f $WXTOFLY_TEMP/outtemp
	rm -f $WXTOFLY_TEMP/outtemp2

	cat $WXTOFLY_BLIPSPOT/blipfooter.html >>$OUTFILE

	rm -f $TEMP_STDERR
	rm -f $TEMP_STDOUT
	
	echo "[BLIPSPOT] Generated $OUTFILE"
done

if ! ls $OUTPUT_DIR/*.html &>/dev/null ; then
	echo "****Error: [BLIPSPOT] No files generated"
	exit -1
fi

#old site
#upload to root only for current day
if [[ $DATA_SOURCE_REGION != *"+"* ]]
then
	for FILE in $(ls $OUTPUT_DIR/*.html); do
		$WXTOFLY_UTIL/upload_queue_add.sh $FILE html "BLIPSPOT"
	done
fi

exit $RET_CODE