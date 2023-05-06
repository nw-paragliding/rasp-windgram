#!/bin/bash

#prints the full path of site list csv for given region

REGION=${1^^}
REGION=${REGION/-WINDOW/}
REGION=$(echo $REGION | sed "s/\+[0-9]//")

case $REGION in
	PNW|TIGER|FRASER)
		echo $WXTOFLY_CONFIG/sites_pnw.csv;;
	PNWRAT)
		echo $WXTOFLY_CONFIG/sites_pnwrat.csv;;
	*)
		>&2 echo "Invalid region"
		exit -1;;
esac
