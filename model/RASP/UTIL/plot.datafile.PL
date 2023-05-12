#! /usr/bin/perl  -w

#ifnot1argument: 
if ( $#ARGV < 0 || $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Plot data file(s)  to png file(s) in current (or optionally specified) directory \n";
print "Usage #1: plot.datafile.pl <flags> datafiledirectory(full|local) grid time <parameter list> \n";
print "Usage #2: plot.datafile.pl <flags> datafilename(full|local) <parameter list> \n";
print "          region,time extracted from filename \n";
#
print "Flags: <-x=X11> <-f=FixedColor> <-c min,max,step=Contours> <-g 512x512=Size> <-D directory=Output> <-k=>KeepNcgmFile> <-R REGIONXYZ=>Region> \n";
print "  NOT for sounding, press.level, or slice \n";
print "  (imagename is parametername.dayid.timelst.gridid.png - default dayid=current) \n";
print "  (output to current directory if no -D flag- latter useful if 80 char full filepath limit exceeded!) \n";
print "  (tries to extract region from datafiledirectory, -R option needed if errs) \n";
print "eg: (from plot.datafile.pl directory) plot.datafile.pl \$BASEDIR/RASP/SAVE/PANOCHE/2007/20070211 w2 1300 wstar \n";
print "eg: (from archive file directory) \$BASEDIR/RASP/UTIL/plot.datafile.pl . d2 1500 wstar sfctemp \n";
exit 0; }
###############################################################################
  ### for cgi use taint checking option -T
  ### FOR VISUAL DEBUGGER:  /usr/bin/perl -d:ptkdb example.pl
  ### FOR DEBUG MODE: run with -d flag 
  ###    i debug mode, set package name + local variables so X,V don't show "main" variables, ie:
  # package Main; local ($a,$b,...);
  ### To restrict unsafe constructs (vars,refs,subs)
  ###    vars requires variables to be declared with "my" or fully qualified or imported
  ###    refs generates error if symbolic references uses instead of hard refs
  ###    subs requires subroutines to be predeclared
  #    use strict;
  ### To provide aliases for buit-in punctuation variables (p403)
use English;
  ### for non-buffered STDOUT,STDERR ouput:
select STDERR; $|=1;
select STDOUT; $|=1;   #must be last select
  #old  use FileHandle; STDOUT->autoflush(1);  # or autoflush HANDLE EXPR (needs "use FileHandle;")
  ### to append new line to each print record:     $\="\n"; #($OUTPUT_RECORD_SEPARATOR)
  ### for error statements with subroutine traceback
use Carp ();
local $SIG{__WARN__} = \&Carp::cluck;
  ### To enable verbose diagnostics:
  #   use diagnostics;
###############################################################################

$program = 'plot.datafile' ;

### MODIFIED FROM plot.wrffilie.pl
### only for "current" data files

### ********** UNFINISHED **********
### TESTED ARGUMENTS: -x
### PRODUCES ONLY ncgm files not PNG
### DOES PRODUCE ncgm FILES USING "plot.datafile.pl ~/DRJACK/RASP/SAVE/GREATBRITAIN/2007/20070211 1500 d2 wstar sfctemp"

###### SET DIRECTORIES
  ### SET BASE DIRECTORY for local "DRJACK" directory setup, based on location of this program
  if( $0 =~ m|^/| ) { ( $SCRIPTDIR = "${0}" ) =~ s|/[^/]*$|| ; }
  else              { ( $SCRIPTDIR = "$ENV{'PWD'}/${0}" ) =~ s|[\./]*/[^/]*$|| ; }
  ( $BASEDIR = $SCRIPTDIR ) =~ s|/[^/]*/[^/]*$|| ;
  #old  $BASEDIR = "${HOME}/DRJACK" ;
  ### SET NCL DIRECTORY
  $NCL_DIR = "${BASEDIR}/WRF/NCL/" ;
  ### asp utilities directory - including copy,plot programs & overlay,gif files
  $UTILDIR = "${BASEDIR}/UTIL";
  ### ImageMagick convert program (should include LZW compressions if loop created)
  $CONVERT = "${UTILDIR}/convert";
  ### USE SEPARATE CALL TO NCARG CTRANS so can mix versions if need be
  $CTRANS = "${UTILDIR}/ctrans";
  ##### ENVIRONMENTAL PARAMS NEEDED FOR NCAR GRAPHICS (CTRANS)
  ### *NB* ON SM THIS IS NCL-ONLY 
  $ENV{'NCARG_ROOT'} = "${UTILDIR}/NCARG";
  ### NEED FULL PATH TO NCL PLOTTING EXECUTIBLE
  $NCLEXE = "$ENV{'NCARG_ROOT'}/bin/ncl";

###### SET NCL FILE TO USE - ITS OUTPUT PARAMS MUST MATCH PARAM LIST HERE !!!
 #normal: 
 $RASP_NCLFILE = "blipmap.ncl" ;
 #test:  $RASP_NCLFILE = "test.ncl" ;

### LPRINT >0 FOR DEBUG PRINT
$LPRINT = 0 ;
#4test: $LPRINT = 1 ;

###### SET DEFAULT ARGUMENT PARAMETERS
### default imagesize 
  $imagesize = '800x800';

##################################################################

### INITALIZATION
  $localsoarday = 'curr.'; 
### treat unknown variables 

### PARSE OPTIONAL FLAG(S) 
  local ( $opt_f, $opt_k, $opt_x ) ;
  use Getopt::Std ;
  getopts('xfkc:g:D:R:');
  ### treat optional X11 output argument - "zero" fed in as character to over-ride normal environmental-variable-triggered write-to-file
  if( $opt_x ) { $LOUT = 'zero' ; }
  else         { $LOUT = 3 ; }
  ### treat optional "geometry" argument
  if( $opt_g ) { $imagesize = $opt_g; }
  ### treat optional "image directory" argument
  if( $opt_D )
  { 
    $OUTDIR = $opt_D;
    ### '.' means use $PWD (must expand so dont use ncl run directory)
    if( $OUTDIR eq '.' ) { $OUTDIR = $ENV{'PWD'} ;}
  }
  ### treat optional "regionname" argument
  if( $opt_R ) { $REGIONNAME = $opt_R; }
  ### treat optional "fixed color" argument
  if( $opt_f )
  { $CONTOURS = "fixed"; }
  else
  { $CONTOURS = "nonfixed"; }
  ### specified contouring overrides a "fixed color" argument
  if( $opt_c )
  { $CONTOURS = "$opt_c"; }

  ### PARSE ARGUMENTS

  ### PARSE FIRST ARG INTO DATADIR - and dummyfilename if file
  ### DETERMINE WHETHER FIRST ARG IS DIRECTORY,FILE,NEITHER

  $ARG0 = $ARGV[0] ;
  if ( $ARG0 =~ m|^~/(.*)$| )
  { $ARG0 = $ENV{HOME}/${1} ; }
  elsif ( $ARG0 =~ m|^\./(.*)$| )
  { $ARG0 = $ENV{HOME}/${1} ; }

  if( -d $ARGV[0] )
  {
    if( $ARG0 =~ m|^/| )
    { 
      $argdir = $ARG0 ;
    }
    elsif( $ARG0 eq '.' )
    { 
      ## must expand so dont use ncl run directory
      $argdir = $ENV{PWD} ;
    }
    else
    { die "*** $program ERROR EXIT: arg1 dir parse error"; }
  }
  elsif( -f "$ARGV[0]" || -f "${ARGV[0]}.zip" )
  {
    if( $ARG0 =~ m|(^.*)/(.*)$| )
    { 
      $argdir = $1 ;
      $argfilename = $2 ; 
    }
    else
    { 
      $argdir = $ENV{PWD} ;
      $argfilename = $ARGV[0] ; 
    }
  }
  else
  { die "*** $program ERROR EXIT: arg1 directory/file not found"; }

### convert $argdir into full path $DATADIR
### ensure $DATADIR does not have trailing slash
  ( $DATADIR = ${argdir} ) =~ s|/$|| ; 

  ### set default date - do NOT use curr since that would overwrite normal RASP-produced plots
  $DATEID = 'current';
  ### DETERMINE REGION FROM DATADIR (unless set by flag)
  ### "smart" search for REGIONXYZ within path
  @subdirs = split( /\//,$DATADIR ) ;
  if( ! $opt_R )
  {
    ### if html directory, use up directory
    if( $subdirs[$#subdirs] eq 'FCST' ) 
    {
      $kregionsubdir = $#subdirs -1 ;
      $REGIONNAME = $subdirs[$kregionsubdir] ;
     }
    ### if run directory, use current directory
    elsif( $subdirs[$#subdirs-2] eq 'RUN' &&  $subdirs[$#subdirs-1] eq 'OUT' ) 
    { 
      $kregionsubdir = $#subdirs ;
      $REGIONNAME = $subdirs[$kregionsubdir] ;
      $yyyy = $1 ;
      $mm = $2 ;
      $dd = $3 ;
    }
    ### if save directory, use up-up directory
    elsif( $subdirs[$#subdirs-3] eq 'SAVE' ) 
    { 
      $kregionsubdir = $#subdirs -2 ;
      $REGIONNAME = $subdirs[$kregionsubdir] ;
      ### DETERMINE RDAY,MONTH,YEAR FROM DATADIR
      if( $subdirs[${kregionsubdir}+2] =~ m|([0-9][0-9][0-9][0-9])([0-9][0-9])([0-9][0-9])| ) 
      {
        $yyyy = $1 ;
        $mm = $2 ;
        $dd = $3 ;
        $DATEID = $yyyy . $mm . $dd ;
      }
      else
      { die "*** $program ERROR EXIT: year,month,day not parsed from DATADIR kregionsubdir = $DATADIR $kregionsubdir"; }
    }
    ### if old-style save directory, use up directory
    elsif( $subdirs[$#subdirs-2] eq 'SAVE' ) 
    { 
      $kregionsubdir = $#subdirs -1 ;
      $REGIONNAME = $subdirs[$kregionsubdir] ;
      ### DETERMINE RDAY,MONTH,YEAR FROM DATADIR
      if( $subdirs[${kregionsubdir}+1] =~ m|([0-9][0-9][0-9][0-9])([0-9][0-9])([0-9][0-9])| ) 
      {
        $yyyy = $1 ;
        $mm = $2 ;
        $dd = $3 ;
        $DATEID = $yyyy . $mm . $dd ;
      }
      else
      { die "*** $program ERROR EXIT: year,month,day not parsed from DATADIR kregionsubdir = $DATADIR $kregionsubdir"; }
    }
    else
   { die "*** $program ERROR EXIT: REGIONNAME not parsed from DATADIR kregionsubdir = $DATADIR $kregionsubdir"; }
  }
     
  ### SET GRID, TIME, PARAMLIST  BASED ON ARG/FILENAME
  if( -d $ARGV[0] )
  {
    $GRID = $ARGV[1] ;
    $TIME = $ARGV[2] ;
    $PARAMLIST = join ':', @ARGV[ 3 .. $#ARGV ] ;
  }
  elsif( -f $ARGV[0] )
  {
    if( $argfilename =~ m|^([^\.]*)\.${localsoarday}([^\.]*)lst\.([wd123]*)\.data| )
    { 
      $PARAMLIST = join ':', $1, @ARGV[ 1 .. $#ARGV ] ;
      $GRID = $3 ;
      $TIME = $2 ;
    }
    else
    { die "*** $program ERROR EXIT: GRID,TIME not parsed from argfilename= $argfilename"; }
  }
  @params = split /:/, $PARAMLIST ;

  ### SET INFOFILENAME - look upward to find first directory containing a terrain file
  if( $GRID eq 'd1' )
  { $terrainfilename = "terrain.g1.data" ; }
  elsif( $GRID eq 'd2' )
  { $terrainfilename = "terrain.g2.data" ; }
  elsif( $GRID eq 'w2' )
  { $terrainfilename = "terrain.g3.data" ; }
  else
  { die "*** $program ERROR EXIT: GRID does not have expected value = $GRID"; }

  ( $dummyfilename = $terrainfilename ) =~ s/terrain/dummy/ ;
  $INFOFILENAME = '' ;
  for ( $iup=0; $iup<=2; $iup++ )
  { 
    $testdir = join '/', @subdirs[ 0 .. ($#subdirs-$iup) ] ;
    if( -f "${testdir}/${terrainfilename}" ) 
    { $INFOFILENAME = "${testdir}/${dummyfilename}" ; }
  }
  if( $INFOFILENAME eq '' )
  { die "*** $program ERROR EXIT: did not find INFOFILENAME= $terrainfilename"; }

  ### SET DATAFILENAME 
  $dummydatafilename = "dummy." . $localsoarday . $TIME . "lst." . $GRID . ".data" ;

  ### SET OUTPUT DIRECTORY - normally use current directory but can be set by flag
  if( ! defined $OUTDIR )
  {
    $OUTDIR = $ENV{PWD} ;
  }

  #4test: print "DATADIR $DATADIR \n";       
  #4test: print "REGIONNAME= $REGIONNAME \n";       
  #4test: print "GRI7D= $GRID \n";       
  #4test: print "TIME= $TIME \n";       
  #4test: print "PARAMLIST= $PARAMLIST \n";       
  #4test: print "INFOFILENAME= $INFOFILENAME \n";       
  #4test: print "OUTDIR= $OUTDIR \n";       
  #4test: print "TIME= $TIME \n";       
  #4test: print "DUMMYDATAFILENAME= $dummydatafilename \n";       



### TEST FOR EXISTENCE OF DATA FILES
### must replace dummy string with parameter name
### TEST OUTDIR since total length of ncgm file written must be <= 80 chars (and also tmp.bkgwks.ncgm written)
###   (error gives ncar warning messageS ala "Error in opngks_: could not open ..." & "GKS:GESC warning...") 
for( $iparam=0; $iparam<=$#params; $iparam++ )
{ 
  ### do tests on base filename 
  ( $testfilename = "${dummydatafilename}" ) =~ s|dummy|$params[$iparam]| ;
  #old ( $testfilename = "${DATADIR}/${dummydatafilename}" ) =~ s|dummy|$params[$iparam]| ;
  ### treat composite case (only test for first file)
  if ( $testfilename =~ m|^([^_]*)_[^\.]*(.*)$| )
  { $testfilename = $1 . $2 ; }
  #old ### must treat mask case separately (only test for first file)
  #old if ( $testfilename =~ m|^(.*)mask\.(.*)$| )
  #old { $testfilename = $1 . '.'. $2 ; }
  ### now make it a full filename 
  $testfilename = "${DATADIR}/${testfilename}" ;
  if( ( ! -f ${testfilename} ) && ( ! -f "${testfilename}.zip" ) )
  { die "*** $program ERROR STOP: non-existent data file $testfilename";  }
  #old if( ( ! -f ${testfilename} ) && ( ! -f "${testfilename}.zip" ) ) { die "*** $program ERROR STOP: non-existent data file $testfilename"; }
  if( length("${OUTDIR}/{params[$iparam]}.ncgm") > 79 ) { die "*** $program ERROR STOP: output directory name too long (ncl has 80 char limit on full filepathname)"; }
}

### SET ENVIRONMENTAL PARAMETERS PASSEED TO NCL PLOTTING PROGRAM
### units read from file for region set by ENV_NCL_REGIONNAME
 $ENV{'ENV_NCL_ID'}           = "${DATEID}.${TIME}lst.${GRID}" ;
 #4test:  $ENV{'ENV_NCL_FILENAME'}     = "/home/glendeni/DRJACK/RASP/SAVE/GREATBRITAIN/2007/20070211/dummy.curr.1500lst.d2.data" ;
 $ENV{'ENV_NCL_FILENAME'}     = "${DATADIR}/${dummydatafilename}" ;
 $ENV{'ENV_NCL_REGIONNAME'}   = $REGIONNAME ;
 $ENV{'ENV_NCL_OUTDIR'}       = $OUTDIR ;
 $ENV{'ENV_NCL_PARAMS'}       = $PARAMLIST ;
 $ENV{'ENV_NCL_INFOFILENAME'} =  $INFOFILENAME ; 
 $ENV{'ENV_NCL_CONTOURS'}     = $CONTOURS ;
### ********** END OF TEST PLOT FROM RASP ARCHIVE FILES  *********

### DEBUG PRINTS
if( $LPRINT > 0 )
{
 print "DATAFILENAME= $ENV{'ENV_NCL_FILENAME'} \n";       
 print "REGIONNAME= $ENV{'ENV_NCL_REGIONNAME'} \n";     
 print "OUTDIR= $ENV{'ENV_NCL_OUTDIR'} \n";
 print "PARAMLIST= $ENV{'ENV_NCL_PARAMS'} \n";
 print "INFOFILENAME= $ENV{'ENV_NCL_INFOFILENAME'} \n";
 print "CONTOURS=  $ENV{'ENV_NCL_CONTOURS'} \n";
 die "DO DEBUG EXIT when LPRINT>0" ; 
}

### PRINT INFO
  print "Plot for region= $REGIONNAME grid= $GRID time= $TIME params= $PARAMLIST \n";
  print "  from datadirectory= $DATADIR \n";
  print "  using NCL executable= $RASP_NCLFILE \n";

### TEST FILENAME LENGTHS due to NCL 80 character limit on output filename
### TEST BASED ON ncgmname which is one character longer than png name !
foreach $param (@params)
{
  $ncgmname = "${param}.${DATEID}.${TIME}lst.${GRID}.ncgm" ;
  $testlength = length("${OUTDIR}/$ncgmname") ;
  if( $testlength > 80 ) { die "*** $program ERROR STOP: output directory name too long - ${OUTDIR}/${ncgmname} = $testlength chars - ncl has 80 char limit on full filepathname"; }
}
$testlength = length("${OUTDIR}/tmp.bkgwks.ncgm") ;
if( $testlength > 80 ) { die "*** $program ERROR STOP: output directory name too long - ${OUTDIR}/tmp.bkgwks.ncgm = $testlength chars - ncl has 80 char limit on full filepathname"; }


### RUN PLOTTING SCRIPT
 $nclout = `cd $NCL_DIR ; $NCLEXE $RASP_NCLFILE \'LOUT=\"${LOUT}\"\' `;
print "NCLOUT= $nclout \n";

if( $LOUT eq '0' ||  $LOUT eq 'zero' ) 
{ exit; }

### PROCESS ANY NCGM FILES PRODUCED

$nconversion = 0 ;
foreach $param (@params)
{

  $ncgmname = "${param}.${DATEID}.${TIME}lst.${GRID}.ncgm" ;
  #old $ncgmname = "${param}.ncgm" ;
  $pngname  = "${param}.${DATEID}.${TIME}lst.${GRID}.png" ;
  #old $pngname = sprintf "%s.%s%slst.%s.png", $param,$localsoarday,$TIME,$GRID ;

  ### skip if non-existent or stub ncgm file (needed for domains with no soundings)
  if( -f "${OUTDIR}/$ncgmname" && -s "$ENV{'ENV_NCL_OUTDIR'}/$ncgmname" > 4000 )
  {

    ### ensure removal of old sun and png file to prevent inadvertent use
    `rm -f $OUTDIR/tmp.rasp.sun $OUTDIR/$pngname`;

    ### convert individual ncgm files into png images
    ### NCAR CTRANS CONVERTS METAFILE TO SQUARE BITMAP
    # defaultsize=512x512 - alter using "-resolution widthxheight"
    chomp( my $ctransout = `$CTRANS -res $imagesize -d sun -outfile $OUTDIR/tmp.rasp.sun $ENV{'ENV_NCL_OUTDIR'}/$ncgmname 2>&1` );
    #old chomp( my $ctransout = `NCARG_ROOT=$NCARG_ROOT; export NCARG_ROOT ; $CTRANS -res $imagesize -d sun -outfile $OUTDIR/tmp.rasp.sun $ENV{'ENV_NCL_OUTDIR'}/$ncgmname 2>&1` );

    ### convert converts square bitmap to (sometimes) non-square png
    chomp( my $convertout = `$CONVERT $OUTDIR/tmp.rasp.sun $OUTDIR/$pngname 2>&1` );

    if( -f "${OUTDIR}/$pngname" && -s "${OUTDIR}/$pngname" > 4000 )
    {
      print "IMAGE CREATED: ${OUTDIR}/$pngname  \n" ;
    }
    else
    { 
      $nconversion++ ;
      print "*** $program ERROR: bad ncgm->gif conversion for ${OUTDIR}/$param \n CTRANSOUT= $ctransout CONVERTOUT= $convertout";
    }

  }
  else
  {
    $nconversion++ ;
     print "*** $program ERROR: missing or bad ncgm file = ${OUTDIR}/$ncgmname \n";
  }

  ### CLEANUP of sun and ncgm file
  `rm -f $OUTDIR/tmp.rasp.sun $OUTDIR/tmp.*.ncgm 2>/dev/null`;
  if( ! defined $opt_k )
  {
    `rm -f ${OUTDIR}/$ncgmname 2>/dev/null`;
  }

}

if( $nconversion != 0 )
{ die "*** $program ERROR EXIT: gif creation failure - nconversion= $nconversion"; }


###########################################################################################
###########################################################################################
