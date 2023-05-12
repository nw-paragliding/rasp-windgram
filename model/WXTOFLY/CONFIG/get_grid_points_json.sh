#!/bin/bash

if [ -z $BASEDIR ]; then
	echo "****Error: BASEDIR variable not defined"
	exit
fi

CSV_FILE=$WXTOFLY_CONFIG/sites.csv
if [ ! -e $CSV_FILE ]
then
	echo "****Error: CSV file $CSV_FILE not found"
	exit -1
fi

function get_grid_latlon {

	IJ=$(perl $BASEDIR/RASP/UTIL/latlon2ij.PL $REGION $GRID $LAT $LON )

	read -r I J <<<$IJ
	NI=$(printf %0.f "$I")
	NJ=$(printf %0.f "$J")
	
	LATLON=$(perl $BASEDIR/RASP/UTIL/ij2latlon.PL $REGION $GRID $NI $NJ )
}

#{
#"test":{
#	"d2":{
#	  "latlon": { "lat":11, "lon":11 },
#	  "ij": { "i":11, "j":11 }
#	},
#	"w2":{
#	  "latlon": { "lat":11, "lon":11 },
#	  "ij": { "i":11, "j":11 }
#	}
#},
#}

FIRST=1
HEADER=1
echo "{"
#!!!IMPORTANT - make sure the CSV has \n on the last line otherwise will not be read
while IFS=',' read -r STATE AREA SITE LAT LON REGION DOMAIN; do

	if [ $HEADER == 1 ]
	then
		HEADER=0
		continue
	fi
	
	DOMAIN=$(echo $DOMAIN | sed -e "s/[^[:print:]]//g")

	if [ $FIRST == 1 ]
	then
		FIRST=0
	else
		echo ","
	fi
	
	echo "\"$SITE\":{"
	GRID="d2"
	echo "  \"$GRID\":{"
	get_grid_latlon
	read -r GRID_LAT GRID_LOT <<<$LATLON
	echo "    \"region\": \"$REGION\","
	echo "    \"latlon\":{ \"lat\":$GRID_LAT, \"lon\":$GRID_LOT },"
	echo "    \"ij\":{ \"i\":$I, \"j\":$J },"
	echo "    \"nij\":{ \"ni\":$NI, \"nj\":$NJ }"

	if [ $DOMAIN != $REGION ]
	then
		GRID="w2"
    	echo "  },"
    	echo "  \"$GRID\":{"
		DOMAIN=${DOMAIN/-WINDOW/}
		get_grid_latlon
		read -r GRID_LAT GRID_LOT <<<$LATLON
     	echo "    \"region\": \"$REGION\","
		echo "    \"latlon\":{ \"lat\":$GRID_LAT, \"lon\":$GRID_LOT },"
		echo "    \"ij\":{ \"i\":$I, \"j\":$J },"
		echo "    \"nij\":{ \"ni\":$NI, \"nj\":$NJ }"
	fi
   	echo "  }"
   	echo "}"
	
done < $CSV_FILE

echo "}"

