#!/bin/bash
echo "[CROP] $0 $@"

if [ -z $BASEDIR ]; then
	echo "****Error: [CROP] BASEDIR variable not defined"
	exit -1
fi

## Generic cropping using graphics magic for Rasp blipmaps.
## Requires minimum of 4 parameters easy to make separate scripts that call it with the proper parameters
#getcropgeneric ${REGION} ${DOMAIN} ${FOCUS} ${PARAM} ${WIDTH} ${HEIGHT} ${X} ${Y} ${STARTLEVEL} ${LOWESTLEVEL}

if [[ -z $1 ]]; then
	echo "****Error: [CROP] REGION argument not specified"
	exit -1
fi
REGION=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] DOMAIN argument not specified"
	exit -1
fi
DOMAIN=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] FOCUS argument not specified"
	exit -1
fi
FOCUS=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] PARAM argument not specified"
	exit -1
fi
PARAM=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] WIDTH argument not specified"
	exit -1
fi
WIDTH=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] HEIGHT argument not specified"
	exit -1
fi
HEIGHT=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] X argument not specified"
	exit -1
fi
X=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] Y argument not specified"
	exit -1
fi
Y=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] STARTLEVEL argument not specified"
	exit -1
fi
STARTLEVEL=$1
shift

if [[ -z $1 ]]; then
	echo "****Error: [CROP] LOWESTLEVEL argument not specified"
	exit -1
fi
LOWESTLEVEL=$1

echo "[CROP] REGION=$REGION"
echo "[CROP] DOMAIN=$DOMAIN"
echo "[CROP] FOCUS=$FOCUS"
echo "[CROP] PARAM=$PARAM"
echo "[CROP] WIDTH=$WIDTH"
echo "[CROP] HEIGHT=$HEIGHT"
echo "[CROP] X=$X"
echo "[CROP] Y=$Y"
echo "[CROP] STARTLEVEL=$STARTLEVEL"
echo "[CROP] LOWESTLEVEL=$LOWESTLEVEL"

OUTPUTDIR="$WXTOFLY_CROP/OUT/$REGION/$DOMAIN/${FOCUS}" 
echo "[CROP] OUTPUTDIR=$OUTPUTDIR"
if [ ! -d $OUTPUTDIR ]; then
	mkdir -p $OUTPUTDIR
	if [ $? != 0 ]; then
		echo "****Error: [CROP] Unable to create output dir $OUTPUTDIR"
		exit -1 
	fi
else
	rm -f $OUTPUTDIR/*.*
fi

SOURCEDIR="$BASEDIR/RASP/HTML/${REGION}/FCST"
echo "[CROP] SOURCEDIR=$SOURCEDIR"

if ls $SOURCEDIR/${PARAM}*${DOMAIN}.png &> /dev/null; then
	echo "[CROP] Found files macthing ${PARAM}*${DOMAIN}.png in $SOURCEDIR"
else
	echo "****Error: [CROP] No files matching ${PARAM}*${DOMAIN}.png found in $SOURCEDIR"
	exit -1
fi

FORECASTDATE=$(date -u +%a_%d_%b)
PUBLISHTIME=$(date +%a_%I:%M%p)
echo "[CROP] FORECAST DATE=$FORECASTDATE"
echo "[CROP] PUBLISH TIME=$PUBLISHTIME"

NOTE_X=$(( $X+10 ))
NOTE_Y=$(( $Y+20 ))

if [[  ${FOCUS} == "dog"  ]]; then
	NOTE_X=$(( $X+20 ))
	NOTE_Y=$(( $Y+$HEIGHT-30 ))
elif [[ ${FOCUS} == "chelan" ]]; then
	NOTE_Y=$(( $Y+370 ))
	NOTE_X=$(( $X+250 ))
fi

dohours () 
{
	if ls ${SOURCEDIR}/${PARAM}${CURRENTLEVEL}.curr.*lst.${DOMAIN}.png &>/dev/null;
	then
		for HOUR in 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000; 
		do 
			FORECASTTIME=$(echo $HOUR |sed  -e 's#\([0-2][0-9]\)\(00\)#\1:\2 #g')
			INPUTFILE=${SOURCEDIR}/${PARAM}${CURRENTLEVEL}.curr.${HOUR}lst.${DOMAIN}.png
			OUTPUTFILE=${OUTPUTDIR}/${FOCUS}${PARAM}${CURRENTLEVEL}.${HOUR}.png
			if [ -e $INPUTFILE ]; then
				echo "[CROP] $(basename $INPUTFILE)-->$(basename $OUTPUTFILE) for HOUR:$HOUR, LEVEL:$CURRENTLEVEL"
				convert $INPUTFILE -crop ${WIDTH}x${HEIGHT}+${X}+${Y}\
				-pointsize 12\
				-annotate  +${NOTE_X}+${NOTE_Y} "'Forcast for ${FORECASTTIME}${FORECASTDATE}  Published ${PUBLISHTIME}'" \
				$OUTPUTFILE ;
			fi
		done
	else
		echo "[CROP] No ${PARAM}${CURRENTLEVEL} plots available available"
	fi
}

if [[ $LOWESTLEVEL == $STARTLEVEL ]]; then
	CURRENTLEVEL=""
	echo "[CROP] cropping $PARAM for $REGION $DOMAIN $FOCUS a single variable"
	dohours
else
	CURRENTLEVEL=$STARTLEVEL
	echo "[CROP] cropping $PARAM for $REGION $DOMAIN $FOCUS at levels starting from $CURRENTLEVEL to $LOWESTLEVEL"
	
	# p CURRENTLEVEL where terrain starts to show up.
	# plevel to hold the wblmaxmin CURRENTLEVEL
	wblmaxmin=$(( ${LOWESTLEVEL}+10 ))
	tenmwind=$(( ${LOWESTLEVEL}+20 ))
	blcloudpct=$(( ${LOWESTLEVEL}+30 ))
	wstar_bsratio=$(( ${LOWESTLEVEL}+40 ))
	rain1=$(( ${LOWESTLEVEL}+50 ))
	echo "[CROP] the nonlevel parameter will be at wblmaxmin = $wblmaxmin"
	echo "[CROP] the tenmwind  parameter will be at press = $tenmwind"
	echo "[CROP] the blcloudpct  parameter will be at press = $blcloudpct"
	echo "[CROP] the w*bs map will be at press = $wstar_bsratio"
	# CURRENTLEVEL to start loop with -- handle odd ones like 700 and 500 separately
	# DOMAIN of the REGION that has the FOCUS contained in it

	## make sure it covers the actual lowest CURRENTLEVEL you want 
	while [ ${CURRENTLEVEL} -lt ${wblmaxmin} ]
	do
		echo "[CROP] doing continuous levels $CURRENTLEVEL"
		dohours 
		let CURRENTLEVEL=$(( ${CURRENTLEVEL}+10 ))
	done

	if [[ ${STARTLEVEL} -le 860 ]]; then
		CURRENTLEVEL=500
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours 
		CURRENTLEVEL=670
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
		CURRENTLEVEL=700
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
		CURRENTLEVEL=725
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
		CURRENTLEVEL=750
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
		CURRENTLEVEL=775
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
		CURRENTLEVEL=800
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
		CURRENTLEVEL=825
		echo "[CROP] For the $DOMAIN doing CURRENTLEVEL for $FOCUS at ${CURRENTLEVEL}mb"
		dohours
	fi

	CURRENTLEVEL=$wblmaxmin
	echo "[CROP] Cropping wblmaxmin plots"
	if ls ${SOURCEDIR}/wblmaxmin.curr.*lst.${DOMAIN}.png &>/dev/null;
	then
		for HOUR in 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 ;
		do
			FORECASTTIME=$(echo $HOUR |sed  -e 's#\([0-2][0-9]\)\(00\)#\1:\2 #g' )
			INPUTFILE=${SOURCEDIR}/wblmaxmin.curr.${HOUR}lst.${DOMAIN}.png
			OUTPUTFILE=${OUTPUTDIR}/${FOCUS}press${wblmaxmin}.${HOUR}.png
			if [ -f $INPUTFILE ]; then
				echo "[CROP] $(basename $INPUTFILE)-->$(basename $OUTPUTFILE) for HOUR:$HOUR, LEVEL:$CURRENTLEVEL"
				convert $INPUTFILE -crop ${WIDTH}x${HEIGHT}+${X}+${Y} \
				-pointsize 12 \
				-annotate +${NOTE_X}+${NOTE_Y} "'Forcast for ${FORECASTTIME}${FORECASTDATE} Published ${PUBLISHTIME}'" \
				$OUTPUTFILE
			fi
		done
	else
		echo "****Error: [CROP] No wblmaxmin plots available for $DOMAIN"
	fi

	##################################################3
	CURRENTLEVEL=$tenmwind
	echo "[CROP] Cropping tenmwind plots"

	if ls ${SOURCEDIR}/tenmwind.curr.*lst.${DOMAIN}.png &>/dev/null;
	then
		if [[  ${FOCUS} == "ebey" || ${FOCUS} == "sanjuan" || ${FOCUS} == "blan" ]]
		then
			FORECASTDATE=""
			FORECASTTIME=""
		fi

		for HOUR in 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 ; 
		do
			FORECASTTIME=$(echo $HOUR |sed  -e 's#\([0-2][0-9]\)\(00\)#\1:\2 #g')
			INPUTFILE=${SOURCEDIR}/tenmwind.curr.${HOUR}lst.${DOMAIN}.png
			OUTPUTFILE=${OUTPUTDIR}/${FOCUS}press${tenmwind}.${HOUR}.png
			if [ -f $INPUTFILE ]; then
				echo "[CROP] $(basename $INPUTFILE)-->$(basename $OUTPUTFILE) for HOUR:$HOUR, LEVEL:$CURRENTLEVEL"
				convert $INPUTFILE -crop ${WIDTH}x${HEIGHT}+${X}+${Y} \
				-pointsize 12 \
				-annotate  +${NOTE_X}+${NOTE_Y}  "Forecast for ${FORECASTTIME}${FORECASTDATE}  Published ${PUBLISHTIME}" \
				$OUTPUTFILE
			fi
		done
	else
		echo "****Error: [CROP] No tenmwind plots available for $DOMAIN"
	fi

	## -pointsize 12 -annotate  +${NOTE_X}+${NOTE_Y}  ${FORECASTDATE} \
	## tenmwind will already have a datestamp from RASP results_output.hook but only on the far left not for east or tiger or fraser
	##################################################
	CURRENTLEVEL=$blcloudpct
	echo "[CROP] Cropping blcloudpct plots"

	if ls ${SOURCEDIR}/blcloudpct.curr.*lst.${DOMAIN}.png &>/dev/null;
	then
		for HOUR in 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 ;
		do
			FORECASTTIME=$(echo $HOUR |sed  -e 's#\([0-2][0-9]\)\(00\)#\1:\2 #g')
			INPUTFILE=${SOURCEDIR}/blcloudpct.curr.${HOUR}lst.${DOMAIN}.png
			OUTPUTFILE=${OUTPUTDIR}/${FOCUS}press${blcloudpct}.${HOUR}.png
			if [ -f $INPUTFILE ]; then
				echo "[CROP] $(basename $INPUTFILE)-->$(basename $OUTPUTFILE) for HOUR:$HOUR, LEVEL:$CURRENTLEVEL"
				convert $INPUTFILE -crop ${WIDTH}x${HEIGHT}+${X}+${Y} \
				-pointsize 12 \
				-annotate  +${NOTE_X}+${NOTE_Y}  "Forecast for ${FORECASTTIME}${FORECASTDATE}  Published ${PUBLISHTIME}" \
				$OUTPUTFILE
			fi
		done
	else
		echo "****Error: [CROP] No blcloudpct plots available for $DOMAIN"
	fi
	
	#############################################################################
	CURRENTLEVEL=$wstar_bsratio
	echo "[CROP] Cropping wstar_bsratio plots"

	if ls ${SOURCEDIR}/wstar_bsratio.curr.*lst.${DOMAIN}.png &>/dev/null;
	then
		for HOUR in 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 ;
		do
			FORECASTTIME=$(echo $HOUR |sed  -e 's#\([0-2][0-9]\)\(00\)#\1:\2 #g')
			INPUTFILE=${SOURCEDIR}/wstar_bsratio.curr.${HOUR}lst.${DOMAIN}.png
			OUTPUTFILE=${OUTPUTDIR}/${FOCUS}press${wstar_bsratio}.${HOUR}.png
			if [ -f $INPUTFILE ]; then
				echo "[CROP] $(basename $INPUTFILE)-->$(basename $OUTPUTFILE) for HOUR:$HOUR, LEVEL:$CURRENTLEVEL"
				convert $INPUTFILE -crop ${WIDTH}x${HEIGHT}+${X}+${Y} \
				-pointsize 12 \
				-annotate +${NOTE_X}+${NOTE_Y} "Forecast for ${FORECASTTIME}${FORECASTDATE}  Published ${PUBLISHTIME}" \
				${OUTPUTDIR}/${FOCUS}press${wstar_bsratio}.${HOUR}.png
			fi
		done
	else
		echo "****Error: [CROP] No wstar_bsratio plots available for $DOMAIN"
	fi
	
	#############################################################################
	CURRENTLEVEL=$rain1
	echo "[CROP] Cropping rain1 plots"

	if ls ${SOURCEDIR}/rain1.curr.*lst.${DOMAIN}.png &>/dev/null;
	then
		for HOUR in 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 ;
		do
			FORECASTTIME=$(echo $HOUR |sed  -e 's#\([0-2][0-9]\)\(00\)#\1:\2 #g')
			INPUTFILE=${SOURCEDIR}/wstar_bsratio.curr.${HOUR}lst.${DOMAIN}.png
			OUTPUTFILE=${OUTPUTDIR}/${FOCUS}press${rain1}.${HOUR}.png
			if [ -f $INPUTFILE ]; then
				echo "[CROP] $(basename $INPUTFILE)-->$(basename $OUTPUTFILE) for HOUR:$HOUR, LEVEL:$CURRENTLEVEL"
				convert $INPUTFILE -crop ${WIDTH}x${HEIGHT}+${X}+${Y} \
				-pointsize 12 -annotate  +${NOTE_X}+${NOTE_Y}  "Forecast for ${FORECASTTIME}${FORECASTDATE}  Published ${PUBLISHTIME}" \
				${OUTPUTDIR}/${FOCUS}press${rain1}.${HOUR}.png
			fi
		done
	else
		echo "****Error: [CROP] No rain1 plots available for $DOMAIN"
	fi
fi

echo "[CROP] Uploading files"
for INPUTFILE in $OUTPUTDIR/*.png; do
	$WXTOFLY_UTIL/upload_queue_add.sh $INPUTFILE html/${FOCUS} "CROP"
done
