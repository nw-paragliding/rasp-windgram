#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

print_cyan "Looking for run configuration for this machine"
echo "Hostname: $(hostname)"

CONFIG_DIR="$BASEDIR/WXTOFLY/CONFIG"
if [ ! -d $CONFIG_DIR ];
then
	print_error "$CONFIG_DIR does not exist"
	exit -1
fi

CONFIG_FILE=${CONFIG_DIR}"/"$(hostname)"/run.conf"

if [ -e $CONFIG_FILE ];
then
	print_yellow "Found machine config $CONFIG_FILE"
	if ! (cp -f "$CONFIG_FILE" "$CONFIG_DIR/run.conf")
	then
		print_error "Error copying config file to $CONFIG_DIR"
		exit -1
	fi
	print_default "Config file copied to $CONFIG_DIR"
else
	print_yellow "Config not available"
fi

