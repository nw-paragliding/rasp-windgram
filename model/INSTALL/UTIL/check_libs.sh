#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

#$(find $BASEDIR -executable -type f)
FILES="$BASEDIR/RASP/RUN/UTIL/cnvgrib
$BASEDIR/UTIL/NCARG/bin/ncl
$BASEDIR/UTIL/NCARG/bin/ctrans
$BASEDIR/UTIL/NCARG/bin/idt
$BASEDIR/WRF/WRFV2/main/wrf.exe
$BASEDIR/WRF/WRFV2/main/real.exe
$BASEDIR/WRF/WRFV2/main/ndown.exe
$BASEDIR/WRF/wrfsi/bin/grib_prep.exe
$BASEDIR/WRF/wrfsi/bin/gridgen_model.exe
$BASEDIR/WRF/wrfsi/bin/hinterp.exe
$BASEDIR/WRF/wrfsi/bin/staticpost.exe
$BASEDIR/WRF/wrfsi/bin/vinterp.exe
$BASEDIR/WRF/NCL/ncl_jack_fortran.so
$BASEDIR/WRF/NCL/wrf_user_fortran_util_0.so"

TEMP_OUTPUT=$(mktemp)
ERROR=0
CURRENT_DIR=$(pwd)
for FILE in $FILES; do

	if [ -L $FILE ]; then
		echo "$FILE -> $(readlink $FILE)"
		cd $(dirname $FILE)
		FILE=$(readlink $FILE)
	fi

	if [ ! -f $FILE ]; then
		print_error "Script error: $FILE not found"
		exit -1
	fi
	
	if [ -f $TEMP_OUTPUT ]; then
		rm $TEMP_OUTPUT
	fi
	
	echo $FILE
	ldd $FILE | grep "not found" >> $TEMP_OUTPUT

	if [ -s $TEMP_OUTPUT ]; then
		#echo $FILE
		file $FILE

		print_error "Missing libs"
		ERROR=-1
		cat $TEMP_OUTPUT
		if [ $LOGENABLED = true ]; then
			echo "Missing libs" >> $LOGFILE
			cat $TEMP_OUTPUT >> $LOGFILE
		fi
	else
		print_ok "Ok"
	fi	
	cd $CURRENT_DIR
done

if [ -f $TEMP_OUTPUT ]; then
	rm $TEMP_OUTPUT
fi

exit $ERROR
