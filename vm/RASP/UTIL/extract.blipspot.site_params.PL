############################################################
### SITE DEPENDENT VARIABLES USED BY extract.blipspot.PL ###
###   (use separate file to avoid tar update overwrite)  ###
############################################################

### SET SITE DEPENDENT DEFAULT PARAMETERS
use File::Basename;
$BASEDIR = "$ENV{'BASEDIR'}";
$DATADIR = "$BASEDIR/RASP/HTML/${REGION}/FCST"; 

#this will construct timedolist array from available files	
@timedolist = ();

my @files=`ls $DATADIR/*.data`;
my $filename=basename($files[0]);

#blcloudpct.curr.0700lst.d2.data
($param, $curr, $time, $grid, $ext) = split /\./, $filename;

my $searchTime="$param.$curr.*.$grid.$ext";
@timedolist=();

@files=`ls $DATADIR/$searchTime`;
foreach $file (@files)
{
	$filename=basename($file);
	($param, $curr, $time) = split /\./, $filename;
	push @timedolist, $time;
}

if ( ${REGION} eq 'EBEY' )
{ 
	@paramdolist = ('tenmwinddir','sfcwind0spd','tenmwindspd','sfcwindspd','sfcwind2spd','wstar','wblmaxmin','zsfclcl','blcloudpct','sfcshf','sfctemp','sfcdewpt','mslpress','rain1'  ) ;
}
elsif ( ${REGION} eq 'NOOKSACK' )
{ 
	@paramdolist = ('tenmwinddir','sfcwindspd','wstar','wblmaxmin','hwcrit','hglider','bsratio','blwindspd','blwinddir','blwindshear','cape','zsfclcl','zblcldif','zblcl','blcloudpct','sfcshf','sfctemp','sfcdewpt','hbl','dbl','mslpress' ) ;
}
else  
{ 
	@paramdolist = ('tenmwinddir','sfcwind0spd','tenmwindspd','sfcwindspd','sfcwind2spd','wstar','wblmaxmin','hwcrit','dwcrit','hglider','bsratio','hbl','dbl','blwindspd','blwinddir','blwindshear','bltopwindspd','bltopwinddir','cape','zsfclcl','zblcldif','zblcl','blcloudpct','sfcshf','sfctemp','sfcdewpt','mslpress','rain1','bltopvariab' ) ;
} 


