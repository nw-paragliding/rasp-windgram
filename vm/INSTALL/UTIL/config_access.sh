#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

print_default "Adding executable permissions"
find $BASEDIR/WXTOFLY -type f -name "*.sh" -exec chmod +x {} \;
chmod +x $BASEDIR/rasp.env
chmod +x $BASEDIR/WXTOFLY/wxtofly.env

find $BASEDIR -type f -name "*.pl" -exec chmod +x {} \;
find $BASEDIR -type f -name "*.PL" -exec chmod +x {} \;

