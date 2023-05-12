#!/bin/bash

# converts sites.csv to json and uploads to the website

if [ -z $BASEDIR ]; then
	echo "****Error: BASEDIR variable not defined"
	exit
fi

SITES_JSON=$WXTOFLY_CONFIG/sites.json

$WXTOFLY_UTIL/csv2json.sh $WXTOFLY_CONFIG/sites.csv > $SITES_JSON

if [ ! -e $SITES_JSON ]
then
	echo "****Error: Sites JSON not created"
	exit -1
fi

if ! ($WXTOFLY_UTIL/upload.sh $SITES_JSON html/v2); then
	echo "****Error: Sites JSON not uploaded"
fi

echo "Sites JSON uploaded"

GRID_JSON=$WXTOFLY_CONFIG/grid.json

$WXTOFLY_CONFIG/get_grid_points_json.sh > $GRID_JSON

if [ ! -e $GRID_JSON ]
then
	echo "****Error: Grid JSON not created"
	exit -1
fi

if ! ($WXTOFLY_UTIL/upload.sh $GRID_JSON html/v2); then
	echo "****Error: Grid JSON not uploaded"
fi

echo "Grid JSON uploaded"