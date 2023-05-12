#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

print_magenta "Setting up WXTOFLY domains"

print_cyan "Copy links from $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly"
#Create links in $BASEDIR/WRF/WRFV2/RASP/REGIONXYZ
for DOMAIN_DIR in $(find $BASEDIR/WRF/WRFV2/RASP/ -type d ! -name "em_real_linksonly");
do
	print_default "Copy links to $DOMAIN_DIR"
	if ! (cp -d $BASEDIR/WRF/WRFV2/RASP/em_real_linksonly/* $DOMAIN_DIR)
	then
		print_error "Unable to copy links"
		exit -1
	fi
done

function create_link() {
	SRC=$1
	print_default "Creating link $2-->$SRC"
	
	if [ ! -e $SRC ];
	then
		print_error "Link target $SRC doesn't exist"
		exit -1
	fi
	
	if [ -z $2 ];
	then
		print_error "Link path not specified"
		exit -1
	fi
	
	if ! (ln -sf $SRC $2); then
		print_error "Failed to create link"
		exit -1
	fi
}

##############################################
print_cyan "Creating namelist.template links..."

function create_namelist_template_links() {
	create_link $BASEDIR/WRF/WRFV2/RASP/$1/namelist.template $BASEDIR/WRF/WRFV2/RASP/${1}+1/namelist.template
	create_link $BASEDIR/WRF/WRFV2/RASP/$1/namelist.template $BASEDIR/WRF/WRFV2/RASP/${1}+2/namelist.template
	create_link $BASEDIR/WRF/WRFV2/RASP/$1/namelist.template $BASEDIR/WRF/WRFV2/RASP/${1}+3/namelist.template
}

create_namelist_template_links PNW
create_namelist_template_links FRASER
create_namelist_template_links TIGER
create_namelist_template_links FT_EBEY
create_namelist_template_links PNWRAT

##############################################
print_cyan "Creating +N domains links..."

function create_plus_n_cdl_links() {
	DOMAIN=$1
	N=$2
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/cdl/wrfsi.cdl $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/cdl/wrfsi.cdl
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/cdl/wrfsi.d01.cdl $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/cdl/wrfsi.d01.cdl
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/cdl/wrfsi.d02.cdl $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/cdl/wrfsi.d02.cdl
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/cdl/wrfsi.d03.cdl $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/cdl/wrfsi.d03.cdl
}

function create_all_plus_n_cdl_links() {
	create_plus_n_cdl_links $1 "1"
	create_plus_n_cdl_links $1 "2"
	create_plus_n_cdl_links $1 "3"
}

create_all_plus_n_cdl_links PNW
create_all_plus_n_cdl_links FRASER
create_all_plus_n_cdl_links TIGER
create_all_plus_n_cdl_links FT_EBEY
create_all_plus_n_cdl_links PNWRAT

function create_plus_n_static_data_links() {
	DOMAIN=$1
	N=$2
	FILE_NAME=$3
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/$FILE_NAME.d01.dat $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/$FILE_NAME.d01.dat
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/$FILE_NAME.d02.dat $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/$FILE_NAME.d02.dat
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/$FILE_NAME.d03.dat $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/$FILE_NAME.d03.dat
}
function create_plus_n_static_wrf_links() {
	DOMAIN=$1
	N=$2
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/created_wrf_static.dat $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/created_wrf_static.dat

	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/wrfstatic_d01 $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/wrfstatic_d01
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/wrfstatic_d02 $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/wrfstatic_d02
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/wrfstatic_d03 $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/wrfstatic_d03

	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/static.wrfsi.d01 $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/static.wrfsi.d01
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/static.wrfsi.d02 $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/static.wrfsi.d02
	create_link $BASEDIR/WRF/wrfsi/domains/$DOMAIN/static/static.wrfsi.d03 $BASEDIR/WRF/wrfsi/domains/${DOMAIN}+$N/static/static.wrfsi.d03
}

function create_all_plus_n_static_data_links() {
	create_plus_n_static_data_links $1 "1" $2
	create_plus_n_static_data_links $1 "2" $2
	create_plus_n_static_data_links $1 "3" $2
}

function create_all_plus_n_static_wrf_links() {
	create_plus_n_static_wrf_links $1 "1"
	create_plus_n_static_wrf_links $1 "2"
	create_plus_n_static_wrf_links $1 "3"
}

function create_all_plus_n_static_links() {
	create_all_plus_n_static_wrf_links $1
	create_all_plus_n_static_data_links $1 "latlon2d"
	create_all_plus_n_static_data_links $1 "latlon2d-mass"
	create_all_plus_n_static_data_links $1 "latlon"
	create_all_plus_n_static_data_links $1 "latlon-mass"
	create_all_plus_n_static_data_links $1 "topo"
	create_all_plus_n_static_data_links $1 "topo-mass"
	create_all_plus_n_static_data_links $1 "topography"
	create_all_plus_n_static_data_links $1 "topography-mass"
}

create_all_plus_n_static_links PNW
create_all_plus_n_static_links FRASER
create_all_plus_n_static_links TIGER
create_all_plus_n_static_links FT_EBEY
create_all_plus_n_static_links PNWRAT

##############################################
print_cyan "Creating WINDOW domains links  ..."

function create_window_domain_links() {
	FILE_NAME=$1
	create_link $DOMAIN_DIR/static/$FILE_NAME.d02.dat $WINDOW_DIR/static/$FILE_NAME.d01.dat
	create_link $DOMAIN_DIR/static/$FILE_NAME.d03.dat $WINDOW_DIR/static/$FILE_NAME.d02.dat
}


#Create link from WINDOW domains to non-WINDOW domains
#under $BASEDIR/WRF/wrfsi/domains

#created_wrf_static.dat -> static/created_wrf_static.dat
#latlon2d.d01.dat -> static/latlon2d.d02.dat
#latlon2d.d02.dat -> static/latlon2d.d03.dat
#latlon2d-mass.d01.dat -> static/latlon2d-mass.d02.dat
#latlon2d-mass.d02.dat -> static/latlon2d-mass.d03.dat
#latlon.d01.dat -> static/latlon.d02.dat
#latlon.d02.dat -> static/latlon.d03.dat
#latlon-mass.d01.dat -> static/latlon-mass.d02.dat
#latlon-mass.d02.dat -> static/latlon-mass.d03.dat
#static.wrfsi.d01 -> static/static.wrfsi.d02
#static.wrfsi.d02 -> static/static.wrfsi.d03
#topo.d01.dat -> static/topo.d02.dat
#topo.d02.dat -> static/topo.d03.dat
#topography.d01.dat -> static/topography.d02.dat
#topography.d02.dat -> static/topography.d03.dat
#topography-mass.d01.dat -> static/topography-mass.d02.dat
#topography-mass.d02.dat -> static/topography-mass.d03.dat
#topo-mass.d01.dat -> static/topo-mass.d02.dat
#topo-mass.d02.dat -> static/topo-mass.d03.dat
#wrfstatic_d01 -> static/wrfstatic_d02
#wrfstatic_d02 -> static/wrfstatic_d03

for WINDOW_DIR in $(ls -d $BASEDIR/WRF/wrfsi/domains/*-WINDOW); 
do
	DOMAIN_DIR=${WINDOW_DIR/-WINDOW/}
	if [ ! -e $DOMAIN_DIR ]
	then
		print_error "$DOMAIN_DIR not found"
		exit -1
	fi
	
	create_link $DOMAIN_DIR/cdl/wrfsi.cdl $WINDOW_DIR/cdl/wrfsi.cdl
	
	create_link $DOMAIN_DIR/cdl/wrfsi.d02.cdl $WINDOW_DIR/cdl/wrfsi.d01.cdl
	create_link $DOMAIN_DIR/cdl/wrfsi.d03.cdl $WINDOW_DIR/cdl/wrfsi.d02.cdl

	create_link $DOMAIN_DIR/static/created_wrf_static.dat $WINDOW_DIR/static/created_wrf_static.dat
	
	create_link $DOMAIN_DIR/static/wrfstatic_d02 $WINDOW_DIR/static/wrfstatic_d01
	create_link $DOMAIN_DIR/static/wrfstatic_d03 $WINDOW_DIR/static/wrfstatic_d02

	create_link $DOMAIN_DIR/static/static.wrfsi.d02 $WINDOW_DIR/static/static.wrfsi.d01
	create_link $DOMAIN_DIR/static/static.wrfsi.d03 $WINDOW_DIR/static/static.wrfsi.d02

	create_window_domain_links "latlon"
	create_window_domain_links "latlon-mass"

	create_window_domain_links "latlon2d"
	create_window_domain_links "latlon2d-mass"
	
	create_window_domain_links "topo"
	create_window_domain_links "topo-mass"
	
	create_window_domain_links "topography"
	create_window_domain_links "topography-mass"
done

print_default "WXTOFLY domains set up"
