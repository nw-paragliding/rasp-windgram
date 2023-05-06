#!/bin/bash
echo $0 $@

if [ -z $BASEDIR ]; then
	echo "****Error: BASEDIR variable not defined"
	exit -1
fi

#current region name including +N for multy-day forecast
if [ -z $1 ]; then
	echo "****Error: REGION variable not defined"
	exit
fi
REGION=$1
region=${REGION,,}
echo "REGION: $REGION"

$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Started d2 tasks"

#the region name without +N for multi-day forecast
SITES_REGION=$(echo $REGION | sed "s/\+[0-9]//")

#generate blipspots for ALL sites
$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Started generating BLIPSPOTS"
if ($WXTOFLY_BLIPSPOT/get_blipspots.sh $REGION "d2" $SITES_REGION "ALL");
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Finished generating BLIPSPOTS"
else
	$WXTOFLY_RUN/run_update_status.sh ERROR "[${REGION}.d2] Error generating BLIPSPOTS"
fi

#generate windgrams for ALL sites
$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Started generating WINDGRAMS"
if ($WXTOFLY_WINDGRAMS/get_windgrams.sh $REGION $SITES_REGION "ALL");
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Finished generating WINDGRAMS"
else
	$WXTOFLY_RUN/run_update_status.sh ERROR "[${REGION}.d2] Error generating WINDGRAMS"
fi

#crop plots only for current day forecast
if [ $REGION == "PNW" ]
then
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Started plot cropping"
	$WXTOFLY_CROP/crop_chelan.sh
	$WXTOFLY_CROP/crop_dog.sh
	$WXTOFLY_CROP/crop_ebey.sh
	$WXTOFLY_CROP/crop_sanjuan.sh
	$WXTOFLY_CROP/crop_ok.sh
	$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] Finished plot cropping"
fi

$WXTOFLY_RUN/run_update_status.sh OK "[${REGION}.d2] All tasks finished in "$($WXTOFLY_UTIL/print_duration.sh $SECONDS)
