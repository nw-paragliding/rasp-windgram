#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

#add WXTOFLY dirs with libs to ld.config
print_default "Creating ld config file"

CONF_NAME="wxtofly.conf"
TMP_FILE="/tmp/$CONF_NAME"

echo "# wxtofly/rasp default configuration" >$TMP_FILE

#here are 32-bit libs for several old utilities
echo "$BASEDIR/UTIL/LIB" >>$TMP_FILE

#64-bit NCL libs for plotting
echo "$BASEDIR/WRF/NCL/LIB" >>$TMP_FILE

if ! (sudo cp -f $TMP_FILE "/etc/ld.so.conf.d/$CONF_NAME");
then
	print_error "Unable to create ld conf file /etc/ld.so.conf.d/$CONF_NAME"
	exit -1
fi

#run ldconfig
if ! (sudo ldconfig)
then
	print_error "ldconfig failed"
	exit -1
fi

print_default "ldconfig complete"
