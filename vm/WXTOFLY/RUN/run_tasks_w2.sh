#!/bin/bash
echo $0 $@

if [ -z $BASEDIR ]; then
	echo "****Error: BASEDIR variable not defined"
	exit
fi

#current region (doesn't contain -WINDOW for window runs)
if [[ -z $1 ]]; then
	echo "****Error: REGION parameter missing"
	exit
fi
REGION=$1
region=${REGION,,}
echo "REGION: $REGION"

$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Started w2 tasks"

#the region name without +N for multi-day forecast
SITES_REGION=$(echo $REGION | sed "s/\+[0-9]//")
#the domain name to filter sites on from the list
SITES_DOMAIN=$SITES_REGION"-WINDOW"

# nested regions
if [ $SITES_REGION == "TIGER" ] || [ $SITES_REGION == "FRASER" ] || [ $SITES_REGION == "FT_EBEY" ]
then
	SITES_REGION="PNW"
fi

$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Started generating BLIPSPOTS"
if ($WXTOFLY_BLIPSPOT/get_blipspots.sh $REGION "w2" $SITES_REGION $SITES_DOMAIN);
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Finished generating BLIPSPOTS"
else
	$WXTOFLY_RUN/run_update_status.sh ERROR "[${REGION}.w2] Error generating BLIPSPOTS"
fi

#data source domain name 
#must contain -WINDOW for window runs
#data under WRF/WRFV2/RASP/REGION-WINDOW/...
DATA_SOURCE_DOMAIN=${REGION}"-WINDOW"

$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Started generating WINDGRAMS"
if ($WXTOFLY_WINDGRAMS/get_windgrams.sh $DATA_SOURCE_DOMAIN $SITES_REGION $SITES_DOMAIN);
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Finished generating WINDGRAMS"
else
	$WXTOFLY_RUN/run_update_status.sh ERROR "[${REGION}.w2] Error generating WINDGRAMS"
fi

#cropping done only for current day forecast for specific regions
if [[ $REGION == "PNW" ]]
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Started cropping plots"
	$WXTOFLY_CROP/crop_ebey.sh
	$WXTOFLY_CROP/crop_bj.sh
	$WXTOFLY_CROP/crop_blan.sh
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Finished cropping plots"
elif [[ $REGION == "FRASER" ]]
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Started cropping plots"
	$WXTOFLY_CROP/crop_fraser.sh
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Finished cropping plots"
elif [[ $REGION == "TIGER" ]]
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Started cropping plots"
	$WXTOFLY_CROP/crop_tiger.sh
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] Finished cropping plots"
fi

$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.w2] All tasks finished in "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)