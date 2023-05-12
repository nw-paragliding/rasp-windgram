#!/bin/bash
SCRIPT_DIR=$(dirname $0)

INSTALL_UTIL_DIR=$SCRIPT_DIR/INSTALL/UTIL
if [ ! -d $INSTALL_UTIL_DIR ]
then
	echo "****Error: Install util dir $INSTALL_UTIL_DIR not found"
	exit -1
fi

source $INSTALL_UTIL_DIR/output_util.sh

if [ -z $1 ];
then
	print_error "BASEDIR argument not specified"
	exit -1
else
	export BASEDIR=${1%/}
fi
if [ ! -d $BASEDIR ];
then
	if ! (mkdir -p $BASEDIR);
	then
		print_error "Unable to create BASEDIR $BASEDIR"
		exit -1
	fi
fi

echo ""
print_yellow  "Updating WXTOFLY"
print_default "----------------"
echo ""
print_default "BASEDIR=$BASEDIR"
echo ""

#copy files from remote location
if ! (bash $INSTALL_UTIL_DIR/copy_files.sh "$SCRIPT_DIR" );
then
	exit
fi

bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/WXTOFLY/wxtofly.env
bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/rasp.env
bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/WRF/wrfsi/config_paths
bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/WRF/wrfsi/data/static
bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/WRF/wrfsi/domains
bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/WRF/wrfsi/extdata/static
bash $INSTALL_UTIL_DIR/fix_basedir.sh $BASEDIR/WRF/wrfsi/templates

if [ -e "$BASEDIR/WXTOFLY/CONFIG/$(hostname)/run.conf" ]
then
	cp -f "$BASEDIR/WXTOFLY/CONFIG/$(hostname)/run.conf" "$BASEDIR/WXTOFLY/CONFIG/run.conf"
fi

echo ""
print_yellow  "Update complete"
echo ""
