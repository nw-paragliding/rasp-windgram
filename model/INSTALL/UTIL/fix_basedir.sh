#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

if [ -z $1 ]
then
	print_error "No path argument specified"
	exit -1
fi
FIX_PATH=$1
if [ ! -e $FIX_PATH ]
then
	print_error "$FIX_PATH does not exit"
	exit -1
fi

print_default "Fixing BASEDIR in $FIX_PATH"

for FILE in $( find $FIX_PATH -type f ); do
	if grep -q "[BASEDIR]" "$FILE"; then
		print_default "$FILE"
		perl -pi -w -e "\$bdir = \"$BASEDIR\"; s/\[BASEDIR\]/\$bdir/g;" $FILE
		if [ $? != 0 ] 
		then
			print_error "Unable to modify file $FILE"
			exit -1
		fi
	fi
	
done

