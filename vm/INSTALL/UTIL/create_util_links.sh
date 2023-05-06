#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh

echo "Creating link to Perl..."
perldir=$(which perl)
if [[ $perldir != "/usr/bin/perl" ]]; then
	sudo ln -sf $perldir /usr/bin/perl
	if [[ $? -eq 0 ]]; then
		print_ok "Link created successfully"
		echo "/usr/bin/perl -> $(readlink -f /usr/bin/perl)"
	else
		print_error "Failed to create link"
		exit -1
	fi
else
	print_ok "Perl is already installed in $perldir"
fi

echo "Creating link to netcdf directory ..."
netcdfdir=$(dirname $(which ncdump))
sudo ln -sf $netcdfdir /usr/local/netcdf
if [[ $? -eq 0 ]]; then
	print_ok "Link created successfully"
	echo "/usr/local/netcdf -> $(readlink -f /usr/local/netcdf)"
else
	print_error "Failed to create link"
	exit -1
fi
	
echo "Creating link to zip ..."
zippath=$(which zip)
ln -sf $zippath $BASEDIR/UTIL/zip
if [[ $? -eq 0 ]]; then
	print_ok "Link created successfully"
	echo "$BASEDIR/UTIL/zip -> $(readlink -f $BASEDIR/UTIL/zip)"
else
	print_error "Failed to create link"
	exit -1
fi

echo "Creating link to gzip ..."
gzippath=$(which gzip)
ln -sf $gzippath $BASEDIR/UTIL/gzip
if [[ $? -eq 0 ]]; then
	print_ok "Link created successfully"
	echo "$BASEDIR/UTIL/gzip -> $(readlink -f $BASEDIR/UTIL/gzip)"
else
	print_error "Failed to create link"
	exit -1
fi

echo "Creating link to curl ..."
curlpath=$(which curl)
ln -sf $curlpath $BASEDIR/UTIL/curl
if [[ $? -eq 0 ]]; then
	print_ok "Link created successfully"
	echo "$BASEDIR/UTIL/curl -> $(readlink -f $BASEDIR/UTIL/curl)"
else
	print_error "Failed to create link"
	exit -1
fi

echo "Creating link to convert ..."
convertpath=$(which convert)
ln -sf $convertpath $BASEDIR/UTIL/convert
if [[ $? -eq 0 ]]; then
	print_ok "Link created successfully"
	echo "$BASEDIR/UTIL/convert -> $(readlink -f $BASEDIR/UTIL/convert)"
else
	print_error "Failed to create link"
	exit -1
fi

echo "Creating links in RASP/RUN/UTIL ..."
ln -sf ../../../UTIL/convert $BASEDIR/RASP/RUN/UTIL/convert
ln -sf ../../../UTIL/ctrans $BASEDIR/RASP/RUN/UTIL/ctrans
ln -sf ../../../UTIL/curl $BASEDIR/RASP/RUN/UTIL/curl
ln -sf ../../../UTIL/zip $BASEDIR/RASP/RUN/UTIL/zip
ln -sf ../../../UTIL/gzip $BASEDIR/RASP/RUN/UTIL/gzip