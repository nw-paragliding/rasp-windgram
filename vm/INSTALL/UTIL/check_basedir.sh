#!/bin/bash
source $(dirname $0)/output_util.sh

if [ -z $BASEDIR ]; then
	print_error "BASEDIR variable not defined"
	exit -1
fi

if [ ! -d $BASEDIR ]; then
	print_error "$BASEDIR does not exist"
	exit -1
fi
