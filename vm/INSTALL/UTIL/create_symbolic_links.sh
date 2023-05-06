#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

print_magenta "Creating symbol links ..."

function create_symbolic_link() {

	SRC=$1

	print_default "$2 -> $1"
	
	if [ ! -e $SRC ];
	then
		print_error "Link target $SRC doen't exist"
		exit -1
	fi
	
	if [ -z $2 ];
	then
		print_error "Link path not specified"
		exit -1
	fi
	
	if ln -sf $1 $2; then
		print_ok "ok"
	else
		print_error "Failed to create link"
		exit -1
	fi
}

##############################################
print_cyan "Creating links in UTIL ..."
create_symbolic_link $BASEDIR/UTIL/NCARG/bin/ctrans $BASEDIR/UTIL/ctrans
create_symbolic_link $BASEDIR/UTIL/NCARG/bin/idt $BASEDIR/UTIL/idt
create_symbolic_link $BASEDIR/UTIL/NCARG/bin/ncl $BASEDIR/UTIL/ncl


##############################################
print_cyan "Creating links in RASP/RUN/UTIL ..."
create_symbolic_link $BASEDIR/UTIL/convert $BASEDIR/RASP/RUN/UTIL/convert
create_symbolic_link $BASEDIR/UTIL/ctrans $BASEDIR/RASP/RUN/UTIL/ctrans
create_symbolic_link $BASEDIR/UTIL/curl $BASEDIR/RASP/RUN/UTIL/curl
create_symbolic_link $BASEDIR/UTIL/gzip $BASEDIR/RASP/RUN/UTIL/gzip
create_symbolic_link $BASEDIR/UTIL/zip $BASEDIR/RASP/RUN/UTIL/zip


##############################################
print_cyan "Creating WRFSI link in WRF ..."
create_symbolic_link $BASEDIR/WRF/wrfsi $BASEDIR/WRF/WRFSI

##############################################
print_cyan "Creating ncl link in WRF/NCL ..."
create_symbolic_link $BASEDIR/UTIL/NCARG/bin/ncl $BASEDIR/WRF/NCL/ncl

##############################################
print_cyan "Creating links in WRF/WRFV2/run ..."
create_symbolic_link $BASEDIR/WRF/WRFV2/main/ndown.exe $BASEDIR/WRF/WRFV2/run/ndown.exe
create_symbolic_link $BASEDIR/WRF/WRFV2/main/real.exe $BASEDIR/WRF/WRFV2/run/real.exe
create_symbolic_link $BASEDIR/WRF/WRFV2/main/wrf.exe $BASEDIR/WRF/WRFV2/run/wrf.exe

##############################################
print_cyan "Creating links in WRF/WRFV2/RASP/em_real_linksonly ..."
create_symbolic_link $BASEDIR/WRF/WRFV2/main/ndown.exe $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/ndown.exe
create_symbolic_link $BASEDIR/WRF/WRFV2/main/real.exe $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/real.exe
create_symbolic_link $BASEDIR/WRF/WRFV2/main/wrf.exe $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/wrf.exe

create_symbolic_link $BASEDIR/WRF/WRFV2/run/ETAMPNEW_DATA $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/ETAMPNEW_DATA
create_symbolic_link $BASEDIR/WRF/WRFV2/run/GENPARM.TBL $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/GENPARM.TBL
create_symbolic_link $BASEDIR/WRF/WRFV2/run/gribmap.txt $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/gribmap.txt
create_symbolic_link $BASEDIR/WRF/WRFV2/run/LANDUSE.TBL $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/LANDUSE.TBL
create_symbolic_link $BASEDIR/WRF/WRFV2/run/README.namelist $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/README.namelist
create_symbolic_link $BASEDIR/WRF/WRFV2/run/RRTM_DATA $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/RRTM_DATA
create_symbolic_link $BASEDIR/WRF/WRFV2/run/SOILPARM.TBL $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/SOILPARM.TBL
create_symbolic_link $BASEDIR/WRF/WRFV2/run/tr49t67 $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/tr49t67
create_symbolic_link $BASEDIR/WRF/WRFV2/run/tr49t85 $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/tr49t85
create_symbolic_link $BASEDIR/WRF/WRFV2/run/tr67t85 $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/tr67t85
create_symbolic_link $BASEDIR/WRF/WRFV2/run/VEGPARM.TBL $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/VEGPARM.TBL

##############################################
print_cyan "Creating links in WRF/wrfsi ..."
create_symbolic_link $BASEDIR/WRF/wrfsi/domains $BASEDIR/WRF/wrfsi/DOMAINS

##############################################
print_cyan "Creating links in WRF/wrfsi/GRIB ..."
create_symbolic_link $BASEDIR/RASP/RUN/AVN/GRIB $BASEDIR/WRF/wrfsi/GRIB/AVN
create_symbolic_link $BASEDIR/RASP/RUN/ETA/GRIB $BASEDIR/WRF/wrfsi/GRIB/ETA
create_symbolic_link $BASEDIR/RASP/RUN/GFS/GRIB $BASEDIR/WRF/wrfsi/GRIB/GFS
create_symbolic_link $BASEDIR/RASP/RUN/RUCH/GRIB $BASEDIR/WRF/wrfsi/GRIB/RUCH
