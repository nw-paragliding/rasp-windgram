#!/bin/csh -f

if ($# != 5) then
  echo "5 args required: cyc int endtime type ext_dataroot"
  exit
endif
set cyc=${1}
set int=${3}
set endtime=${2}
set type=${4}
set ext_dataroot=${5}
set pathname="$ext_dataroot/GRIB"

set tvalsave=0

set ROOT=$INSTALLROOT

if ($type == 104) then
set bname=eta.t${cyc}z.grbgrd
set EXE=$ROOT/bin/grib_prep_etatiles.exe
endif

if ($type == 212) then
set bname=eta.t${cyc}z.awip3d
set EXE=$ROOT/exe/dgeta2model.exe
endif

if ($type == 221) then
set bname=eta.t${cyc}z.awip32
set EXE=$ROOT/exe/dgeta2model.exe
endif

if ($type == tile || $type == tile218) then
#set EXE=$ROOT/exe/dgeta2model_tileuni.exe
set EXE=$ROOT/bin/grib_prep_etatiles.exe
endif

if ($type == avn) then
set bname=gblav.t${cyc}z.pgrbf
set EXE=$ROOT/exe/dgeta2model_gbl.exe
endif

if ($type == wafs) then
set bname=wafs.T${cyc}Z.F
set EXE=$ROOT/exe/dgeta2model_wafs.exe
endif

if ($type == lmbc) then
set bname=lmbc_0
# set EXE=$ROOT/exe/dgeta2model_nest.exe
set EXE=$ROOT/exe/dgeta2model.exe
endif

if ($type == latlon) then
set bname=latlon_0
# set EXE=$ROOT/exe/dgeta2model_nest.exe
set EXE=$ROOT/exe/dgeta2model.exe
endif

echo for $cyc data will handle data from 00 to $endtime at $int hour intervals

while ($tvalsave <= $endtime)

if ($tvalsave <= 9) then
set tval=0${tvalsave}
else
set tval=${tvalsave}
endif

if ($type == 104 || $type == 212 || $type == 221) then
set filename=${bname}${tval}.tm00
endif

if ($type == avn || $type == wafs) then
set filename=${bname}${tval}
endif

if ($type == lmbc || $type == latlon) then
set filename=${bname}${tval}
endif

if ($type != tile && $type != tile218) then
set GRIBFILE=${pathname}/${filename}
echo " Begin processing for "$filename
else
set GRIBFILE="not"
endif

set OUTDIR="$ext_dataroot/extprd"

# Degrib data.

if ( -e $GRIBFILE || $type == "tile" || $type == "tile218" ) then
echo " "
else
echo " "$GRIBFILE" grib file not found."
exit 0
endif

# Convert degribbed data to unformatted format for local area model use.

echo " "
echo " Start degrib to formatted data conversion process..."
 
if ($type != wafs && $type != tile && $type != tile218) then
$EXE << endin
$GRIBFILE
$OUTDIR
endin
endif

if ($type == wafs) then
$EXE << endin
$GRIBFILE
$OUTDIR
37
38
39
40
41
42
43
44
-9
endin
endif

if ($type == tile || $type == tile218 ) then
$EXE << endin
`cat $pathname/tile.list.${tval}`
9999
$OUTDIR
endin
endif
 
# Cleanup.

if ($tvalsave <= $endtime) then
@ tvalsave += $int
endif

end

exit 0
