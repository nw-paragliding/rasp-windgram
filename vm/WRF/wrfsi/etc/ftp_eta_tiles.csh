#! /bin/csh -f

if (${#argv} != 5 ) then
  echo "5 args required:  cycle lasthr interval type ext_dataroot"
  exit
endif
set cycle=$1
set hrlast=$2
set int=$3
set type=$4
set ext_dataroot=$5

set gribdir="$ext_dataroot/GRIB"
if ( ! -d "$ext_dataroot/GRIB" ) then
  echo "Making $ext_dataroot/GRIB"
  mkdir -p $ext_dataroot/GRIB
endif

set tilelistfile="$ext_dataroot/static/tilelist.txt"
#################################
#
#set tilelist="15 16 24 25"
#
#################################

set ymd=`date +%Y%m%d`

set hr=00
set hrsave=00

if ($type == 104 || $type == 212 || $type == 221 || $type == tile || \
		$type == tile218) then
set mod=eta
endif

if ($type == avn || $type == wafs) then
set mod=avn
endif

cd $gribdir
set pathname=`pwd`
rm tile.list.*

echo for the ${1}Z cycle getting data to $hrlast hr at a $int hr interval

while ($hrsave <= $hrlast)
if ($hrsave < 10 && $hrsave != 00) set hr=0${hrsave}
if ($hrsave >= 10) set hr=${hrsave}

if ($type == 104) then
set fget=eta.t${cycle}z.grbgrd${hr}.tm00
set dir=/pub/data/nccf/com/${mod}/prod/${mod}.$ymd
endif

if ($type == 212) then
set fget=eta.t${cycle}z.awip3d${hr}.tm00
set dir=/pub/data/nccf/com/${mod}/prod/${mod}.$ymd
endif

if ($type == 221) then
set fget=eta.t${cycle}z.awip32${hr}.tm00
set dir=/pub/data/nccf/com/${mod}/prod/${mod}.$ymd
endif

if ($type == tile) then
source $tilelistfile
set fget=""
set fbase=eta.t${cycle}z.awip32${hr}
set dir=/pub/data/nccf/com/${mod}/prod/${mod}.$ymd/tiles.t${cycle}z
endif

if ($type == tile218) then
source $tilelistfile
set fget=""
set fbase=eta.t${cycle}z.awip218${hr}
set dir=/pub/data/nccf/com/${mod}/prod/${mod}.$ymd/tiles.t${cycle}z
endif

if ($type == avn) then
set fget=gblav.t${cycle}z.pgrbf${hr}
set dir=/pub/data/nccf/com/${mod}/prod/${mod}.$ymd
endif

if ($type == lmbc) then
set fget=${type}_0${hr}
endif

if ($type == latlon) then
set fget=${type}_0${hr}
endif

if ($type == wafs) then
set fget=xtrn.wfsavn${cycle}${hr}
set dir=/pub/data/nccf/pcom/${mod}
endif

if ($type != tile && $type != tile218 && $type != lmbc && $type != latlon) then
echo attempting to get /com/${mod}/prod/${mod}.$ymd/$fget
endif

if ($type == wafs) then
ftp -in ftpprd.ncep.noaa.gov << endftp
user anonymous `whoami`@1`hostname`
binary
cd $dir
mget ${fget}*
bye
endftp
endif

if ($type == tile || $type == tile218) then

foreach tc (`echo $tilelist`)

echo ${pathname}/$fbase.$tc >> tile.list.${hr}
/usr/bin/ncftpget -r 5 -t 120 ftpprd.ncep.noaa.gov $pathname $dir/$fbase.$tc
#ftp -in ftpprd.ncep.noaa.gov << endftp
#user anonymous `whoami`@`hostname`
#binary
#cd $dir
#get ${fbase}.$tc
#bye
#endftp

end

endif


if ($type != wafs && $type != lmbc && $type != latlon && $type != tile && \
		 $type != tile218) then

ftp -in ftpprd.ncep.noaa.gov << endftp
user anonymous `whoami`@`hostname`
binary
cd $dir
mget ${fget}
bye
endftp
endif

if ($type == lmbc || $type == latlon) then
cp ../../eta/runs/$fget .
endif

@ hrsave += $int

if ($type == wafs) then
if ( $hr == 12 || $hr == 18 || $hr == 24 || $hr == 30 ) then
cat xtrn.wfsavn${cycle}${hr}a.* xtrn.wfsavn${cycle}${hr}b.* \
		> wafs.T${cycle}Z.F${hr}
else
mv xtrn.wfsavn${cycle}${hr}* wafs.T${cycle}Z.F${hr}
endif
endif

end
