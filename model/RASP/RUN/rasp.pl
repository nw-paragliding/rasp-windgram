#! /usr/bin/perl -w
###>>>>>>>>>>>> VERSION: $Revision: 2.136 $ $Date: 2008/09/15 00:27:34 $Z <<<<<<<<<<<<###
########## TO-DO: ######################################################
########################################################################
#########################################################################################
###  RASP (Regional Atmospheric Soaring Predictions) COMPUTER PROGRAM
###  Original Creator:  Dr. John W. (Jack) Glendening, Meterologist  2005
###  Script copyright 2005-2006  by Dr. John W. Glendening  All rights reserved.
###  External credits:
###    utilizes Weather Research and Forecasting (WRF) meteorological model
###    utilizes National Center for Atmospheric Research (NCAR) graphics
###    utilizes model output from the National Center for Environmental Prediction (NCEP)
#########################################################################################
### rasp.pl runs weather prediction model, producing soaring info from model output
### Written by Jack Glendening <glendening@drjack.info>, Jan 2005+
### Modified by Alan Crouse to support a 'parent' domain, supporting multiple d03 windows
### within the same d02 model, August 2009  additonal modifications tjo 2010
   if ( $#ARGV < 1 || $ARGV[0] eq '-?' ) {
  print "RASP:  \n";
  print "< \$1: => JOBARG (eg  ALL|PANOCHE|WILLIAMS|CANV|SW_SOOUTHAFRICA|GREATBRITAIN|REGIONXYZ) > \n";
  print "< \$2: =>               > \n";
  print "<    -t jday => test with no init,getgrib,ftpmail,save for specified julianday<_year> (0=today) \n";
  print "<    -T jday => test with no testsection modification - flags vary   > \n";
  print "<    -p jday => init+model for specified julianday<_year> (0=today) - lgetgrib=1,send=0 lsave=0 - output to terminal > \n";
  print "<    -P jday => init+model for specified julianday<_year> (0=today) - lgetgrib=1 - output to file > \n";
  print "<    -q jday => quick init (skip grib_prep) + model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  print "<    -Q jday => quick init (skip grib_prep) + model for specified julianday<_year> (0=today) - lgetgrib=0 - output to file > \n";
  print "<    -r jday => rerun model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  print "<    -R jday => rerun model for specified julianday<_year> (0=today) - lgetgrib= - output to file > \n";
  print "<    -b => batch with getgrib,init+modelrun,save but NO ftpmail        > \n";
  print "<    -m => batch with getgrib,init+modelrun,ftpmail=2(NOprev.day),save > \n";
  print "<    -M => batch with getgrib,init+modelrun,ftpmail,save               > \n";
  print "<    -n => ala -m but no getgrib > \n";
  print "<    -N => ala -M but no getgrib > \n";
  print "<    -w => run window from existing parent domain > \n";
  print "KILL SIGNALS:  STOP=-23  CONTINUE=-25  END(+final_processing)=-2 \n";
  exit 0; 
}
############## PROGRAM COPYRIGHT NOTICE #################################
##
##   PROGRAM COPYRIGHT NOTICE
##
##   RASP (Regional Atmospheric Soaring Predictions) COMPUTER PROGRAM
##   Version: $Revision: 2.136 $ $Date: 2008/09/15 00:27:34 $
##   Original Creator: Dr. John W. (Jack) Glendening, Meteorologist (drjack@drjack.info)
##   Copyright 2005-2006  by John W. Glendening   All rights reserved.
## 
## This program is at present NOT in the public domain and is intended
## to be utilized only by the copyright holder or those specifically
## designated by him to run local versions for regional forecasting.
## It is not be be used, copied, modified, or distributed without the
## written permission of the copyright holder.
##
## The copyright holder will not be liable for any direct, indirect, 
## or consequential damages arising out of any use of the program or
## documentation.
## 
## Title to copyright in this program and any associated documentation
## will at all times remain with copyright holder.
##
## However, in the event of the death of the original creator, this program
## and all RASP and BLIP programs, scripts, data and information are to be
## released under the terms of version 2 of the GNU General Public License.
## A copy of that license should be in the "gnu_gpl_license.txt" file,
## but a copy of the GNU General Public License can also be 
## obtained from the Free Software Foundation, Inc., 59 Temple Place -
## Suite 330, Boston, MA 02111-1307, USA, or, on-line at
## http://www.gnu.org/copyleft/gpl.html.
##
#########################################################################
#############################################################################
###################  USAGE NOTES  ###########################################
#############################################################################
#########  TO RUN "WINDOW-ONLY" (stage2) JOB  #####################
### MUST HAVE ALREADY RUN SUCCESSFUL STAGE1 ( REGIONXYZ) CASE 
###    since its output file needed for input to stage2
### SETUP JOB FILE rasp.run.parameters.REGIONXYZ-WINDOW ala rasp.run.parameters.REGIONXYZ
###    EXCEPT set $LRUN_WINDOW{REGIONXYZ}=1
### RUN ALA "rasp.pl REGIONXYZ-WINDOW -m" or "rasp.pl REGIONXYZ-WINDOW -q jjj" where jjj is that used for REGIONXYZ run
###    but no downloading done
### NOTE THAT COULD SET $LRUN_WINDOW{REGIONXYZ}=1 in rasp.run.parameters.REGIONXYZ and use,
###    but use of rasp.run.parameters.REGIONXYZ-WINDOW helps prevents confusion
###################################################################
#############################################################################
########## PROGRAMMING NOTES: ###########################################
##  BASIC DECISION: SHOULD JOB BASIS BE "ALL FORECASTS FOR SAME SOARING DAY" OR "ALL GRIB FILES ON SAME JULIAN DAY"
##                 here is latter primarily for historical reasons but former might be better
##  ASSUMES THAT WILL NEVER ASK FOR FILE WITH INIT(ANAL) TIME BEYOND CURRENT JULIAN DAY !
##  GRIB FILES GENERALLY TREATED INDEPENDENTLY, YET ARE ACTUALLY NEEDED IN SEPARATE GROUPINGS
#########################################################################
#############################################################################
###### forXItest: USE FOR RUNS ON XI
### FOR XI, SET $LMODELINIT=0 TO AVOID INITIALIZATION
### FOR XI, WHEN INITIALIZING ($LMODELINIT=1) WITHOUT DOWNLOAD ($LGETGRIB=0) MUST
### PRESENT AVAILBLE XI TEST INITIALIZATIONS
###  Run by modifying rasp.run.parameter.REGION variables as below, if necessary, then call with proper day ala "rasp.pl PANOCHE -q 92_2005" for RUCH
#############################################################################
###### TRACING INITIALIZATION ERRORS  eg "died ./wrfprep.pl line 693"
### CHECK FOR FTP ERROR
### CHECK GRIB PREP RESULTS:
##     in .../WRF/WRFSI/EXTDATA/log - in latest gp_RUCH.yyyymmddhh.log (only available for _last_ grib file processed) look for "Normal termination of program grib_prep"
##     in .../WRF/WRFSI/EXTDATA/extprd should have files ala RUCH:yyyy-mm-dd_hh 
### CHECK WRF PREP RESULTS:
##     in .../WRF/WRFSI/domains/REGIONXYZ/log - in latest yyyymmddhh.wrfprep look for "wrfprep.pl ended normally" - if not found, also look for error messages in other logs 
##     errors can be caused by non-matching (1) init.model as $GRIBFILE_MODEL & in a wrfsi.nl (2) $GRIBFILES_PER_FORECAST_PERIOD{REGION} & @{$GRIBFILE_DOLIST{REGION}} for init.model
#############################################################################
####### FOR DEBUG MODE: run with -d flag  (but not for neptune)
### In debug mode, set package name + local variables so X,V don't show "main" variables, ie:
### To enable verbose diagnostics (but not for CRAY):
### To restrict unsafe constructs (vars,refs,subs)
###    vars requires variables to be declared with "my" or fully qualified or imported
###    refs generates error if symbolic references uses instead of hard refs
###    subs requires subroutines to be predeclared
### To provide aliases for buit-in punctuation variables (p403)

use English;

####### FOR GRIB ARCHIVE RUN   GFS(1x1deg-180hrmax)/ETA(~11Mb-12km-60hrmax)/RUC(20km-12hrmax) archives at http://nomads.ncdc.noaa.gov/data.php
###     BUT ARCHIVE RUC CANNOT INIT (missing cloud/rain/ice/snow/graupel/soil/etc parameters)
###         with RUCH Vtable failed at wrfprep: hinterp log has zero length & with RUCP Vtable failed at wrfprep: hinterp log says "no valid landmask found!", no soil height interpolation, etc. and later fails
### download grib files for necessary date and times
###    e.g. "wget http://nomads.ncdc.noaa.gov/data/gfs-avn-hi/200602/20060219/gfs_3_20060219_1200_012.grb"
###    e.g. "wget http://nomads.ncdc.noaa.gov/data/meso-eta-hi/200602/20060219/nam_218_20060219_1200_012.grb"
### create links in GRIB directory to expected file names for all necessary times
###    e.g. "ln -s gfs_3_20060219_1200_012.grb gfs.t12z.pgrb2f12"
###    e.g. "ln -s nam_218_20060219_1200_012.grb nam.t12z.awip3d12.tm00"
### possbily create special rasp.run.parameters file for different $GRIBFILE_MODEL/$LRUN_WINDOW/%GRIBFILE_DOLIST
###    e.g. rasp.run.parameters.PANOCHE-TEST
### possibly move old output directory(s) to temporary name (so can easily save output directory with new name)
###    e.g. "mv PANOCHE PANOCHE-OLD" & "mv PANOCHE-WINDOW PANOCHE-WINDOW-OLD"
### run with julian date specification
###    e.g.  "rasp.pl PANOCHE-TEST -q 050_2006"
### possibly save output directory(s) with new name
###    e.g. "mv PANOCHE PANOCHE-19FEB2006" & "mv PANOCHE-WINDOW PANOCHE-WINDOW-19FEB2006"
###########  EXTERNAL PROGRAMS:  ########################################
  ## Unix Shell Commands:  echo, rm, cp, mv, date, grep, ps, sleep, ftp, Mail
  ## My Unix Scripts:      jdate2date
  ## Scripts for ftp file transfer (with password!):  gribftpget, ftp/cp,rasp.multiftp/cp,blipmap.ftp/cp2previousday curl
  ## Graphics programs:  ncl(NCARG), ctrans(NCARG), convert(ImageMagick)/imcopy(SDSC)
  ## Model: WRF preprocessing+run scripts
  ## Graphics scripts: plt_chars.pl(uses plt_chars.exe), no_blipmap_available.pl (uses no_blipmap_available.exe)
  ## Compresssion program:  gzip(GNU)/zip
  ## Required non-standard perl modules: Proc::Background
####################  ERROR MESSAGES  #####################################
  ##  UNMATCHED PARENS BETWEEN BACKSLASHS:  sh: -c: line 1: unexpected EOF while looking for matching `"' sh: -c: line 2: syntax error: unexpected end of file
  ##  nan IN PLOT DATA FILE (at data line 115): ERROR - lsli=-12 reading 2D data:  112 115
########## COMMENTED-OUT ALTERNATIVES #####################################
#################  NOTES  ##############################################
##########  PROCESSING INFO  ###########################################
### TIME STEP
### 2005-01-05: used dt=60s for first cases, but test with 2005-01-05-0Z+12h init went never-never-land after 45 iters so changed to dt=30s (non-hydro,rk=3) SM2.8Pentium=>~35min(40x49x30)
#########################################################################
### GRIB FILENAMES
  ## 32km ETA(NAM) (grid221) ~89Mb files on NCEP server http://nomads.ncep.noaa.gov
  ##   nam.tiiz.awip32pp.tm00.grib2 at directory pub/data/nccf/com/nam/prod/nam.YYYYMMDD 
  ## 40km ETA(NAM) (grid212) ~15Mb files on NCEP server http://nomads.ncep.noaa.gov
  ##   nam.tiiz.awip3dpp.tm00 at directory pub/data/nccf/com/nam/prod/nam.YYYYMMDD 
  ##   #eta-grib1 nam.tiiz.awip3dpp.tm00 at directory pub/data/nccf/com/nam/prod/nam.YYYYMMDD 
  ## ALTERNATE 40km ETA(NAM) files on NWS server  tgftp.nws.noaa.gov
  ##   fh.00pp_tl.press_gr.awip3d at directory SL.us008001/ST.opnl/MT.nam_CY.ii/RD.yyyymmdd/PT.grid_DF.gr1
  ## 20km(<-13km) FSL RUCH ~52Mb on server gsdftp.fsl.noaa.gov
  ##   yyjjjhh0000pp.grib at 13kmruc/maps_fcst20
  ##   #old-20km ~55Mb yyjjjhh0000pp.grib at 20kmruc/maps_fcst
  ## 13km FSL RUCH ~120Mb on server gsdftp.fsl.noaa.gov
  ##   yyjjjhh0000pp.grib at 13kmruc/maps_fcst
  ## GFSN = 0.5degx0.5deg GFS GRIB2 files on NCEP server  http://nomads.ncep.noaa.gov
  ##   gfs.t00z.pgrb2f00 at directory pub/data/nccf/com/gfs/prod/gfs.YYYYMMDDCC  (CC=cycle, eg 00)
  ##     levels= 1000,975,950,925,900,850,800,750,700,650,600,550,500,450,400,350,300,250,200,150,100,70,50,30,20,10 mb
  ##     289 variables
  ## *NO* ALTERNATE GFS 0.5degx0.5deg GFS GRIB2 files on NWS server   tgftp.nws.noaa.gov
  ##   (??  at directory SL.us008001/ST.opnl/MT.gfs_CY.ii/RD.20050218/PT.grid_DF.gr1)
  ## GFSA = LimitedArea 0.5degx0.5deg GFS GRIB1 files on NOMADS server 'http://nomad1.ncep.noaa.gov/cgi-bin/ftp2u_gfs0.5.sh
  ## AVN = LimitedArea 1degx1deg GFS GRIB files on NOMADS server  http://nomads.ncep.noaa.gov
  ##   grib1=gfs.t00z.pgrbf00 grib2=gfs.t00z.pgrb2f00 at directory pub/data/nccf/com/gfs/prod/gfs.YYYYMMDDCC  (CC=cycle, eg 00)
  ##     levels= 1000,975,950,925,900,850,800,750,700,650,600,550,500,450,400,350,300,250,200,150,100,70,50,30,20,10 mb
  ##     320 variables
  ## ALTERNATE AVN 1degx1deg GFS GRIB1 files on NWS server   tgftp.nws.noaa.gov
  ##   fh.00pp_tl.press_gr.onedeg at directory SL.us008001/ST.opnl/MT.gfs_CY.ii/RD.20050218/PT.grid_DF.gr1
##########  INSTALL NOTES  ###########################################
################### NAMES CONSIDERED ##################################
#########################################################################
######### SET DATA ###########
### perl modules needed
  use POSIX qw(mktime);
### TO ALLOW FLAGS IN waitpid
  use POSIX "sys_wait_h";
### for parallel ftping in background - see http://search.cpan.org/~bzajac/Proc-Background-1.08/lib/Proc/Background.pm
  use Proc::Background ;
###### SET PROCESS ID
  $RUNPID = $$ ;
###### SET PROGRAM NAME
  $program = $0;
  $program =~ s|$ENV{'PWD'}/||;
  $program  =~ s|\.pl$||;
###### SET BASIC DIRECTORIES
### SET BASE DIRECTORY for local "DRJACK" directory setup, based on location of this program
  if( $0 =~ m|^/| ) { ( $SCRIPTDIR = "${0}" ) =~ s|/[^/]*$|| ; }
  else              { ( $SCRIPTDIR = "$ENV{'PWD'}/${0}" ) =~ s|[\./]*/[^/]*$|| ; }
  ( $BASEDIR = $SCRIPTDIR ) =~ s|/[^/]*/[^/]*$|| ;
### SET RASP base directory
  $DIR = "$BASEDIR/RASP";
### run subdirectory - PRESENTLY HARDWIRED TO STATIC VALUE, NOT TO $JOBARG
  $RUNDIR = "${DIR}/RUN";

####### FIRST ARGUMENT IS JOBARG
### idea of JOBARG is distinguish/identify a job
### but due to simultaneous need of same grib file, CANNOT simulataneously run 2 same GRIBFILE_MODEL jobs even with different JOBARG
###    To allow separate jobs should use RUNDARG to set $RUNDIR BELOW (which also distinguishes curls from different JOBARG jobs)
###     which would separate everything by JOBARG _EXCEPT_ $SAVEDIR (so files would be saved to common directory)
###     BUT GRIB link in grib_prep.nl NOT separate so above not be sufficent to separate jobs
###     (once thought to have two jobs running each with different JOBARG )
###     (but would need to keep changing grib_prep.nl to keep grib file separate so not done)
## PRESENT THOUGHT IS THAT SHOULD PLAN TO JUST HAVE A SINGLE JOB RUNNING
## SO CAN NOW TREAT REGIONS BY PUTTING EACH INTO A SEPARATE THREAD/JOB
##      (this also allows a single grib get for all regions)
  $JOBARG = $ARGV[0];
  shift;
### REQUIRE JOBARG TO BE IN CAPS
  $JOBARG =~ tr/a-z/A-Z/;
## initialize control variables for multi nest runs
  $runmultinest = 0;  
  $existing_parent = " " ;
###tjo  print ("existing_parent initialized  \n");
#############################################
##########  OVERRIDE NORMAL CHOMP  ##########
### must be set here to avoid compile warning "jchomp() called too early to check prototype"
### but then edpsub macro cuts off lines above from narrowed region
sub jchomp(@)
### DELETES ENDING NEWLINE ALA REGULAR CHOMP
{
  if ( $_[0] =~ m/(^.*)\n$/ ) { $_[0] = $1; }
  return  ;
}
############################################
###############################################################################################
#################################  FLAGS  #####################################################
### LPRINT:     >0 output to std.out,  <0 output to file $program.printout
###             |$LPRINT|=4 for most output,  2=normal, 1=minimal,  0=none
### LGETGRIB:   0= skip grib get & prep
###             1= run grib_prep.pl for existing grib files
###             2= get new grib files at scheduled times
###             3= get new grib files via ls query
###            -1= grib file name specified
### LSEND:      0= images produced only in local "RASP/RUN/OUT" subdirectory
###             1= copy images to web directory using filenames pre-pended with "test"
###             2= copy images to web directory using normal filenames
###             -1,-2 => ftp images to remote server (NOT OPERATIONALLY TESTED)
###             3= also do firstofday processing (NOT IMPLEMENTED)
### LSAVE:      0= nosave 1= save plot data files 2= also save plot images 3=also save init files
### LMODELINIT: 1= do wrfsi initialization 0=none
### LMODELRUN:  2= run all  1= skip wrf.exe  0= no_run
################################################################################################
###### PARSE ARGUMENT AND SET FLAGS
  ## -t jday => test with testsection & no init,getgrib,degrib,ftpmail,save  for specified julianday<_year> (0=today)
  ## -T jday => test with no testsection <for specified julianday<_year> - flags vary
  ## -q jday => init+model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  ## -Q jday => init+model for specified julianday<_year> (0=today) - lgetgrib=0 - output to file > \n";
  ## -r jday => rerun model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  ## -R jday => rerun model for specified julianday<_year> (0=today) - lgetgrib=0 - output to file > \n";
  ## -b => batch with getgrib,modelrun,save but NO FTP/MAIL
  ## -m => batch with getgrib,modelrun,ftpmail,save but no firstofday processing       
  ## -M => batch with getgrib,modelrun,ftpmail,save and firstofday processing  
  ## -w => run second window from existing parent model    
  if ( $ARGV[0] eq '-t' )
  {
    $RUNTYPE = '-t';
    ###### INTENDED FOR XI RUNS 
    ###### MUST ALSO SETUP TEST PARAMETER SECTION
    ### LMODELINIT=0 INHIBITS MODEL INITIALIZATION
    $LMODELINIT = 0 ;
    $LMODELINIT = 1 ; 
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-T' )
  {
    $RUNTYPE = '-T';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 0; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-p' )
  {
    $RUNTYPE = '-p';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT get new files from website
    $LGETGRIB = 1;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-P' )
  {
    $RUNTYPE = '-P';
    ### TERMINAL print DEBUGS
    $LPRINT = -3;
    ### DONT get new files from website
    $LGETGRIB = 1;
    ### DONT/DO send ftp/mail 
    ### DONT/DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-q' || $ARGV[0] eq '-w' )
  {
    $RUNTYPE = '-q';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 && $ARGV[0] eq '-q' ) { die 'Must specifiy a julian date for this option'; }
    if  ( $ARGV[0] eq '-q' ) { $julianday_forced = $ARGV[1]; }
    else { $julianday_forced = $ARGV[2] ; }
    ####
    ####  Check for parent domain and copy wrfout files if -w option
    #####
    if ( $ARGV[0] eq '-w' )
    { 
	$runmultinest = 1;
      ### Get the parent domain name
      if  ( $#ARGV <0 ) { die 'Must specifiy an existing parent domain for this option'; }
      $existing_parent = $ARGV[1];
	  print ("existing_parent now set to: $existing_parent  \n");

      ### Check parent exists and copy required files
      if ( -s "$BASEDIR/WRF/WRFV2/RASP/${existing_parent}" )
      { 
        ## remove the old wrfoutfiles from the subnest domain so they don't accumulate tjo
	`rm $BASEDIR/WRF/WRFV2/RASP/${JOBARG}/wrfout_d0*` ;
        ### Copy wrfout_d0 files from earlier run of parent model
	  
        `cp $BASEDIR/WRF/WRFV2/RASP/${existing_parent}/wrfout_d0* $BASEDIR/WRF/WRFV2/RASP/${JOBARG}` ;
      }
      else
      { die 'Specified parent domain $BASEDIR/WRF/WRFV2/RASP/${existing_parent}  does not exist'; }
      ### Continue on
    }
  }
  elsif ( $ARGV[0] eq '-Q' )
  {
    $RUNTYPE = '-Q';
    ### TERMINAL print DEBUGS
    $LPRINT = -3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    ### DONT/DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-r' )
  {
    $RUNTYPE = '-r';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 0; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-R' )
  {
    $RUNTYPE = '-R';
    ### TERMINAL print DEBUGS
    $LPRINT = -3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    ### DONT/DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 0; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-b' )
  {
    $RUNTYPE = '-b';
    ### FILE print DEBUGs
    $LPRINT = -3;
    ### DO get new files from website
    $LGETGRIB = 2;
    ### NO  send ftp/mail !!!
    $LSEND = 0;
    ### DO save final info to storage file
    $LSAVE = 3;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
  }
  elsif ( $ARGV[0] eq '-m' || $ARGV[0] eq '-n' )
  { 
    $RUNTYPE = '-m';
    ### FILE print DEBUGs
    $LPRINT = -3;
    ### DO get new files from website
    if ( $ARGV[0] eq '-m'  )
      { $LGETGRIB = 2; }
    elsif ( $ARGV[0] eq '-n'  )
      { $LGETGRIB = 0; }
    ### FULL send ftp/mail but _dont_ create a "first" file
    $LSEND = 2;
    ### DO save final info to storage file
    $LSAVE = 3;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
  }
  elsif ( $ARGV[0] eq '-M' || $ARGV[0] eq '-N' )
  {
    $RUNTYPE = '-M';
    ### DO get new files from website
    if ( $ARGV[0] eq '-M'  )
    { $LGETGRIB = 2 ; }
    elsif ( $ARGV[0] eq '-N'  )
    { $LGETGRIB = 0; }
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### $LPRINT=-3 prints to output file
    $LPRINT = -3;
    ###!!!### SITE-SPECIFIC PARAMETER: $LSEND=2 copies images to web directory
    ### $LSEND=-2 ftp images to server specified in $UTILDIR/rasp.multiftp - must also modify that file appropriately (NOT OPERATIONALLY TESTED)
    ###!!!### SITE-SPECIFIC PARAMETER: $LSAVE=3 saves image files (a single forecast hour only) and initial condition files to a storage directory
    ### $LSAVE=0 inhibits all such saves, preserving disk space
    ### $LSAVE=1 saves images only, using much less disk space than $LSAVE=2
  }
### TREAT GRIB FILE INPUT CASE
### WARNING: IF RUN WHILE EXISTING JOB USING SAME JOBARG RUNNING, THIS WILL KILL THAT EXISTING JOB
### WARNING: WILL HAVE WRONG FORECAST PERIOD IF FILE FROM ONE CURRENT DAY RUN ON A DIFFERENT CURRENT DAY
  elsif ( $ARGV[0] !~ m|^-m| )
  { 
    $specifiedfilename = $ARGV[0] ;
    $RUNTYPE = '-m';
    ### FILE print DEBUGs
    $LPRINT = -3;
    ### do NOT get new files from website - -1 INDICATES THAT FILENAME IS SPECIFIED
    $LGETGRIB = -1;
    ### FULL send ftp/mail but _dont_ create a "first" file
    ### DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
  }
  else
  {
    print "$program ERROR EXIT: bad argument 1 = $RUNTYPE \n";
    exit 2;
  }
### AS SOON AS LPRINT IS SET, SET PRINTING FILEHANDLES
### ALL TEST OUTPUT SENT TO STDERR
### printfh used for perl print comands
### printpipe used for shell echo commands - no longer used normally, kept for possible test prints
### (output doesnt appear anywhere if use $PRINTPIPE = '';)
  if ( $LPRINT >=0 )
  {
    ### FOR $LPRINT>=0, FILE $PRINTFH,$PRINTPIPE PRINT TO TERMINAL
    ### FOR TEST PRINT STDOUT TO TERMINAL
    $printoutfilename = "&1";
    ### for child processes which must have an actual file to write to
    $childprintoutfilename = "${RUNDIR}/${program}.ftpchild_printout";
    $PRINTPIPE = ' 1>&2';
    $PRINTFH = 'STDOUT';
  }
  elsif ( $LPRINT <0 )
  {
    ### FOR $LPRINT<0, FILE HANDLE $PRINTFH,$PRINTPIPE PRINT TO A FILE
    ### NOW MAKE LPRINT POSTITIVE TO ALLOW SAME TESTS FOR DIFFERENT FILEHANDLES
    $LPRINT = abs( $LPRINT );
    $PRINTFH = 'FILEPRINT';
    ### set printout filename
    $printoutfilename = "${RUNDIR}/${program}.printout";
    `rm -f ${DIR}/$printoutfilename`;
    ### for child processes which must have an actual file to write to
    $childprintoutfilename = $printoutfilename ;
    open ($PRINTFH, ">>$printoutfilename");
    $PRINTPIPE = ">> $printoutfilename";
  }
### PREVENT PRINT BUFFERING
  use FileHandle;
### must do STDOUT _last_
  select $PRINTFH; $|=1;
  select $PRINTPIPE; $|=1;
  select STDERR; $|=1;
  select STDOUT; $|=1;
#######################################################################
####################  START OF SET RUN PARAMETERS  ####################
### USE JOBARG TO CREATE griddolist
### READ PARAMETERS FROM EXTERNAL FILE IF IT EXISTS
  if ( -s "rasp.run.parameters.${JOBARG}" )
  { 
    $externalrunparamsfile = "rasp.run.parameters.${JOBARG}" ;
    ### PREVENT PERL WARNINGS from certain parameters set in rasp.run.parameters... file
    %SAVE_PLOT_HHMMLIST = %NDOWN_BOUNDARY_UPDATE_PERIODHRS = %PLOT_IMAGE_SIZE = ();
    require $externalrunparamsfile  ;
  }
  else
  { print $PRINTFH "ERROR STOP: no rasp run parameters file found for $JOBARG"; exit 1; }
##########  PARAMETER ALTERATIONS  ##########
  ### SET WINDOW LOOP LIMITS BASED ON $LRUN_WINDOW
  foreach $regionkey (@REGION_DOLIST)
  {
    if( $LRUN_WINDOW{$regionkey} < 2 )
      { $iwindowstart{$regionkey} = $iwindowend{$regionkey} = $LRUN_WINDOW{$regionkey} ; }
    else
      {  $iwindowstart{$regionkey} = 0; $iwindowend{$regionkey} = 1 ; }
  }
### $LWINDOWRESTART=1 FOR RESTART FROM NON-WINDOW IC/BC WITH PRE-EXISTING GRIB FILE USED FOR NEEDED LANDUSE, ETC DATA
###                   (ALSO NEED BELOW: HARD-WIRED DAY/TIME FOR AN EXISTING GRIB FILE & START/END TIME ALTERATIONS)
###11feb2006  !!! I NO LONGER REMEMBER WHAT THIS SECTION (INVOKED BY SETTING $LWINDOWRESTART=1) IS ABOUT !!!
  $LWINDOWRESTART = 0;  
    ### SETUP FOR PANOCHE-WINDOW RESTART CASE
    if( $LWINDOWRESTART == 1 && $JOBARG eq 'PANOCHE-WINDOW' )
    {
      $DOMAIN1_STARTHH{$JOBARG}[1] = '18';          # must have grib file available at or prior to this time
      $FORECAST_PERIODHRS{$JOBARG}[1] = 6;       
      $BOUNDARY_UPDATE_PERIODHRS{$JOBARG}[1] = 1;     
      eval "\$DOMAIN2_START_DELTAMINS{\$JOBARG}[1] = 0" ;     # if non-zero, must set namelist.template INPUT_FROM_FILE=false
      eval "\$DOMAIN3_START_DELTAMINS{\$JOBARG}[1] = 0" ;     # if non-zero, must set namelist.template INPUT_FROM_FILE=false
      eval "\$DOMAIN2_END_DELTAMINS{\$JOBARG}[1] = 0" ;     # relative to domain1
      eval "\$DOMAIN3_END_DELTAMINS{\$JOBARG}[1] = 0" ;     # relative to domain1
      @{$PLOT_HHMMLIST{$JOBARG}[1]} = ( '1800','2100','0000' ); 
      print $PRINTFH "   PANOCHE-WINDOW WINDOW *RE*START starts at $DOMAIN1_STARTHH{$JOBARG}[1] with $FORECAST_PERIODHRS{$JOBARG}[1] hr period \n"; 
      ### END PANOCHE-WINDOW restart case
    }
    elsif( $LWINDOWRESTART == 1 )
    { print $PRINTFH "$program ERROR STOP: WINDOW RESTART NOT SETUP FOR JOBARG $JOBARG"; exit 1; }
###### SPECIAL REQUIREMENTS FOR XI RUNS
### NO GFS FILES ON XI SO REQUIRE GFS (AVN also required in .../static/wrfsi.nl files)
##  (use this fixup so that rasp.run.parameters.CANV to be same on both XI and SM)
if( $GRIBFILE_MODEL eq 'GFSN' && defined $ENV{'HOME'} && $ENV{'HOME'} eq '/home/glendeni' )
{
  $GRIBFILE_MODEL = 'GFSA' ;
} 
##########  FOR BACKWARDS COMPATABILITY  ##########
if( $GRIBFILE_MODEL eq 'GFS' ) { $GRIBFILE_MODEL = 'GFSN'; } 
###############################################################
##########  START OF TEST MODE PARAMETER OVERRIDE  ############
if ( $#ARGV == -1 || $ARGV[0] eq '-t' )
  {
    print "***************************************************************************************\n";
    print "***************************************************************************************\n";
    print "********************  THIS RUN USES TEST MODE OVERRIDE PARAMETERS  ********************\n";
    print "***************************************************************************************\n";
    print "***************************************************************************************\n";
    ### 4TESTMODE TEST PARAMETER OVERRIDES SET HERE
    ### CURRENTLY SUCCESSFUL XI TESTS:
    ### 30oct2005: PANOCHE without init   : rasp.pl PANOCHE -t   *** BUT FAILS 22Feb2007 ***
    ### 22Feb2007: PANOCHE with RUCH init : rasp.pl PANOCHE -t 92_2005
    ### TEST TIME SETUP - use existing eta/ruch grib files
    ### FOR RUCH INIT
    if( ( $JOBARG eq 'PANOCHE' || $JOBARG eq 'WILLIAMS' ) && ( ( $GRIBFILE_MODEL eq 'RUCH' && ( $LMODELINIT == 0  || $julianday_forced eq '92_2005' ) ) || ( $GRIBFILE_MODEL eq 'ETA' && ( $LMODELINIT == 0  || $julianday_forced eq '35_2005' ) ) ) )
    {  
       $FORECAST_PERIODHRS{$JOBARG}[0] = 12 ; 
       $GRIBFILES_PER_FORECAST_PERIOD{$JOBARG} = 5 ; @{$GRIBFILE_DOLIST{$JOBARG}} = ( '12Z+0', '12Z+3',  '12Z+6',  '12Z+9', '12Z+12' );
      print $PRINTFH "**WARNING** PANOCHE/WILLIAMS TEST-GRIB PARAMETERS USED \n";  
    }
    else
    { print $PRINTFH "***ERROR: PANOCHE/WILLIAMS TEST-GRIB PARAMETER SETUP ERROR: -t run not setup for parameters JOBARG=${JOBARG} julianday=${julianday_forced} GRIBFILE_MODEL=${GRIBFILE_MODEL} \n"; exit 1; }
  }
##########  END OF TEST MODE PARAMETER OVERRIDE  ############
#############################################################
####################  END OF SET RUN PARAMETERS  ####################
#####################################################################
###### SET OTHER DIRECTORIES
### WRF base directory (WRFV2+WRFSI are subdirectories)
  $WRFBASEDIR="$BASEDIR/WRF";
### rasp utilities directory - including copy,plot programs & overlay,gif files
  $UTILDIR = "${DIR}/RUN/UTIL";
### directory for grib file - *** MUST AGREE WITH VALUE IN WRFSI/extdata/static/grib_prep.nl
  $GRIBFILE_MODELDIR = "${RUNDIR}/$GRIBFILE_MODEL";
  $GRIBDIR = "$GRIBFILE_MODELDIR/GRIB";
### directory for plotting files (overlays, executeables)
### directory for saved files (uses separate subdirectorys for each grid
###   (don't use RUNDIR, since can then have separate JOBARG jobs writing to same directory)
  $SAVEDIR = "${DIR}/SAVE";
### directory for temporary plot, ftp/cp files
  $OUTDIR = "$RUNDIR/OUT";
###### SET EXTERNAL PROGRAM INFO
### gnu zip program
### regular zip program
  $ZIP = "$BASEDIR/UTIL/zip";
### ImageMagick convert program (should include LZW compressions if loop created)
  $CONVERT = "$BASEDIR/UTIL/convert";
### USE SEPARATE CALL TO NCARG CTRANS so can mix versions if need be
  $CTRANS = "$BASEDIR/UTIL/ctrans";
##### ENVIRONMENTAL PARAMS NEEDED FOR NCAR GRAPHICS (CTRANS)
### *NB* ON SM THIS IS NCL-ONLY 
  $NCARG_ROOT = "$BASEDIR/UTIL/NCARG";
### WRF NCL DIRECTORY contains ncl plotting stuff
  $NCLDIR = "$WRFBASEDIR/NCL";
####### HTML BASE DIRECTORY - where plot images sent to
  $HTMLBASEDIR = "$BASEDIR/RASP/HTML";
###### SET FILENAME INFO
### tmp filenames for gribftpget ftp output
  $GRIBFTPSTDOUT = "$GRIBFILE_MODELDIR/gribftpget.stdout"; 
  $GRIBFTPSTDERR = "$GRIBFILE_MODELDIR/gribftpget.stderr";
### tmp filename for gribftpls output for directory1
  $LSOUTFILE1 = "$GRIBFILE_MODELDIR/gribftpls.stdout1"; 
### tmp filename for gribftpls output for directory2
  $LSOUTFILE2 = "$GRIBFILE_MODELDIR/gribftpls.stdout2"; 
### tmp filename for gribftpls error output
  $LSOUTFILEERR = "$GRIBFILE_MODELDIR/gribftpls.stderr"; 
###### SET CYCLE CONTROL PARAMETERS
### SWITCHING TIME SETS *GMT* AFTER WHICH CYCLE ENDED AND PROGRAM TERMINATES FOR -M/-m RUNS
### SHOULD BE TIME BEYOND WHICH EXPECT NEW JOB TO START (with some padding) IE COMPARE TO CRONTAB TIME
##_for_next_day_switchingtime: 
  $switchingtimehrz{'ETA'}= 1.7;
  $switchingtimehrz{'GFSN'}= 1.7;
  $switchingtimehrz{'GFSA'}= 1.7;
  $switchingtimehrz{'AVN'}= 1.7;
  $switchingtimehrz{'RUCH'}= 1.7;
##_for_same_day_switchingtime: $switchingtimehrz = 23.7;
### SET MINIMUM FTP,CALC TIMES USED TO DETERMINE WHEN ANOTHER ITERATION POSSIBLE
  $minftpmin{'ETA'}=20; 
  $minftpmin{'GFSN'}=20; 
  $minftpmin{'GFSA'}=20; 
  $minftpmin{'AVN'}=20; 
  $minftpmin{'RUCH'}=20; 
  $mincalcmin{'ETA'}=5; 
  $mincalcmin{'GFSN'}=5; 
  $mincalcmin{'GFSA'}=5; 
  $mincalcmin{'AVN'}=5; 
  $mincalcmin{'RUCH'}=5; 
###### SET GRIB GET PARAMETERS
### set max waits for ftpget but should never be reached since file exists
### set max ftp time for grib get
  $getgrib_waitsec = 2 *60;                # sleep time, _not_ a timeout time
  ### GRIBAVAILHRZOFFSET USED TO _ADD_ CUSHION TO ACTUAL EXPECTED AVAILABILTY
  ### must treat gfsa/avn separately since cannot request before available (no date identifiation by ftp2u!)
  ### for test purposes, can be overridden by specifying $gribavailhrzoffset in rasp.run.parameters or rasp.site.parameters
  $gribavailhrzoffset{ETA} = -0.05; 
  $gribavailhrzoffset{RUCH} = -0.05; 
  $gribavailhrzoffset{GFSN} = -0.05; 
  $gribavailhrzoffset{GFSA} = +0.0; 
  $gribavailhrzoffset{AVN} = +0.6; 
### SET LS FTP TIMEOUT TIMES
### time for ls of grib file directory
### *NB* should match that used for curl in gribftpls
### ($gribgetftptimeoutmaxsec set further below, since differs for different models)
  $lsgetftptimeoutsec = 2 *60;
### CYCLE_WAITSEC IS SECONDS BETWEEN CYCLES WITH NO AVAILABLE FILES TO PROCESS
  $cycle_waitsec = 3 *60;
### CYCLE_MAX_RUNHRS = MAX HOURS FOR SCRIPT TO RUN (runaway script prevention) (not affected by day of start)
  $cycle_max_runhrs = 23.6 ;
### now use 2 min instead of cycle_waitsec since that is iter time when have ftp ls failure due to server being down
       $cycle_max = int( ($cycle_max_runhrs*3600.)/(2*60) );
### SET GRID CALC TIMEOUT TIME
### to avoid any possible hangup in model init/run section, set to 6 hr
### but some runs can extend longer if next time slot not fully loaded
  $gridcalctimeoutsec = int( 8 *3600 );
### SET NCL PLOT TIMEOUT TIME - normally takes 2-5 mins clock time on SM
  $ncltimeoutsec = int( 20 *60 );          
### SET FTP TIMEOUT TIME (only used when $LSEND<0)
  my $ftptimeoutsec = int( 6 *60 );
### time for initial setup,renames on webbnet files (usually takes 3 mins) 
### should span internal iteration#*sleepsec in blipmap.ftp2previousday
###       (presently primarymaxiter=3 primarysleepsec=60)
### normal CA-NV (13 times) run time is ~3-4 min for blipmap.ftp2previousday
  $previousdayftptimeoutsec = 15 *60;
### SET GRIBGET PARAMETERS
### expect following statuses to be > $maxattempts, so then no files no longer available for processing
  $status_processed = 9;
  $status_skipped = 8;
  $status_problem = 7;
### for LGETGRIB=2 cases, set max scheduled attempts
  $max_schedgrib_attempts = 1;
### SET SLEEP TIME FOR MAIN THREAD FINISH/PLOT LOOP
    ### MUST ALLOW ENOUGH START-UP TIME FOR PREVIOUS wrfout FILES TO BE RE-NAMED
    if( $RUNTYPE eq '-T' || $RUNTYPE eq '-t' )
    { $finishloopsleepsec = 10 ; }
    ### dont make so short that plotting finds wrfout... files created in REGIONXYZ-WINDOW during stage2-only initialization
    elsif ( $JOBARG =~ '-WINDOW' )
    { $finishloopsleepsec = 300 ; }
    ### don't make more than 10 mins as 1-stage job can forecast 3hrs in ~10min
    elsif( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' )
    { $finishloopsleepsec = 180 ; }
    else
    { $finishloopsleepsec = 180 ; }
###### STORED IMAGE IDs
  $dow_localid = '36x18';
  $day_localid = '36x18';
  $mon_localid = '36x18';
###### SET BLANK DEFAULT $ADMIN_EMAIL_ADDRESS
### must be overriden by rasp.site.parameters since also used for anonymous login password
 $ADMIN_EMAIL_ADDRESS = ''; 
###### SET USERNAME
  $USERNAME = $ENV{'LOGNAME'};
###    these are empirically obtained values - might also depend on no. of model levels ?
  $num_metgrid_levels{'GFSN'} = 52 ;
  $num_metgrid_levels{'GFSA'} = 52 ;
  $num_metgrid_levels{'AVN'} = 52 ;
  $num_metgrid_levels{'ETA'} = 52 ;
  $num_metgrid_levels{'RUCH'} = 52 ;
### SET PARAMETER INFORMATION NAMES USED FOR IMAGE LOOP TITLE - note "~" escape NOT recognized by plt_text.exe 
$paraminfo{'hglider'}       = 'Maximum Thermalling Height' ;
$paraminfo{'dbl'}           = 'BL Depth' ;
$paraminfo{'sfcshf'}        = 'Sfc. Heating' ;
$paraminfo{'vhf'}           = 'Sfc. Virtual Heat Flux' ;
$paraminfo{'sfcsun'}        = 'Sfc. Solar Radiation' ;
$paraminfo{'sfcsunpct'}     = 'Normalized Sfc. Solar Radiation' ;
$paraminfo{'wstar'}         = 'Thermal Updraft Velocity' ;
$paraminfo{'hglider'}       = 'Thermalling Height' ;
$paraminfo{'hbl'}           = 'Height of BL Top' ;
$paraminfo{'hwcrit'}        = 'Height of Critical Updraft Strength' ;
$paraminfo{'dwcrit'}        = 'Depth of Critical Updraft Strength' ;
$paraminfo{'wblmaxmin'}     = 'BL Max. Up/Down Motion' ;
$paraminfo{'zwblmaxmin'}    = 'MSL Height of maxmin Wbl' ;
$paraminfo{'swblmaxmin'}    = 'AGL Height of maxmin Wbl' ;
$paraminfo{'pwblmaxmin'}    = 'Depth of maxmin Wbl' ;
$paraminfo{'blicw'}         = 'BL Integrated Cloud Water' ;
$paraminfo{'aboveblicw'}    = 'Above-BL Integrated Cloud Water' ;
$paraminfo{'blcwbase'}      = 'BL CloudWater Base' ;
$paraminfo{'cwbase'}        = 'CloudWater Base' ;
$paraminfo{'rhblmax'}       = 'BL Max. Relative Humidity' ;
$paraminfo{'blcloudpct'}    = 'BL Cloud Cover' ;
$paraminfo{'zsfclcl'}       = 'Cu Cloudbase' ;
$paraminfo{'zsfclcldif'}    = 'Cu Potential' ;
$paraminfo{'zblcl'}         = 'OvercastDevelopment Cloudbase' ;
$paraminfo{'zblcldif'}      = 'OvercastDevelopment Potential' ;
$paraminfo{'bsratio'}       = 'Buoyancy/Shear Ratio' ;
$paraminfo{'blwindshear'}   = 'BL Vertical Wind Shear' ;
$paraminfo{'sfctemp'}       = 'Surface Temperature' ;
$paraminfo{'sfcdewpt'}      = 'Surface Dew Point Temperature' ;
$paraminfo{'bltopvariab'}   = 'BL Top Uncertainty/Variability' ;
$paraminfo{'cape'}          = 'CAPE' ;
$paraminfo{'blwind'}        = 'BL Wind' ;
$paraminfo{'sfcwind'}       = 'Surface Wind' ;
$paraminfo{'bltopwind'}     = 'Wind at BL Top' ;
$paraminfo{'wstar_bsratio'} = 'Thermal Updraft Velocity + B/S stipple' ;
$paraminfo{'zsfclclmask'}   = 'Cu Cloudbase  where Cu Potential > 0' ;
$paraminfo{'zblclmask'}     = 'OD Cloudbase  where OD Potential > 0' ;
$paraminfo{'boxwmax'}       = 'Cross-Section at max vert. motion' ;
$paraminfo{'press850'}      = '850 mb Constant Pressure Level' ;
$paraminfo{'press700'}      = '700 mb Constant Pressure Level' ;
$paraminfo{'press500'}      = '500 mb Constant Pressure Level' ;
##############################################################
###### SET NON-ARGUMENT FLAGS
### SET WHETHER MULTIPLE REGIONS WILL BE RUN SERIALLY (0) OR IN PARALLEL (1)
### AND WHETHER OUTPUT PLOT ALL DONE AT END (0) OR SOON AFTER THEY ARE PRODUCED (1)
###   (IF RUN WITH SINGLE THREAD ($LTHREADEDREGIONRUN=0) THEN IMAGES NOT GENERATED UNTIL END !)
###   ($LTHREADEDREGIONRUN=0 intended for testing so domain to be plotted hard-wired into &output_model_results_hhmm)
### ENSURE USE OF SINGLE_THREAD FOR SM DEBUG CASES SINCE MULTI-WINDOW CAUSES PROBLEMS
  if ( $^P != 0 && defined $ENV{'HOSTNAME'} && $ENV{'HOSTNAME'} eq 'drjack.info' )
    {
      $LTHREADEDREGIONRUN = 0;
      if ( $LPRINT >=0 ) { print $PRINTFH "   ** SET LTHREADEDREGIONRUN=0, since running debugger on SM \n"; }
    }
  else
    { $LTHREADEDREGIONRUN = 1; }
### MANUALLY SPECIFY LTHREADEDREGIONRUN  HERE
### SET NUMBER OF PHYSICAL CPUS TO BE USED BY WRF EXECUTABLE
### set to 2 so multiple cpus utilized when available (do NOT set to 4 for hyper-threaded dual Xeon)
###  $NCPUS = 8 ;
###### FINALLY, IF SITE PARAMETER FILE EXISTS THEN ALTER PARAMETERS SET ABOVE
if ( -s "rasp.site.parameters" )
{ 
  	print $PRINTFH "Loading rasp.site.parameters\n";
	
    $externalsitefile = "rasp.site.parameters" ;
    require $externalsitefile  ;
	
  	print $PRINTFH "    NCPUS=${NCPUS}\n";
}
### SET RASP ENVIRONMENTAL PARAMETERS
$ENV{'RASP_ADMIN_EMAIL_ADDRESS'} =  $ADMIN_EMAIL_ADDRESS ;
if( ! defined $ADMIN_EMAIL_ADDRESS || $ADMIN_EMAIL_ADDRESS =~ m|^\s*$| ) { die "*** ERROR EXIT - parameter ADMIN_EMAIL_ADDRESS must not be blank or null"; exit 1; }
####################################################################################
#### DETECT AND KILL PREVIOUSLY RUNNING BATCH JOB
  if ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' )
  { 
    jchomp( my $jobps=`ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID} .*${0}  *$JOBARG  *-[Mm]" | grep "$USERNAME .*${0}  *$JOBARG  *-[Mm]"` );
      ### be sure to eliminate present job !
      ### FIRST TRY "SOFT" KILL USING SIGNAL 2 
      jchomp( $previousjobps=`ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID} .*${0}  *$JOBARG  *-[Mm]" | grep "$USERNAME .*${0}  *$JOBARG  *-[Mm]"` );
      if ( $previousjobps ne "" )
      {
        ### IF INTERACTIVE JOB, MAKE SURE I WANT TO DO THE KILL !
        if ( defined $ENV{TERM} )
        {
          print $PRINTFH ">> Found existing job $previousjobps \n>>  should it be killed ?? [CR/y=YES, n=NO] >> ";
          print ">> Found existing job $previousjobps \n>>  should it be killed ?? [CR/y=YES, n=NO] >> ";
         ( my $char1 = substr( <STDIN>, 0, 1) ) =~ tr/A-Z/a-z/ ;
          if ( $char1 eq 'n' ) { goto SKIPSTARTINGKILL; }
        }
        $previousjobpid = ( split /  */, $previousjobps )[1];
        if ($LPRINT>1) { print $PRINTFH "*** pid= $$ START SOFT KILL of existing job with PID= $previousjobpid \n"; }
        jchomp( my $killout=`kill -2 $previousjobpid` );
        sleep 60;
        if ($LPRINT>1) { print $PRINTFH "*** SOFT KILLLED EXISTING JOB $previousjobpid => $killout \n"; }
      }
      ### IF ABOVE SOFT KILL DOESNT WORK, USE "HARD" KILL USING SIGNAL 9
      jchomp( $previousjobps=`ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID} .*${0}  *$JOBARG  *-[Mm]" | grep "$USERNAME .*${0}  *$JOBARG  *-[Mm]"` );
      if ( $previousjobps ne "" )
      {
        if ($LPRINT>1) { print $PRINTFH "*** pid= $$ START HARD KILL of existing job+children from PID= $previousjobpid PS= $previousjobps \n"; }
        $previousjobpid = ( split /  */, $previousjobps )[1];
        my $killout = &kill_pstree( $previousjobpid );
        sleep 60;
        if ($LPRINT>1) { print $PRINTFH "*** HARD KILLED EXISTING JOB $previousjobpid PS TREE => $killout \n"; }
      }
      ### MAKE DOUBLY SURE THAT ANY LEFT-OVER CURL JOBS ARE KILLED
      ### be sure to eliminate present job !
      jchomp( $previousjobpids = `ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID}" | grep "$USERNAME .* $BASEDIR/UTIL/curl .*${JOBARG}" | tr -s ' ' | cut -f2 -d' ' | tr '\n' ' '` );
      if ( $previousjobpids !~ m|^\s*$| )
      {
        if ($LPRINT>1) { print $PRINTFH "*** !!! OLD CURL JOBS FOUND SO KILLED !!!  PID= $previousjobpids \n"; }
        ### send stderr to stdout as once tried to kill non-existent job
        jchomp( my $killout = `kill -9 $previousjobpids 2>&1` );
        sleep 60;
        if ($LPRINT>1) { print $PRINTFH "*** KILLED EXISTING CURL JOBS $previousjobpids \n"; }
      }
    SKIPSTARTINGKILL:
  }
### KILL ANY EXISTING FTP JOBS - UNTESTED !!!
### set test filename tail
  $filenamehead{ 'test' } = 'test.grib';
  $filetimes{ 'test' } = '';
### CALL TO SET  MODEL-DEPENDENT LGETGRIB AND SCHEDULING PARAMETERS
  &setup_getgrib_parameters;
### INITIALIZATION
### NB mon{01}=Jan !
  my %mon = ( '01','Jan', '02','Feb', '03','Mar', '04','Apr', '05','May', '06','Jun',
              '07','Jul', '08','Aug', '09','Sep', '10','Oct', '11','Nov', '12','Dec' );
  @dow = ( "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" );
### GET ZULU RUNDAYS MONTH,DAY,YEAR
### need julian date for 20kmRUC
### use date -u when start before midnight local time
  $julianday = `date -u +%j` ; jchomp($julianday);
### dont use date -u if may start after 00Z
  $startzuluhr = `date -u +%H` ; jchomp($startzuluhr);
### 4TESTMODE - force $julianday here when using existing data files
  if( defined $julianday_forced )
  {
    ### allow specification of year with julian date
    if( $julianday_forced =~ m|_| )
    { 
       ( $julianday,$julianyear_forced ) = split ( /_/, $julianday_forced );
    }
    elsif ( $julianday_forced != 0 )
    {
       $julianday = $julianday_forced;
    }
 print "   vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv   \n";
 print ">>> *WARNING* FORCED JULIANDAY_YEAR = $julianday_forced => julianday= $julianday <<< \n";
 print "   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   \n";
  }
### FOR EVENING TESTS, AUTOMATICALLY USE PREVIOUS JULIAN DATE
### require 3 digit julian date with leading zeros for filenames
  $julianday = sprintf( "%03d",$julianday );
### SET CURRENT JULIAN MONTH,DAY,YR
  if( ! defined $julianyear_forced )
  {
    $iyr2runday = `date -u +%y` ; jchomp($iyr2runday);
  }
  else
  {
    $iyr2runday = $julianyear_forced ;
  }
  ### this section & UTIL/jdate2date only valid until 2099 - i can't believe this code will still be running then, but ...
  if( $iyr2runday == 0 ) { print $PRINTFH "*** ERROR EXIT - sorry, only coded to be valid until 2099"; exit 1; }
  jchomp( $string = `$UTILDIR/jdate2date $julianday $iyr2runday` );
  ($jmo2,$jda2,$jyr2) = split ( m|/|, $string );
  $jyr4 = $jyr2 + 2000 ;
  $validdow{'curr.'} = $dow[ &dayofweek( $jda2, $jmo2, $jyr4 ) ]; # uses Date::DayOfWeek
  $validdow{''} = $validdow{'curr.'};
  $validdateprt{'curr.'} = "${jmo2}/${jda2}";
  $validdateprt{''} = $validdateprt{'curr.'};
  $validmon{'curr.'} = $mon{$jmo2};
  $validmon{''} = $validmon{'curr.'} ;
  $validda1{'curr.'} = &strip_leading_zero( $jda2 ); 
  $validda1{''} = $validda1{'curr.'}; 
  $yymmdd{'curr.'} = "${jyr2}${jmo2}${jda2}";
  $yymmdd{''} = $yymmdd{'curr.'};
  $juliandayprt = "${validdow{'curr.'}} ${jda2} ${mon{$jmo2}} ${jyr4}";
  $julianyyyymmddprt{'curr.'} = "${jyr4}-${jmo2}-${jda2}";
  $julianyyyymmddprt{''} = $julianyyyymmddprt{'curr.'} ;
### NOW SET "RUNDAY" BASED ON JULIANDAY (SO ALTERED BY ANY ALTERATIONS TO IT)
  my $yymmddrunday = $yymmdd{''};
  $rundayprt = $juliandayprt;
### SET PREVIOUS JULIAN MONTH,DAY,YR
  $juliandaym1 = $julianday - 1;
  jchomp( $string = `$UTILDIR/jdate2date $juliandaym1 $iyr2runday` );
  my ($jmo2m1,$jda2m1,$jyr2m1) = split ( m|/|, $string );
  $jyr4m1 = $jyr2m1 + 2000 ;
### SET CURRENT+1 JULIAN MONTH,DAY,YR
  $juliandayp1 = $julianday + 1;
  jchomp( $string = `$UTILDIR/jdate2date $juliandayp1 $iyr2runday` );
  my ($jyr2p1);
  ($jmo2p1,$jda2p1,$jyr2p1) = split ( m|/|, $string );
  $jyr4p1 = $jyr2p1 + 2000 ;
  $validdow{'curr+1.'} = $dow[ &dayofweek( $jda2p1, $jmo2p1, $jyr4p1 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+1.'} = "${jmo2p1}/${jda2p1}";
  $validmon{'curr+1.'} = $mon{$jmo2p1};
  $validda1{'curr+1.'} = &strip_leading_zero( $jda2p1 ); 
  $yymmdd{'curr+1.'} = "${jyr2p1}${jmo2p1}${jda2p1}";
  $julianyyyymmddprt{'curr+1.'} = "${jyr4p1}-${jmo2p1}-${jda2p1}";
### SET CURRENT+2 JULIAN MONTH,DAY,YR
  $juliandayp2 = $julianday + 2;
  my ($jyr2p2);
  jchomp( $string = `$UTILDIR/jdate2date $juliandayp2 $iyr2runday` );
  ($jmo2p2,$jda2p2,$jyr2p2) = split ( m|/|, $string );
  my $jyr4p2 = $jyr2p2 + 2000 ;
  $validdow{'curr+2.'} = $dow[ &dayofweek( $jda2p2, $jmo2p2, $jyr4p2 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+2.'} = "${jmo2p2}/${jda2p2}";
  $validmon{'curr+2.'} = $mon{$jmo2p2};
  $validda1{'curr+2.'} = &strip_leading_zero( $jda2p2 ); 
  $yymmdd{'curr+2.'} = "${jyr2p2}${jmo2p2}${jda2p2}";
  $julianyyyymmddprt{'curr+2.'} = "${jyr4p2}-${jmo2p2}-${jda2p2}";
### SET CURRENT+3 JULIAN MONTH,DAY,YR
  $juliandayp3 = $julianday + 3;
  my ($jyr2p3);
  jchomp( $string = `$UTILDIR/jdate2date $juliandayp3 $iyr2runday` );
  ($jmo2p3,$jda2p3,$jyr2p3) = split ( m|/|, $string );
  my $jyr4p3 = $jyr2p3 + 2000 ;
  $validdow{'curr+3.'} = $dow[ &dayofweek( $jda2p3, $jmo2p3, $jyr4p3 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+3.'} = "${jmo2p3}/${jda2p3}";
  $validmon{'curr+3.'} = $mon{$jmo2p3};
  $validda1{'curr+3.'} = &strip_leading_zero( $jda2p3 ); 
  $yymmdd{'curr+3.'} = "${jyr2p3}${jmo2p3}${jda2p3}";
  $julianyyyymmddprt{'curr+3.'} = "${jyr4p3}-${jmo2p3}-${jda2p3}";
### SET CURRENT+4 JULIAN MONTH,DAY,YR
  $juliandayp4 = $julianday + 4;
  my ($jyr2p4);
  jchomp( $string = `$UTILDIR/jdate2date $juliandayp4 $iyr2runday` );
  ($jmo2p4,$jda2p4,$jyr2p4) = split ( m|/|, $string );
  my $jyr4p4 = $jyr2p4 + 2000 ;
  $validdow{'curr+4.'} = $dow[ &dayofweek( $jda2p4, $jmo2p4, $jyr4p4 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+4.'} = "${jmo2p4}/${jda2p4}";
  $validmon{'curr+4.'} = $mon{$jmo2p4};
  $validda1{'curr+4.'} = &strip_leading_zero( $jda2p4 ); 
  $yymmdd{'curr+4.'} = "${jyr2p4}${jmo2p4}${jda2p4}";
  $julianyyyymmddprt{'curr+4.'} = "${jyr4p4}-${jmo2p4}-${jda2p4}";
### note: if "curr+4" run option added, would need a 'curr+5' section here and thus to alter RUN/UTIL/jdate2date to allow curr+5
### CALL TO SET  FTP PARAMETERS
### but for NWS must later override directories since since depends on initialization time
  &setup_ftp_parameters;
  my ($dummy,$dum);
  $lalldone = 1;
######## 4TESTMODE : SET ANY FINAL FLAGS HERE PRIOR TO FIRST SCRIPT PRINT ########
#### ARGUMENT FLAGS
#### NON-ARGUMENT FLAGS
### SCRIPT START-UP PRINTS
  $startdate = `date '+%b %d'` ; jchomp($startdate);
  $starttime = `date +%H:%M` ; jchomp($starttime);
  if ($LPRINT>1)
  {
    print $PRINTFH "START: $program @ARGV at $starttime $startdate for $rundayprt : process $$ & perl $] & ",'$Revision: 2.136 $ $Date: 2008/09/15 00:27:34 $Z',"\n";
    print $PRINTFH "FLAGS:  LPRINT=${LPRINT}  LGETGRIB=${LGETGRIB}  LMODELINIT=${LMODELINIT}   LMODELRUN=${LMODELRUN}  LSEND=${LSEND}  LSAVE=${LSAVE}\n";
    print $PRINTFH "VARS:   BASEDIR=${BASEDIR} \n";
    if( defined $externalrunparamsfile )
    {
       print $PRINTFH "--- Run parameters were read from file:  $externalrunparamsfile \n";
       ### LIST RUN PARAMETERS
       @externalrunparams = `cat $externalrunparamsfile | sed 's/^/  >  /'`;
       print $PRINTFH "@externalrunparams";
    }
    else                                 
	{ 
		print $PRINTFH "** INTERNAL run parameters used, NOT read from file\n"; 
	}

    if( ! defined $externalsitefile ) 
	{ 
		print $PRINTFH "** INTERNAL run parameters used with NO site alterations \n\n"; 
	}
    else
    { 
       print $PRINTFH "--- SITE ALTERATIONS were read from file: $externalsitefile \n";
       ### LIST RUN PARAMETERS
       @externalsiteparams = `cat $externalsitefile | sed 's/^/  >  /'`;
       print $PRINTFH "@externalsiteparams";
    }
  }
  if ($LPRINT>1) {print $PRINTFH ("\nRUNDATE= $rundayprt  JULIANDAY= $julianday  Timezone info = $LOCALTIME_ADJ{$JOBARG}  $LOCALTIME_ID{$JOBARG}");}
  if ($LPRINT>1)
  {
    foreach $regionkey (@REGION_DOLIST)
    {
      printf $PRINTFH "  %4s  GRIBFILE_DOLIST= ( %s )\n",$regionkey,"@{$GRIBFILE_DOLIST{$regionkey}}";
    }
  }
####### CONSISTENCY/SANITY CHECKS
  foreach $regionkey (@REGION_DOLIST)
  {
    ### REQUIRE CONSISTENCY OF $GRIBFILE_MODEL & INIT_ROOT,LBC_ROOT in WRF/WRFSI/domains/REGIONXYZ/static/wrfsi.nl
    ### must allow for existence of ETAP in wrfsi when ETA model used
    chomp( $testconsistency = `grep -c "['\\\"]${GRIBFILE_MODEL}['\\\"]" $BASEDIR/WRF/WRFSI/domains/$regionkey/static/wrfsi.nl` );
    if ( $testconsistency eq '' )
    { print $PRINTFH  "ERROR STOP: GRIBFILE_MODEL missing file WRF/WRFSI/domains/$regionkey/static/wrfsi.nl"; exit 1; }
    elsif ( $testconsistency ne '2' )
    { 
      if ( -l "$BASEDIR/WRF/WRFSI/domains/$regionkey/static/wrfsi.nl" )
     { print $PRINTFH "*** ERROR EXIT: $regionkey wrfsi.nl NOT consistent with GRIBFILE_MODEL BUT SHALL NOT ALTER A LINK!\n"; exit 1; }
      `mv -f $BASEDIR/WRF/WRFSI/domains/$regionkey/static/wrfsi.nl $BASEDIR/WRF/WRFSI/domains/$regionkey/static/wrfsi.nl.pre_consistency_check ; sed -e "/INIT_ROOT/s/.*/  INIT_ROOT = \'${GRIBFILE_MODEL}\',/;/LBC_ROOT/s/.*/  LBC_ROOT = \'${GRIBFILE_MODEL}\',/" $BASEDIR/WRF/WRFSI/domains/$regionkey/static/wrfsi.nl.pre_consistency_check > $BASEDIR/WRF/WRFSI/domains/$regionkey/static/wrfsi.nl`;
      if ($LPRINT>1) { print $PRINTFH "*WARNING: $regionkey wrfsi.nl ALTERED so consistent with GRIBFILE_MODEL\n"; }
    }
    if ( $LRUN_WINDOW{$regionkey} > 0 )
    {
      chomp( $testconsistency = `grep -c "['\\\"]${GRIBFILE_MODEL}['\\\"]" $BASEDIR/WRF/WRFSI/domains/${regionkey}-WINDOW/static/wrfsi.nl` );
      if ( $testconsistency ne '2' )
      { 
        if ( -l "$BASEDIR/WRF/WRFSI/domains/${regionkey}-WINDOW/static/wrfsi.nl" )
        { print $PRINTFH "*** ERROR EXIT: ${regionkey}-WINDOW wrfsi.nl NOT consistent with GRIBFILE_MODEL BUT SHALL NOT ALTER A LINK!\n"; exit 1; }
        `mv -f $BASEDIR/WRF/WRFSI/domains/${regionkey}-WINDOW/static/wrfsi.nl $BASEDIR/WRF/WRFSI/domains/${regionkey}-WINDOW/static/wrfsi.nl.pre_consistency_check ; sed -e "/INIT_ROOT/s/.*/  INIT_ROOT = \'${GRIBFILE_MODEL}\',/;/LBC_ROOT/s/.*/  LBC_ROOT = \'${GRIBFILE_MODEL}\',/" $BASEDIR/WRF/WRFSI/domains/${regionkey}-WINDOW/static/wrfsi.nl.pre_consistency_check > $BASEDIR/WRF/WRFSI/domains/${regionkey}-WINDOW/static/wrfsi.nl`;
        if ($LPRINT>1) { print $PRINTFH "*WARNING: ${regionkey}-WINDOW wrfsi.nl ALTERED so consistent with GRIBFILE_MODEL\n"; }
      }
    }
    ### PLOT FILENAME LENGTH now 256 characters instead of old 80 character NCARG plot filename limit
  }
### SET FULL FILE DO LIST (order determines overall processing priority) (lower-priority duplicates eliminated later)
### PRESENT PRIORITY: @ GRIBFILE_DOLIST
  @filedolist = ();
  $sumblipmapfiledolists = 0;
  foreach $regionkey (@REGION_DOLIST)
  {
    push @filedolist, @{$GRIBFILE_DOLIST{$regionkey}};
    $sumblipmapfiledolists += $#{$GRIBFILE_DOLIST{$regionkey}} +1; 
  }
### ELIMINATE ANY DUPLICATE REQUESTED FILENAMES
  $dofilecount = 0;
  foreach $ifile (@filedolist)
  {
    ($ifilegreptest = $ifile ) =~ s/\+/\\\+/g;
    ### eliminate any duplicate (with lower priority) requested filenames
    ### here filevalidtimes is just a dummy - overwritten later
    if( ! defined($filevalidtimes{$ifile}) )
    {
      push ( @editedfiledolist, $ifile );
      $dofilecount = $dofilecount +1;
      $filevalidtimes{$ifile} = 1;
    }
  }
  @filedolist = @editedfiledolist;
  ### this used for printing of summary times and again
  @validdaylist = ( "curr.", "curr+1.", "curr+2.", "curr+3.", "curr+4." );
### START OF SET FILENAME ANAL/FCST/VALID TIME ARRAYS
  $avgextendedvalidtime = 0 ; 
  $nfiles = 0 ; 
  foreach $ifile (@filedolist)
  {
    $nfiles += 1; 
    $lgribprepsuccess{$ifile} = 0; 
    ### extract analysis and forecast times from file specifier
    ### allow leading - to use previous julian day
    if ( substr($ifile,0,1) ne '-' && substr($ifile,0,1) ne '+' )
    {
      $julianday{$ifile} = ${julianday}; 
      $julianyear{$ifile} = ${jyr2}; 
      ($fileanaltime,$ftime) = split( /Z\+/, $ifile );
      $analtime = $fileanaltime;
    }
    ### allow leading + to use next julian day
    elsif ( substr($ifile,0,1) eq '-' )
    {
      $julianday{$ifile} = $juliandaym1; 
      ### require 2,3 digit julian year,day with leading zeros for filenames
      $julianday{$ifile} = sprintf( "%03d",$julianday{$ifile} );
      $julianyear{$ifile} = ${jyr2m1}; 
      ($fileanaltime,$ftime) = split( /Z\+/, substr($ifile,1) );
      $analtime = $fileanaltime - 24.;
    }
    ### allow leading + to use next julian day
    elsif ( substr($ifile,0,1) eq '+' )
    {
      $julianday{$ifile} = $juliandayp1; 
      ### require 2,3 digit julian year,day with leading zeros for filenames
      $julianday{$ifile} = sprintf( "%03d",$julianday{$ifile} );
      $julianyear{$ifile} = ${jyr2p1}; 
      ($fileanaltime,$ftime) = split( /Z\+/, substr($ifile,1) );
      $analtime = $fileanaltime + 24.;
    }
    else
    { print $PRINTFH "*** ERROR EXIT: BAD FORMAT FOR $ifile"; exit 1; }
    ### PARTIAL SPECIFICATION OF MODEL GRIB FILENAME HERE
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2 DUE TO THIS CODE SEGMENT
    if ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'fh.00%02d_tl.press_gr.awip3d',$ftime;   }
    elsif ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'fh.00%02d_tl.press_gr.onedeg',$ftime;
      }
    elsif ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' )
      { print $PRINTFH "*** ERROR EXIT - Limited Area GFS file not available from NWS"; exit 1; }
    elsif ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' )
      { print $PRINTFH "*** ERROR EXIT - truncated AVN file not available from NWS"; exit 1; }
    elsif ( $gribftpsite1 eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'RUCH' )
      { 
        ### break fsl filename into 2 parts (head+time) so can delete old grib files using wildcard+latter
        $filenamehead{$ifile} = sprintf '%02d%03d',($jyr2,$julianday);
        $filetimes{$ifile} = sprintf '%02d%06d.grib',($fileanaltime,$ftime);
      }
    elsif ( $gribftpsite1 eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'nam.t%02dz.awip3d%02d.tm00.grib2',$fileanaltime,$ftime;   }
    elsif ( $gribftpsite1 eq 'nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'nam.t%02dz.awip3d%02d.tm00.grib2',$fileanaltime,$ftime;   }  
    elsif ( $gribftpsite1 eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrb2f%02d',$fileanaltime,$ftime;
      }
    elsif ( $gribftpsite1 eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrbf%02d',$fileanaltime,$ftime;
      }
    elsif ( $gribftpsite1 eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' )
      { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrbf%02d',$fileanaltime,$ftime;
      }
    if ( $ftime eq 'nl' )
       { $ftime = '00'; }
    ### require analysis time to have leading zero
    if( length($analtime)==1 ) { $fileanaltime = "0${fileanaltime}"; }
    ### remove any leading zero from forecast time (but dont remove single 0)
    $ftime =~ s/^0[^0]// ;
    $fileanaltimes{$ifile} = $fileanaltime ;
    $filefcsttimes{$ifile} = $ftime ;
    $validtime = $analtime + $ftime ;
    ### allow leading + to be next julian day
    ### set extended valid time which includes 24hr for each day (needed for eta)
    $fileextendedvalidtimes{$ifile} = $validtime; 
    ### average validtime to use as "current day" indicator
    $avgextendedvalidtime += $validtime ; 
    ### determine file day and adjust filevalidtime
    if ( $GRIBFILE_MODEL eq 'ETA' || $GRIBFILE_MODEL eq 'RUCH' || $GRIBFILE_MODEL eq 'GFSN' || $GRIBFILE_MODEL eq 'GFSA' || $GRIBFILE_MODEL eq 'AVN' )
      { $filevaliddays{$ifile} = 'curr.'; }
    else
      { $filevaliddays{$ifile} = ''; }
    if ( $validtime <= 0 )
      {
       $filevalidtime = $validtime +24;
      }
    elsif ( $validtime <= 23 )
      {
        ### now use null to indicate current day ala present maps useage
        $filevalidtime = $validtime;
      }
    elsif ( $validtime <= 47 )
      {
        $filevaliddays{$ifile} = 'curr+1.';
        $filevalidtime = $validtime - 24;
      }
    elsif ( $validtime <= 71 )
      {
        $filevaliddays{$ifile} = 'curr+2.';
        $filevalidtime = $validtime - 48;
      }
    elsif ( $validtime <= 95 )
      {
        $filevaliddays{$ifile} = 'curr+3.';
        $filevalidtime = $validtime - 72;
      }
    elsif ( $validtime <= 119 )
      {
        $filevaliddays{$ifile} = 'curr+4.';
        $filevalidtime = $validtime - 95;
      }
    else
      { print $PRINTFH "BLIP ERROR EXIT: bad filevalidtime= $filevalidtime"; exit 1; } 
    $filevalidtimepluses{$ifile} = $filevalidtime ;
    if ( $filevalidtimepluses{$ifile} > 23 )
      { $filevalidtimepluses{$ifile} = $filevalidtimepluses{$ifile} - 24; }
    if ( $filevalidtime > 23 )
      { $filevalidtime = $filevalidtime - 24; }
    $filevalidtimes{$ifile} = $filevalidtime ;
    ### initialize latest fcst time 
    $latestfcsttime[$fileextendedvalidtimes{$ifile}] = 999; 
    ### SET SCHEDULED AVAILABILITY TIMES IF NEEDED
    if ( $LGETGRIB == 2 )
    {
      $gribavailadd = $gribavailhrzinc * $ftime;
      ### note that fileanaltime is 2 digit ie 00,... not 0,...
      $gribavailhrz{$ifile} = $gribavailhrzoffset + $gribavailhrz0{$fileanaltime} + $gribavailadd ;
      if ($LPRINT>1) { printf $PRINTFH "   Scheduled availability: %7s @ %5sZ\n",$ifile,&hour2hhmm($gribavailhrz{$ifile}); }
    }
    $filevalidday = $filevaliddays{$ifile} ;
    ### CALC FINAL PROCESSING SUMMARY PRESENTATION TIMES (part1)
    if ( ! grep( /^${filefcsttimes{$ifile}}$/, @{$fcsttimelist{$filevalidday}} ) )
    {
      push @{$fcsttimelist{$filevalidday}}, $filefcsttimes{$ifile} ;  
    }
    if ( ! grep( /^${filevalidtimes{$ifile}}$/, @{$validtimelist{$filevalidday}} ) )
    {
      push @{$validtimelist{$filevalidday}}, $filevalidtimes{$ifile} ;  
    }
  }
### END OF SET FILENAME ANAL/FCST/VALID TIME ARRAYS
### CALC FINAL PROCESSING SUMMARY PRESENTATION TIMES (part2) & INITIALIZE SUMMARY VALUES
### overkill as many unused indexs initialized - but ensures all values initialized
  foreach $validday (@validdaylist)
  {
    ### order with largest fcst times first
    if( $#{$fcsttimelist{$validday}} > -1 )
    {
      @{$fcsttimelist{$validday}} = sort { $b <=> $a } @{$fcsttimelist{$validday}} ;
    }
  }
  $avgextendedvalidtime = nint( $avgextendedvalidtime / $nfiles ) ; 
### CREATE LIST OF UNIQUE _BLIPMAP_ VALIDATION TIMES TO BE DONE FOR EACH GRID
### used for clearing blipmap gifs
### and create inclusive one for all regions - used for aging of degrib subdirectories
  @blipmapvalidtimelist = ();
  foreach $regionkey (@REGION_DOLIST)
  {
     $#{$blipmapvalidtimes{$regionkey}} = -1;
     foreach $file (@{$GRIBFILE_DOLIST{$regionkey}})
     {
       if ( ! grep(/^${filevalidtimes{$file}}$/,@{$blipmapvalidtimes{$regionkey}}) )
       {
         push ( @{$blipmapvalidtimes{$regionkey}}, $filevalidtimes{$file} ); 
       }
       ### create inclusive one for all regions - note is array whereas regional is a hash
       if ( ! grep(/^${filevalidtimes{$file}}$/,@blipmapvalidtimelist) )
       {
         push ( @blipmapvalidtimelist, $filevalidtimes{$file} ); 
       }
     }
  }
### CREATE INITIAL ARRAY OF RECEIVED FILE FLAGS
  foreach $regionkey (@REGION_DOLIST)
  {
     for ( $iifile=0; $iifile<=$#{$GRIBFILE_DOLIST{$regionkey}}; $iifile++ ) 
     {
       $blipmapfilereceivedflag{$regionkey}[$iifile] = 0;
     }
  }
### OPEN THREAD TIME SUMMARY FILES
  foreach $regionkey (@REGION_DOLIST)
  {    
    $SUMMARYFH{$regionkey} = *${regionkey} ;
    open ( $SUMMARYFH{$regionkey}, ">>${RUNDIR}/summary.gridcalctimes.${regionkey}" ) ;
    printf { $SUMMARYFH{$regionkey} } "\n%s: ", $rundayprt  ;
  }    
### CREATE DO LIST CONTAINING _entire_ FILENAME - also status array
  @filenamedolist = ();
  foreach $ifile (@filedolist)
  {
    ### add filename do list
    ### PARTIAL SPECIFICATION OF MODEL GRIB FILENAME HERE
    if ( $GRIBFILE_MODEL eq 'ETA' || $GRIBFILE_MODEL eq 'GFSN' || $GRIBFILE_MODEL eq 'GFSA' || $GRIBFILE_MODEL eq 'AVN' )
      {
        $filename = $filenamehead{$ifile} . $filetimes{$ifile} ;
        ### select directory based on init.time - 1=present vs 2=previous jdate
        if ( $ifile =~ /^ *\-/ )
          { $filenamedirectoryno{$ifile} = 0 ; }
        elsif ( $ifile =~ /^ *\+/ )
          { $filenamedirectoryno{$ifile} = 2 ; }
        else
          { $filenamedirectoryno{$ifile} = 1 ; }
      }
    elsif ( $GRIBFILE_MODEL eq 'RUCH'  )
      {
        $filename = $filenamehead{$ifile} . $filetimes{$ifile} ;
        $filenamedirectoryno{$ifile} = 1 ; 
      }
    push ( @filenamedolist, $filename );
    if ($LPRINT>1) {printf $PRINTFH ("   filenamedolist= %7s => %s %s\n",$ifile,$gribftpdirectory[$filenamedirectoryno{$ifile}],$filename);}
    ### set filestatus for files to be processed
    $filestatus{$ifile} = -1;
  }
  if ($LPRINT>1) {printf $PRINTFH ("FILENAMEdolist   count = %s\n",$dofilecount);}
  $ii=-1;
  foreach $ifile (@filedolist)
  {
    $ii=$ii+1;
    $filename = $filenamedolist[$ii];
    print $PRINTFH "   filename= $ii $ifile $filenamedirectoryno{$ifile} $gribftpdirectory[$filenamedirectoryno{$ifile}] $filename\n";
  }
  if ($LPRINT>1) {print $PRINTFH ("Begin CYCLE loop over Time/Filename\n" );}
### ENSURE THAT ALL NEEDED OUT BLIPMAP REGION DIRECTORIES EXIST
  foreach $regionname (@REGION_DOLIST)
  {
    $mkdirstring .= "$regionname ";
    ### include stage2-only case
    if( $LRUN_WINDOW{$regionname} > 0 ) { $mkdirstring .= "${regionname}-WINDOW "; }
  }  
  if ( $mkdirstring !~ m/^ *$/ ) { `cd $OUTDIR ; mkdir -p $mkdirstring`; }
### ENSURE THAT NEEDED SAVE DIRECTORIES EXIST
### save directory based on region-specific julian date intended to represent soaring day
  if ( $LSAVE >0 )
  {
    my  $localmin  ;
    foreach $regionname (@REGION_DOLIST)
    {
      ($gribanalhr,$gribfcstperiod) = split /Z\+/, $GRIBFILE_DOLIST{$regionname}[0] ;    
      ( $localyyyy,$localmm,$localdd,$localhh, $localmin ) = &GMT_plus_mins( $jyr4, $jmo2, $jda2, $gribanalhr, 0, (60*($gribfcstperiod+$LOCALTIME_ADJ{$regionname})) );
      ### with added year subdirectory to allow archiving alternatives
      $savesubdir{$regionname} = sprintf "%s/%s/%4d/%4d%02d%02d",$SAVEDIR,$regionname,$localyyyy,$localyyyy,$localmm,$localdd;
      `mkdir -p $savesubdir{$regionname} 2>/dev/null`;
      if ($LPRINT>1) { printf $PRINTFH ("   Created SAVE directory $savesubdir{$regionname} \n" ); }
    }  
  }
####### START CYCLE LOOP OVER TIME #######
  $runstartsec = time();
  $runstarttime = `date +%H:%M` ; jchomp($runstarttime);
  $elapsed_runhrs = 0.;
  $icycle = 0;
  $foundfilecount = 0;
  $filename = 'INITIAL_VALUE';
  $lastfilename = '';
  $successfultimescount = 0;
  $nextskipcount = 0;
  $oldtimescount = 0;
  CYCLE: while ( $elapsed_runhrs < $cycle_max_runhrs && $icycle < $cycle_max )
  {
####### INTERRUPT SIGNAL (Ctrl-C) WILL END CYCLE AND SKIP TO END PROCESSING #######
    $SIG{'INT'} = \&signal_endcycle;
    $icycle = $icycle + 1;
    $cycletime = `date +%H:%M:%S` ;  jchomp($cycletime);
    if ($LPRINT>1) {printf $PRINTFH ("CYCLE: TOP %d/%d %4.1f/%4.1fhr %02d(%02d/%02d) - last= %s at %s\n", $icycle,$cycle_max,$elapsed_runhrs,$cycle_max_runhrs,$foundfilecount,$successfultimescount,$dofilecount,$lastfilename,$cycletime);}
    $elapsed_runhrs = (time ()- $runstartsec ) / 3600. ;
    ### printout process info, incl. memory usage, to track possible probs
    $psout = `ps --no-header -o pid,priority,nice,%cpu,%mem,size,rss,sz,tsiz,vsize  $$`;
    jchomp( $psout ); 
    if ($LPRINT>1) { print $PRINTFH "   PS: $psout\n"; }
    ### CALL TO GET GRIB ALA CHOSEN LGETGRIB
    &do_getgrib_selection;
    ### DOWNLOAD GRIB FILE
    $ftptime0{$ifile} = `date +%H:%M:%S` ;  jchomp($ftptime0{$ifile});
    if ( $LGETGRIB > 1 && $LMODELRUN > 0 )
    {
      ### -i argument allows killing existing job, changing code, removing all old grib files, and restarting with appends to existing grib files
      if( $RUNTYPE ne '-i' )
        { $rmout = `rm -v ${GRIBDIR}/*${filetimes{$ifile}} 2>&1`; }
        ### parallel-ftp gribftpget.pl does _not_ delete any grib files
        if ($LPRINT>2) { print $PRINTFH "${ifile}: pre-grib-download rm of previous grib file: $rmout"; }
      ### now adjust $gribgetftptimeoutsec sent to routine so should end ftp+calc prior to switching time
      if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' )
      {
        $sec2finalcalcstart =  3600.*( &zulu2local( $switchingtimehrz{$GRIBFILE_MODEL} ) - &hhmm2hour( $ftptime0{$ifile} ) ) - 60.*$mincalcmin{$GRIBFILE_MODEL};
        if ( $sec2finalcalcstart < 0 ) { $sec2finalcalcstart += 24*3600 ; }
        if ( $sec2finalcalcstart < $gribgetftptimeoutmaxsec )
           { $gribgetftptimeoutsec = $sec2finalcalcstart ; }
        else
           { $gribgetftptimeoutsec = $gribgetftptimeoutmaxsec ; }
      }
      else
      {
        $gribgetftptimeoutsec = $gribgetftptimeoutmaxsec;
      }
      ### SET ARGUMENT LIST
      ### this sends single comma-delimited string
      ### *NB* JOBARG not really needed as an argument at present
      ### NEED DIFFERENT TREATMENT FOR DOWNLOAD OF LIMITED AREA GFS GRIB FILE
      if( $GRIBFILE_MODEL eq 'GFSA' && defined $GRIB_LEFT_LON && defined $GRIB_RIGHT_LON && defined $GRIB_TOP_LAT && defined $GRIB_BOTTOM_LAT )
      {
        $args = join ',', (
        "$BASEDIR/UTIL/curl",
        $filename,
        $GRIB_LEFT_LON,
        $GRIB_RIGHT_LON,
        $GRIB_TOP_LAT,
        $GRIB_BOTTOM_LAT,
        $ifile,
        $GRIBFTPSTDOUT,
        $GRIBFTPSTDERR,
        $GRIBDIR,
        $childprintoutfilename
         );
        $gribgetcommand = "$UTILDIR/ftp2u_subregion.pl";
      }
      elsif( $GRIBFILE_MODEL eq 'AVN' && defined $GRIB_LEFT_LON && defined $GRIB_RIGHT_LON && defined $GRIB_TOP_LAT && defined $GRIB_BOTTOM_LAT )
      {
        $args = join ',', (
        "$BASEDIR/UTIL/curl",
        $filename,
        $GRIB_LEFT_LON,
        $GRIB_RIGHT_LON,
        $GRIB_TOP_LAT,
        $GRIB_BOTTOM_LAT,
        $ifile,
        $GRIBFTPSTDOUT,
        $GRIBFTPSTDERR,
        $GRIBDIR
         );
        $gribgetcommand = "$UTILDIR/ftpgetdat_ftp2u.pl";
      }
      else
      {
      ### STANDARD (NON-TRUNCATED) GRIB FILE DOWNLOAD
        $args = join ',', (
                  $JOBARG,
                  $GRIBFILE_MODEL,
                  $ifile,
                  $rundayprt,
                  $gribftpsite,
                  "${gribftpdirectory0}/${filenamedirectory}",
                  $filename,
                  $GRIBFTPSTDOUT,
                  $GRIBFTPSTDERR,
                  $RUNDIR,
                  $GRIBDIR,
                  "$BASEDIR/UTIL",
                  $cycle_waitsec,
                  $gribgetftptimeoutsec,
                  $mingribfilesize,
                  $childprintoutfilename
         );
        ### CREATE BACKGROUND FTP JOB
	  
       $gribgetcommand = "$UTILDIR/gribftpget.pl";   
	  ###$gribgetcommand = "$UTILDIR/wgetNAMdata";    ## tjo quick and dirty bash script
      }
      if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time) ; print $PRINTFH "${ifile}: Grib file Download Request $gribgetcommand at $time"; }
      my $childftpproc = Proc::Background->new( $gribgetcommand, $args );
      if ( $childftpproc->alive )
      {
        push @childftplist, $ifile;
        $childftpobject{$ifile} = $childftpproc;
        $childftppid{$ifile} = $childftpproc->pid ;
        print $PRINTFH "${ifile}: call child gribftpget routine: timeout = $gribgetftptimeoutsec for: $filename at:$gribftpsite/${gribftpdirectory0}/${filenamedirectory}/$filename\n";
      }
      else
      {
        print $PRINTFH ("*** FTP CHILD CREATION FAILED for $ifile - skip this file \n");
        goto NEWGRIBTEST; 
      } 
    }
    else
    {
      print $PRINTFH ("${ifile}: TEST/RERUN MODE run with *NO*GETGRIB* DOWNLOAD\n");
    }
    NEWGRIBTEST: 
    @oldchildftplist =  @childftplist;
    @childftplist = ();
    ### expect child gribftpget processes started later to have later initialization times, so do them first
    for ( $ilist=$#oldchildftplist; $ilist>=0; $ilist-- )
    {
      $ifile = $oldchildftplist[$ilist];
      $childftpproc = $childftpobject{$ifile};
      $childftppid = $childftppid{$ifile};
      ### SET VALUES CONSTANT FOR FILE (FOR ALL POINTS)
      ($ifilegreptest = $ifile ) =~ s/\+/\\\+/g;
      $filevalidday = $filevaliddays{$ifile};
      $filefcsttime = $filefcsttimes{$ifile};
      $filevalidtime = $filevalidtimes{$ifile};
      $fileanaltime = $fileanaltimes{$ifile};
     my $filevalidtimeplus = $filevalidtimepluses{$ifile};
      $fileextendedvalidtime = $fileextendedvalidtimes{$ifile};
      $filename = $filename{$ifile};
      $filenamedirectory = $filenamedirectory{$ifile};
     my $fullfilename = "${GRIBDIR}/${filename}"; 
      $time = `date +%H:%M:%S` ;  jchomp($time);
      ### START OF SKIP TEST OF FTP PROCEESSES IF TEST MODE
      if ( $LGETGRIB > 1 )
      {
        ### don't process fcst time if shorter term one already done for this valid time
        ### putting kill here leads to delays in killing (vice putting immediately after successful run status change)
        ###    but is more convenient since loop exists here and can conveniently remove the $ifile from @childftplist
        if ( $filefcsttimes{$ifile} > $latestfcsttime[$fileextendedvalidtimes{$ifile}] && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
         {
           if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER NEWGRIBTEST $ifile - previous $filevalidtimes{$ifile}Z validation time (extended=${fileextendedvalidtimes{$ifile}}) had shorter fcst time = $latestfcsttime[$fileextendedvalidtime]\n" );}
           ### setting this status will caused file to be ignored later
           $filestatus{$ifile} = $status_skipped; 
           $oldtimescount++;
           ### kill entire pstree  - killing child will _not_ kill gribftpget or curl processes it creates (at least not when job run with nohup)
           my $killout = &kill_pstree( $childftppid );
           if ($LPRINT>1) {print $PRINTFH ("                       killed entire ps tree ftping $filename => $killout \n" );}
           next;
         }
        if ( $childftpproc->alive )
        {
          ### keep same order in childftplist
          unshift @childftplist, $ifile;
          next;
        }
        $childtest = $childftpproc->wait ;
        $child_exit_value  = $childtest >> 8 ;      #=int($?/256)  
        $child_signal_num  = $childtest & 127 ;     #=($?-256*exit_value#)
        ### also calculate total download speed, including any partial downloads
        my ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = localtime( $childftpproc->end_time );
        $endhhmmss = sprintf "%02d:%02d:%02d", $hour,$min,$sec ;
        &print_download_speed ( 'FULL_Download', $ftptime0{$ifile}, $endhhmmss );
        ### TREAT GRIBFTPGET ERROR CASES
        ### treat case of job killed by a signal by skipping that file
        if ( $child_signal_num != 0 )
        {
          $filestatus{$ifile} = $status_skipped; 
          my $killout = &kill_pstree( $childftppid );
          if ($LPRINT>1) {print $PRINTFH ("** SKIPPING $ifile at $time  - CHILD gribftpget RETURNED NON-ZERO CURL SIGNAL = $child_signal_num SO KILL PS TREE & SKIP PROCESSING \n" );}
          goto STRANGE_CYCLE_END;
        }
        ### treat any other non-zero exit code by skipping that file
        elsif ( $child_exit_value != 0 )
        {
          $filestatus{$ifile} = $status_skipped; 
          if ($LPRINT>1) {print $PRINTFH ("** SKIPPING $ifile at $time  - CHILD gribftpget RETURNED UNRECOVERABLE CURL EXIT VALUE = $child_exit_value SO SKIP PROCESSING \n" );}
          goto STRANGE_CYCLE_END;
        }
      ### END OF SKIP TEST OF FTP PROCEESSES IF TEST MODE
      }
      ### IF REACH HERE, MUST HAVE BEEN A SUCCESSFUL GRIB FTP GET
      STARTNEWGRIB: 
      $foundfilecount = $foundfilecount +1;
      ### CALCULATION INITIALIZATION  
      $calctime0 = `date +%H:%M:%S` ; jchomp($calctime0);
      ### PRINT HEADER FOR START OF NEW FILE CALCULATION
      printf $PRINTFH ("   NEW_GRIB_FILE_RECEIVED : %s  %02d(%02d/%02d)  %7s => %7s %2dZ  %s %s\n",$calctime0,$foundfilecount,$successfultimescount,$dofilecount,$ifile,$filevaliddays{$ifile},$filevalidtimes{$ifile},$filenamedirectory,$filename);
      ### INITIALIZE ERROR FLAGS 
      ######### DO grib_prep FOR EACH GRIB FILE INDIVIDUALLY TO ALLOW THREADED TREATMENT (so threads won't step on each other)
      ######### SO MUST SET SI PARAMS PRIOR TO CALL TO grib_prep
      ### SET ENVIRONMENTAL VARIABLES NEEDED BY WRFSI (except for $ENV{MOAD_DATAROOT} which depends on $regionkey)
      ### set universal paths
      $ENV{INSTALLROOT} = "$WRFBASEDIR/WRFSI";
      $ENV{SOURCE_ROOT} = "$WRFBASEDIR/WRFSI";
      $ENV{TEMPLATES} = "$WRFBASEDIR/WRFSI/templates";
      $ENV{DATAROOT} = "$WRFBASEDIR/WRFSI/domains";
      $ENV{EXT_DATAROOT} = "$WRFBASEDIR/WRFSI/extdata";
      $ENV{GEOG_DATAROOT} = "$WRFBASEDIR/WRFSI/extdata/GEOG";
      ### OTHER ENV VARIABLES NEEDED FOR CRON RUN 
      $ENV{LD_LIBRARY_PATH} = "$BASEDIR/UTIL/PGI";
      $ENV{NCARG_ROOT} = $NCARG_ROOT ;
      ### from emprical tests, NetCDF executables (ncdump,ncgen) must be at /usr/local/netcdf/bin
      ###    use of NETCDF environ. variable OR UTIL/NETCDF path addition does not find ncdump/ncgen !
      $ENV{LANG} = 'en_US';                       # LANG MAY BE SUPERFLUOUS
      if ($LGETGRIB>0)
      {
        ### CALL EXTERNAL WRFSI SCRIPT TO PREP THIS GRIB FILE FOR LATER WRF INITIALIZATION PROCESSING    
        ### must use yyymmddhh associated with this grib file !
        ### need criteria for determining when tomorrow's julian date needed 
        ### DAY/HR SELECTION - this depends upon validation time of file
        if ( $filevaliddays{$ifile} eq 'curr.' )
        { 
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4},${jmo2},${jda2},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4m1},${jmo2m1},${jda2m1},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+1.' )
        {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p1},${jmo2p1},${jda2p1},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4},${jmo2},${jda2},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+2.' )
        {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p2},${jmo2p2},${jda2p2},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p1},${jmo2p1},${jda2p1},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+3.' )
        {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p3},${jmo2p3},${jda2p3},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p2},${jmo2p2},${jda2p2},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+4.' )
        {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p4},${jmo2p4},${jda2p4},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p3},${jmo2p3},${jda2p3},${filevalidtime};
        }
        else 
        { print $PRINTFH "$program ERROR EXIT - grib_yyyymmddhh bad filevaliddays =  $ifile $filevaliddays{$ifile} "; exit 1; }
        ### DELETE OLD WRFSI/extdata/extprd & log files created by grib_prep
        ### old grib_prep output files in WRF/WRFSI/extprd not overwritten since are model/day/time stamped
        ### cant use grib_prep -P option since could possibly erase file from another run sill being used (though unlikely)
        ### so instead delete previous model/day/time stamped files from WRF/WRFSI/extprd
        ### BUT run glitches occasionally leave orphaned older extprd files which never get deleted !
        ###     these extprd file can be huge (150-200MB for RUC/GFS) and take up much space
        ###     so also look for and remove extprd files older than 1 day if operational run
        if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i')
        {
          ### delete yesterday's grib_prep output file
          &fileage_delete ( "$ENV{EXT_DATAROOT}/extprd" , 86400 ) ;
          if ($LPRINT>1) { print $PRINTFH "      Removed yesterday\'s grib_prep output file $ENV{EXT_DATAROOT}/extprd/${GRIBFILE_MODEL}:${yesterday_grib_yyyymmddhh}"; } 
          ### find and delete any orphaned grib_prep output files more than 1 day old
          $oldrmout = `find $ENV{EXT_DATAROOT}/extprd -mtime +0 -name "${GRIBFILE_MODEL}:*" -follow -print | xargs rm -v  2>/dev/null`;
          $oldrmout =~ s|\n|\n         |g ;
          if( $oldrmout =~ m|removed| ) { if ($LPRINT>1) { print $PRINTFH "      Removed orphaned grib_prep output files: \n         ${oldrmout}"; } }
          if ($LPRINT>1) { print $PRINTFH "   Grib Prep using $grib_yyyymmddhh \n"; }
          ### REMOVE grib_prep LOGS OLDER THAN 1 DAY
          $oldrmout = `find $ENV{EXT_DATAROOT}/log -mtime +0 -name "*${GRIBFILE_MODEL}*" -follow -print | xargs rm -v  2>/dev/null`;
        }
        ### -P option removes older-than-startdate processed ETA* files from ../extprd directory - do NOT use when doing each file individually !
        ### here stderr goes to $gribprep_errout and stdout to site-specific log file
        ### use single-file filter ensure correct grib file used  (and add wildcard for test files with date-specific tail)
        ### (since several might have same valid time) and for efficiency (no need to look at more than one file)
        if( $LWINDOWRESTART != 1 )
        {
          if( $GRIBFILE_MODEL ne 'ETA' )
          {
            $gribprep_errout = `cd $WRFBASEDIR/WRFSI/etc ; ./grib_prep.pl -f "${filename}.*" -l 0 -t 1 -s $grib_yyyymmddhh $GRIBFILE_MODEL >| $ENV{EXT_DATAROOT}/log/grib_prep.${GRIBFILE_MODEL}.stdout`;  
          }
          else
          {
            ### KLUDGE TO ALLOW USE OF GRIB2 ETA/NAM FILES
            $gribconv_errout = `cd $GRIBDIR ; rm -f "${filename}.cnvgrib.out"; ${UTILDIR}/cnvgrib -g21 -nv "${filename}" "${filename}.cnvgrib.out"`;
            if ( $gribconv_errout !~ m|^\s*$| )
            {
               print $PRINTFH "*** ERROR: cnvgrib => error found in STDERR = $gribconv_errout \n";
            }
            $gribprep_errout = `cd $WRFBASEDIR/WRFSI/etc ; ./grib_prep.pl -f "${filename}.cnvgrib.out" -l 0 -t 1 -s $grib_yyyymmddhh $GRIBFILE_MODEL >| $ENV{EXT_DATAROOT}/log/grib_prep.${GRIBFILE_MODEL}.stdout`;
          }
        }
        else
        {
          ### $LWINDOWRESTART =1 FOR RESTART FROM NON-WINDOW IC/BC WITH PRE-EXISTING GRIB FILE USED FOR NEEDED LANDUSE, ETC DATA
          ###                   (USE HARD-WIRED DAY/TIME FOR AN EXISTING GRIB FILE)
          ###                   (else ala $foundfilecount=1,2,3 => $grib_yyyymmddhh= 2005041918,2005041921,2005042000, for filename 0510912000006.grib,0510912000009.grib,0510912000012.grib)
          print $PRINTFH "   $moad grib_prep uses landuse,etc data from existing grib file with hard-wired date! \n"; 
          $gribprep_errout = `cd $WRFBASEDIR/WRFSI/etc ; ./grib_prep.pl -f 0509212000006.grib -l 0 -t 1 -s 2005040218 $GRIBFILE_MODEL >| $ENV{EXT_DATAROOT}/log/grib_prep.${GRIBFILE_MODEL}.stdout`;  
        }
        ###  test for run errors
        $lrunerr = $?;
        chomp( $successtest = `grep -c -i 'normal termination' $ENV{EXT_DATAROOT}/log/gp_${GRIBFILE_MODEL}.${grib_yyyymmddhh}.log 2>/dev/null` ) ;
        if ( $gribprep_errout !~ m|^\s*$| )
        {
           print $PRINTFH "*** ERROR: grib_prep.pl => error found in STDERR = $gribprep_errout \n";
           ### continue after grib_prep error so as not to preclude later time slot run
        }
        elsif ( ! defined $successtest || $successtest eq '' || $successtest != 1 )
        {
           print $PRINTFH "*** ERROR: grib_prep.pl successtest=${successtest} !=1 => error reported in log file $ENV{EXT_DATAROOT}/log/gp_${GRIBFILE_MODEL}.${grib_yyyymmddhh}.log - STDERR= $gribprep_errout \n";
           ### continue after grib_prep error so as not to preclude later time slot run
        }
        elsif ( $lrunerr != 0 )
        {
           print $PRINTFH "*** ERROR: grib_prep.pl non-zero ReturnCode = $lrunerr - STDERR= $gribprep_errout \n";
           ### continue after grib_prep error so as not to preclude later time slot run
        }
        else
        {
           $lgribprepsuccess{$ifile} = 1 ;
           print $PRINTFH "      Exited $ifile grib_prep.pl with no detected error \n";
        }
      }
      else
      {
        $lgribprepsuccess{$ifile} = 1 ;
        if ($LPRINT>1) { print $PRINTFH "   ** LGETGRIB=0, so *SKIP* grib_prep.pl \n"; }
      }
      ########## START OF LOOP OVER REGIONS !!! ##########
      $kpid = 0;
      @childrunmodellist = ();
      $nstartedchildren = 0;
      REGION: foreach $regionkey (@REGION_DOLIST)
      {    
        ### use $regionname when not a hash key, such as a directory name, to allow different searching
        $regionname = $regionkey;
        ( $regionname_lc = $regionname ) =~ tr/A-Z/a-z/;
     ###### NOT USED BUT LEAVE FOR REFERENCE 
        ### SET PRINTED TIME FOR THIS FILE AND GRID
        $localtimeprt = $filevalidtime + $LOCALTIME_ADJ{$regionkey};
        jchomp( $localtimeid = `date +%Z` ); 
        $localtimeid = substr( $localtimeid, 1,2 );
        if( $localtimeid eq 'DT' || $localtimeid eq 'dt' )
          { $localtimeprt = $localtimeprt +1; }
        if( $localtimeprt < 0 ) { $localtimeprt = $localtimeprt + 24; }
        $localtimeid = substr( $LOCALTIME_ID{$regionkey}, 0,1 ) . $localtimeid;
        $localtimeid =~ tr/A-Z/a-z/;
        my $timeprt = $filevalidtimes{$ifile} . 'Z(' . $localtimeprt . $localtimeid . ')'; 
        ###### TEST IF NEEDED FILES NOW RECEIVED FOR ANY GRID - IF SO, RUN MODEL FOR IT
        ### test all possible run times (for simplicity), then change array of received file flags and test for all received
        $iifile = -1;
        $maxfcsttimes = ( $#{$blipmapfilereceivedflag{$regionkey}} + 1 ) / $GRIBFILES_PER_FORECAST_PERIOD{$regionkey} ; 
        for ( $iifcsttimes=1; $iifcsttimes<=$maxfcsttimes; $iifcsttimes++ )
        {
          $nreceived = 0;
          $ngribprepsuccess = 0;
          for ( $ii=1; $ii<=$GRIBFILES_PER_FORECAST_PERIOD{$regionkey}; $ii++ )
          {
            $iifile++;
            $fileid = $GRIBFILE_DOLIST{$regionkey}[$iifile];
            ### add this file to list of those received
            if( $fileid eq $ifile )
            { 
              $blipmapfilereceivedflag{$regionkey}[$iifile] = 1 ;
            }
            ### count total received
            if( $blipmapfilereceivedflag{$regionkey}[$iifile] == 1 )
            {
              $nreceived++;
            }
            if( $lgribprepsuccess{$fileid} == 1 )
            {
              $ngribprepsuccess++;
            }
          }
          if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time) ; print $PRINTFH  "   Check for needed $regionkey files of rungroup $iifcsttimes found ${nreceived}/${GRIBFILES_PER_FORECAST_PERIOD{$regionkey}} received with $ngribprepsuccess grib_prep success at $time \n"; }
          ### go to model processing when required grib files obtained
          if ( $nreceived == $GRIBFILES_PER_FORECAST_PERIOD{$regionkey} 
          ### add check that all grep_prep processing was successful
             && ( $ngribprepsuccess == $nreceived || $LMODELINIT == 0 ) )
          {
            ### reset blipmapfilereceivedflag so these files not processed again
            for ( $jjfile=$iifile; $jjfile>=($iifile-$GRIBFILES_PER_FORECAST_PERIOD{$regionkey}+1); $jjfile-- )
            {
              $blipmapfilereceivedflag{$regionkey}[$jjfile] = -1; 
            }
            ### empty list of already processed output files
            @{$finishedoutputhour{$regionkey}} = ( "" );        
            ### go to processing section
            goto ALL_GRIBFILES_AVAILABLE ;
          }
        }
        ### AT PRESENT REQUIRE *ALL* REQUESTED GRIB FILES TO BE RECEIVED TO RUN MODEL
        $nreceived = 0;
        next REGION;
        ### START OF SECTION PROCESSED IF ALL NEEDED GRIB FILES OBTAINED FOR A FORECAST RUN
        ALL_GRIBFILES_AVAILABLE:
        ### SET VARIABLES NEEDED BY PLOT PROCESSING PRIOR TO CREATING CHILD PROCESSES
        ### this section had been placed after child creation - assumes variables same for all regions
        ### DETERMINE VALID DAY & ANAL TIME & FCST PERIOD OF GRIB FILE USED FOR RASP INITIALIZATION
        ### kludgey method uses position of a file in  GRIBFILE_DOLIST so requires %gribfile_dolist ordering to increase in each group
        for( $iifile=0; $iifile<=$#{$GRIBFILE_DOLIST{$regionkey}}; $iifile++ )
        {
          if( $ifile eq $GRIBFILE_DOLIST{$regionkey}[$iifile] )
          {
            $groupnumber = int( $iifile/$GRIBFILES_PER_FORECAST_PERIOD{$regionkey} +1);
            $startindex = $GRIBFILES_PER_FORECAST_PERIOD{$regionkey}* ($groupnumber -1);
            last;
          }
        }
        $startifile = $GRIBFILE_DOLIST{$regionkey}[$startindex];
        $startvalidday =  $filevaliddays{$startifile} ;
        ### FIND FORECAST PERIOD AND ANAL TIME OF INITIALIZATION GRIB FILE
        $gribanaltime = $fileanaltimes{$startifile} ;
        $gribfcstperiod = $filefcsttimes{$startifile} ;
        $hhinit = $gribanaltime + $gribfcstperiod - 24*int( ($gribanaltime+$gribfcstperiod)/24 ) ;
        ### DETERMINE NUMBER OF DOMAINS for non-window & window runs
        jchomp( $MAXDOMAIN{$regionkey}[0] = `grep -i 'max_dom' $WRFBASEDIR/WRFV2/RASP/$regionkey/namelist.template` );
        $MAXDOMAIN{$regionkey}[0] =~ s/^.*= *([0-9]).*$/$1/ ; 
        if ( $LRUN_WINDOW{$regionkey} > 0 )
        {
          jchomp( $MAXDOMAIN{$regionkey}[1] = `grep -i 'max_dom' $WRFBASEDIR/WRFV2/RASP/${regionkey}-WINDOW/namelist.template` );
          $MAXDOMAIN{$regionkey}[1] =~ s/^.*= *([0-9]).*$/$1/ ; 
          $MAXDOMAIN{$regionkey}[2] = $MAXDOMAIN{$regionkey}[1] ;
        }
        $nstartedchildren++;
        if ($LPRINT>1) { print $PRINTFH  "   ALL needed $regionkey rungroup $groupnumber files received so initiate run\n"; }
        ### START OF THREADEDREGIONRUN IF FOR CHILD CREATION
        ### allow debug tests of threaded case plots which skip model init+run to not create child processes
        if ( $LMODELINIT == 0 && $LMODELRUN == 0 )
        {
          print $PRINTFH "   ** LMODELINIT=LMODELRUN=0, so *SKIP* ENTIRE MODEL SEQUENCE FOR $regionkey \n"; 
        }
        ### FOR THREADED REGIONRUN, CREATE CHILD PROCESS FOR EACH REGION
        elsif ( $LTHREADEDREGIONRUN == 1 && ! defined( $kpid = fork() ) )
        {
          print $PRINTFH "THREAD OS ERROR IN PROCESS $$ RUNNING $program $JOBARG for $regionkey - cannot fork error = $!";
          exit 1;
        }
        elsif ( $LTHREADEDREGIONRUN == 0 || $kpid == 0 )
        {
          $gridcalcstarttime = `date +%H:%M` ; jchomp($gridcalcstarttime);
          if( $LTHREADEDREGIONRUN == 1 )
          {
            ### FOR THREADED REGIONRUN, THIS IS CHILD PROCESS since fork returned 0
            ### IF CHILD, SET NEW PROGRAM NAME TO DISPLAY IN FORK'S ps
            $0 = "rasp-${JOBARG}child${regionkey}";
            print $PRINTFH "   >>> $regionkey THREADED CHILD RUNMODEL STARTED under $RUNPID for $regionkey at $gridcalcstarttime \n";
          }
          else
          {
            print $PRINTFH "   >>> $regionkey NON-THREADED RUNMODEL STARTED for $regionkey at $gridcalcstarttime \n";
          }
          ### SET TIMEOUT FOR ENTIRE MODEL INIT/RUN SECTION (THREAD)
          if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i')
          {
            local $SIG{ALRM} = sub { $time=`date +%H:%M:%S`; jchomp($time); print $PRINTFH "*** $regionname MODEL RUN/INIT *TIMED*OUT* at $time\n"; &final_processing; };
            alarm ( $gridcalctimeoutsec );
          }
          for( $IWINDOW=$iwindowstart{$regionkey}; $IWINDOW<= $iwindowend{$regionkey}; $IWINDOW++ )
          {
            ### SET NAME OF CURRENT CASE HERE
            ###  $LRUN_WINDOW=1 used for REGIONXYZ-WINDOW RUN (assumes needed wrfout files in REGIONXYZ directory)
            if ( $IWINDOW == 0 )
            ### include stage2-only case
            { $moad = $regionname; }
            else
            { $moad = $regionname . "-WINDOW"; }
            if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time); print $PRINTFH "   START $regionname MODEL RUN LOOP $IWINDOW FOR $moad at $time\n";}
            ### INITIALIZATIONS
            %imageloopfilelist = ();
            ### SET INITIALIZATION TIME FOR ALL DOMAINS  - do here so available outside region thread      
            ###     MEANS THAT START/END MUST BE SAME FOR ALL REGIONS !
          ### DAY/HR SELECTION - this depends upon start/end time of run
          ### WEAKNESS: GRIB GETS TREATED LARGELY INDEPENDENTLY YET ACTUALLY DISTINCT GROUPS
          ### so put kludgey way of determining day of valid time of first file
          ### LATER: REPLACE $DOMAIN1_STARTHH,$DOMAIN1_ENDHH with $DOMAIN1_START_DELTAMINS,$DOMAIN1_END_DELTAMINS
          ###        AND MAKE ALL "DELTAMINS" PARAMS RELATIVE TO START/END *GRIB* FILE TIMES FOR CONSISTENCY
          ### second case treats window run with start on same day as stage1
          ### (note that assumes that run will be for less than 24hrs)
          if( $IWINDOW==0 || $DOMAIN1_STARTHH{$regionname}[0] < $DOMAIN1_STARTHH{$regionname}[1] )
          {
            if( $startvalidday eq 'curr.' )
            {
                  $startyyyy4dom[1] = $jyr4;
                  $startmm4dom[1] = $jmo2;
                  $startdd4dom[1] = $jda2;
            }
            elsif( $startvalidday eq 'curr+1.' )
            {
                  $startyyyy4dom[1] = $jyr4p1;
                  $startmm4dom[1] = $jmo2p1;
                  $startdd4dom[1] = $jda2p1;
            }
            elsif( $startvalidday eq 'curr+2.' )
            {
                  $startyyyy4dom[1] = $jyr4p2;
                  $startmm4dom[1] = $jmo2p2;
                  $startdd4dom[1] = $jda2p2;
            }
            elsif( $startvalidday eq 'curr+3.' )
            {
                  $startyyyy4dom[1] = $jyr4p3;
                  $startmm4dom[1] = $jmo2p3;
                  $startdd4dom[1] = $jda2p3;
            }
            else
            { print $PRINTFH "*** ERROR EXIT - start day not valid: $IWINDOW $startvalidday "; exit 1; }
          }
          ### treat window run with start on day after stage1
          else
          {
            if( $startvalidday eq 'curr.' )
            {
                  $startyyyy4dom[1] = $jyr4p1;
                  $startmm4dom[1] = $jmo2p1;
                  $startdd4dom[1] = $jda2p1;
            }
            elsif( $startvalidday eq 'curr+1.' )
            {
                  $startyyyy4dom[1] = $jyr4p2;
                  $startmm4dom[1] = $jmo2p2;
                  $startdd4dom[1] = $jda2p2;
            }
            elsif( $startvalidday eq 'curr+2.' )
            {
                  $startyyyy4dom[1] = $jyr4p3;
                  $startmm4dom[1] = $jmo2p3;
                  $startdd4dom[1] = $jda2p3;
            }
            elsif( $startvalidday eq 'curr+3.' )
            {
                  $startyyyy4dom[1] = $jyr4p4;
                  $startmm4dom[1] = $jmo2p4;
                  $startdd4dom[1] = $jda2p4;
            }
            else
            { print $PRINTFH "*** ERROR EXIT - window start day not valid: $IWINDOW $startvalidday "; exit 1; }
          }
          $starthh4dom[1] = $DOMAIN1_STARTHH{$regionname}[$IWINDOW];
          ### ALLOW DIFFERENT STARTS FOR DIFFERENT DOMAINS
          for ( $idomain=2 ; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW] ; $idomain++ )
          {
            my $startdeltamins ;
            eval "\$startdeltamins = \$DOMAIN${idomain}_START_DELTAMINS{\$regionname}[\$IWINDOW]" ; 
            ( $startyyyy4dom[$idomain],$startmm4dom[$idomain],$startdd4dom[$idomain],$starthh4dom[$idomain], $min2 ) = &GMT_plus_mins( $startyyyy4dom[$idomain-1],$startmm4dom[$idomain-1],$startdd4dom[$idomain-1],$starthh4dom[$idomain-1], 0, $startdeltamins ) ; 
          }
          ### DAY/HR SELECTION - this depends upon start/end time of run
          ( $endyyyy4dom[1],$endmm4dom[1],$enddd4dom[1],$endhh4dom[1], $min2 ) = &GMT_plus_mins( $startyyyy4dom[1],$startmm4dom[1],$startdd4dom[1],$starthh4dom[1], 0, (60*$FORECAST_PERIODHRS{$regionname}[$IWINDOW]) ); 
          for ( $idomain=2 ; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW] ; $idomain++ )
          {
            my $enddeltamins ;
            eval "\$enddeltamins = \$DOMAIN${idomain}_END_DELTAMINS{\$regionname}[\$IWINDOW]" ; 
            ( $endyyyy4dom[$idomain],$endmm4dom[$idomain],$enddd4dom[$idomain],$endhh4dom[$idomain], $min2 ) = &GMT_plus_mins( $startyyyy4dom[$idomain],$startmm4dom[$idomain],$startdd4dom[$idomain],$starthh4dom[$idomain], 0, (60*$FORECAST_PERIODHRS{$regionname}[$IWINDOW]+$enddeltamins) ); 
          }
              ### PRINT START/END INFO
              if ($LPRINT>1)
              { 
                for ($idomain=1; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW]; $idomain++ )
                {
                   printf $PRINTFH "      $moad DOMAIN $idomain START-END = %s-%s-%s:%sZ - %s-%s-%s:%sZ \n", $startyyyy4dom[$idomain],$startmm4dom[$idomain],$startdd4dom[$idomain],$starthh4dom[$idomain], $endyyyy4dom[$idomain],$endmm4dom[$idomain],$enddd4dom[$idomain],$endhh4dom[$idomain] ; 
                }
              }
              ### FOR WINDOWED RUN, TEMPORARILY SET START DAY/TIME TO NON-WINDOW VALUES FOR wrfprep RUN (whatta mess!)
              ### since  need valid wrfprep output file for real.exe to run !
              if( $IWINDOW == 1 )
              {
                ### first save true values
                $truewindow_startyyyy4dom[1] = $startyyyy4dom[1] ;
                $truewindow_startmm4dom[1]   = $startmm4dom[1] ;
                $truewindow_startdd4dom[1]   = $startdd4dom[1] ;
                $truewindow_starthh4dom[1]   = $starthh4dom[1] ;
                $truewindow_startyyyy4dom[2] = $startyyyy4dom[2] ;
                $truewindow_startmm4dom[2]   = $startmm4dom[2] ;
                $truewindow_startdd4dom[2]   = $startdd4dom[2] ;
                $truewindow_starthh4dom[2]   = $starthh4dom[2] ;
                ### now set fake start time for wrfprep (only domain1 actually used, but do both) - fake start hour must have grib file available
                $fakedomain1_startyyyy[0] = $startyyyy4dom[1] ;
                $fakedomain1_startmm[0] = $startmm4dom[1]  ;
                $fakedomain1_startdd[0] = $startdd4dom[1];
                $fakedomain1_starthh[0] = 3*int($starthh4dom[1]/3) ;   # assume 3 hr increment grib files - must  have grib file for this hour
                $startyyyy4dom[1] = $fakedomain1_startyyyy[0] ;
                $startmm4dom[1]   = $fakedomain1_startmm[0] ;
                $startdd4dom[1]   = $fakedomain1_startdd[0] ;
                $starthh4dom[1]   = $fakedomain1_starthh[0] ;
                $startyyyy4dom[2] = $fakedomain1_startyyyy[0] ;
                $startmm4dom[2]   = $fakedomain1_startmm[0] ;
                $startdd4dom[2]   = $fakedomain1_startdd[0] ;
                $starthh4dom[2]   = $fakedomain1_starthh[0] ;
              }
              ### SET ONE ENVIRONMENTAL VARIABLE WHICH DEPENDS ON $regionkey
              ### used to set name of current case ($moad) here but moved to start of grid loop
              ### set case-specific path
              $ENV{MOAD_DATAROOT} = "$WRFBASEDIR/WRFSI/domains/$moad";
              ### KEEP LAST WRF REAL/EXE OUTPUT & namelist.input FILES IF NON-TEST RUN
              ### only remove previous file if is an existing non-previous output files
              @filelist = `cd $WRFBASEDIR/WRFV2/RASP/$moad ; ls -1 real.out* 2>/dev/null`;
              if ( $LMODELRUN>0 && $#filelist > -1 )
              {
                ### only remove previous files if there are existing non-previous files
                `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/previous.real.out*`;
                foreach $filename (@filelist)
                {
                  jchomp($filename);
                  `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/$filename $WRFBASEDIR/WRFV2/RASP/$moad/previous.${filename} 2>/dev/null`;
                }
                if ($LPRINT>1) { print $PRINTFH "      Previous $moad real.out* files found and pre-pended with \"previous.\" \n"; }
              }
              if ( $LMODELRUN>0 && -f "$WRFBASEDIR/WRFV2/RASP/$moad/wrf.out"  )
              {
                if ($LPRINT>2) { print $PRINTFH "      Previous $moad wrf.out file found and pre-pended with \"previous.\" \n"; }
                `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/wrf.out $WRFBASEDIR/WRFV2/RASP/$moad/previous.wrf.out 2>/dev/null`;
              }
              if ( $LMODELRUN>0 && -f "$WRFBASEDIR/WRFV2/RASP/$moad/namelist.input"  )
              {
                if( $LMODELINIT > 0 )
                {
                  `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/namelist.input $WRFBASEDIR/WRFV2/RASP/$moad/previous.namelist.input 2>/dev/null`;
                  if ($LPRINT>2) { print $PRINTFH "      Previous $moad namelist.input file found and pre-pended with \"previous.\" \n"; }
                }
                else
                {
                  ### for run without new initialization must use existing namelist.input file for this run
                  `cp -pf $WRFBASEDIR/WRFV2/RASP/$moad/namelist.input $WRFBASEDIR/WRFV2/RASP/$moad/previous.namelist.input 2>/dev/null`;
                  if ($LPRINT>1) { print $PRINTFH "   ** LMODELINIT=0, so existing $moad namelist.input file used for this run - also copied to \"previous.namelist.input\" \n"; }
                }
              }
              ### RENAME OLD WRF EXE OUTPUT FILE PRIOR TO THREAD, SO NOT FOUND AT FIRST THREADED PLOT
              ### KEEP ONLY PREVIOUS DAY WRF EXEC OUTPUT FILES
              ### for threaded plot output, must remove output files from previous jobs
              @filelist = `cd $WRFBASEDIR/WRFV2/RASP/$moad ; ls -1 wrfout* 2>/dev/null`;
              ### only remove previous files if there are existing non-previous output files
              ### include stage2-only case - must also do for $LRUN_WINDOW=1 since then moad=$regionname-WINODW
              if ( $LMODELRUN>0 && $#filelist > -1 )
              {
                `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/previous.wrfout*`;
                foreach $filename (@filelist)
                {
                  jchomp($filename);
                  `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/$filename $WRFBASEDIR/WRFV2/RASP/$moad/previous.${filename} 2>/dev/null`;
                }
                if ($LPRINT>2) { print $PRINTFH "      Previous $moad wrfout files found and pre-pended with \"previous.\" (older previous files deleted)\n"; }
              }
              #### here $regionname = $regionkey 
              if ( $LRUN_WINDOW{$regionname} > 1 && $IWINDOW == 0 )
              {
                $moadwindow = $moad . "-WINDOW"; 
                @filelist = `cd $WRFBASEDIR/WRFV2/RASP/$moadwindow ; ls -1 wrfout* 2>/dev/null`;
                if ( $LMODELRUN>0 && $#filelist > -1 )
                {
                  `rm -f $WRFBASEDIR/WRFV2/RASP/$moadwindow/previous.wrfout*`;
                  foreach $filename (@filelist)
                  {
                    jchomp($filename);
                    `mv -f $WRFBASEDIR/WRFV2/RASP/$moadwindow/$filename $WRFBASEDIR/WRFV2/RASP/$moadwindow/previous.${filename} 2>/dev/null`;
                  }
                  if ($LPRINT>2) { print $PRINTFH "      Previous $moadwindow wrfout files found and pre-pended with \"previous.\" after deleting existing previous files \n"; }
                }
              }
              ### SET yyyymmddhh for INITIALIZATION HERE SO KNOWN IN BOTH INIT AND RUN SECTIONS
              $run_yyyymmddhh = sprintf "%4d%02d%02d%02d", $startyyyy4dom[1],$startmm4dom[1],$startdd4dom[1],$starthh4dom[1];
              ### DO MODEL INITIALIZATION
              if ($LMODELINIT>0)
              {
                if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time) ; print $PRINTFH "   $moad MODEL PREPARATION using $run_yyyymmddhh at $time \n"; }
                ### IF LATER CHANGE TO DOING A GROUP grib_prep, DO IT HERE
                ### KEEP ONLY LAST LOG from wrfprep stage
                `rm -f $ENV{MOAD_DATAROOT}/log/previous.*`;
                @filelist = split /\s+/,`cd $ENV{MOAD_DATAROOT}/log/ ; ls -1 2* 2>/dev/null`;
                foreach $filename (@filelist)
                {
                   jchomp($filename);
                  `mv -f $ENV{MOAD_DATAROOT}/log/$filename $ENV{MOAD_DATAROOT}/log/previous.${filename} 2>/dev/null`;
                }
		### afer naming to previous, copy the existing_parent log files to the subnest  tjo   
		if ( -s "$BASEDIR/WRF/WRFV2/RASP/${existing_parent}"  && $runmultinest == 1 )  {
                  if ($LPRINT>2) { print $PRINTFH "  Running multi nest with ${existing_parent} as existing_parent for $JOBARG    \n"; }
		`rm -f  $BASEDIR/WRF/wrfsi/domains/${JOBARG}-WINDOW/log/*.* `;    
		`cp $BASEDIR/WRF/WRFSI/domains/${existing_parent}-WINDOW/log/${run_yyyymmddhh}.*  $BASEDIR/WRF/wrfsi/domains/${JOBARG}-WINDOW/log/` ;
#                  if ($LPRINT>1) { print $PRINTFH "  using $existing_parent-WINDOW/log/$run_yyyymmddhh. to check previous runs existing_parent for $JOBARG    \n"; }
		    }
			
		  
                ### CALL EXTERNAL WRFSI wrfprep SCRIPT FOR INITIALIZATION FOR THIS DOMAIN
                ### need to force 3hr modelforecasetperiodhr param for window run to avoid failure for 1hr boundary update
                if( $IWINDOW == 0 )
                {
				  print $PRINTFH "Running WRFPREP.PL: cd $WRFBASEDIR/WRFSI/etc ; ./wrfprep.pl -f $FORECAST_PERIODHRS{$regionname}[$IWINDOW] -t $BOUNDARY_UPDATE_PERIODHRS{$regionname}[$IWINDOW] -s $run_yyyymmddhh\n";
                  $wrfprep_errout = `cd $WRFBASEDIR/WRFSI/etc ; ./wrfprep.pl -f $FORECAST_PERIODHRS{$regionname}[$IWINDOW] -t $BOUNDARY_UPDATE_PERIODHRS{$regionname}[$IWINDOW] -s $run_yyyymmddhh >| $ENV{MOAD_DATAROOT}/log/wrfprep.stdout`;  
                }
                else
                {
                  ### fake -f & -t args since actual may not have available grib file and only need for landuse, etc data
                  if( $LWINDOWRESTART != 1 )
                  {
					print $PRINTFH "Running WRFPREP.PL: cd $WRFBASEDIR/WRFSI/etc ; ./wrfprep.pl -f $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -t $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -s $run_yyyymmddhh\n";
                    $wrfprep_errout = `cd $WRFBASEDIR/WRFSI/etc ; ./wrfprep.pl -f $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -t $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -s $run_yyyymmddhh >| $ENV{MOAD_DATAROOT}/log/wrfprep.stdout`;  
                  }
                  else
                  {
                    ### $LWINDOWRESTART =1 FOR RESTART FROM NON-WINDOW IC/BC WITH PRE-EXISTING GRIB FILE USED FOR NEEDED LANDUSE, ETC DATA
                    ###                   (USE HARD-WIRED DAY/TIME FOR AN EXISTING GRIB FILE)
					print $PRINTFH "Running WRFPREP.PL: cd $WRFBASEDIR/WRFSI/etc ; ./wrfprep.pl -f $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -t $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -s 2005040218\n";
                    print $PRINTFH "   $moad grib_prep using landuse,etc data from existing grib file with hard-wired date! \n"; 
                    $wrfprep_errout = `cd $WRFBASEDIR/WRFSI/etc ; ./wrfprep.pl -f $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -t $BOUNDARY_UPDATE_PERIODHRS{$regionname}[0] -s 2005040218 >| $ENV{MOAD_DATAROOT}/log/wrfprep.stdout`;  
                  }
                }
                ### test for wrfprep run errors
                $lrunerr = $?;
                chomp( $successtest3 = `grep -c -i 'ended normally' $ENV{MOAD_DATAROOT}/log/${run_yyyymmddhh}.wrfprep` ) ;
                chomp( $successtest2 = `grep -c -i 'VINTERP COMPLETE' $ENV{MOAD_DATAROOT}/log/${run_yyyymmddhh}.vinterp` ) ;
                ### should be _2_ matches (domain 1 and domain 2) for this hinterp log string
                chomp( $successtest1 = `grep -c -i 'HINTERP: Completed' $ENV{MOAD_DATAROOT}/log/${run_yyyymmddhh}.hinterp` ) ;
                if ( $wrfprep_errout !~ m|^\s*$| )
                {
                  print $PRINTFH "*** $moad ERROR EXIT : WRFPREP.PL => error found in STDERR = $wrfprep_errout \n";
                  ### EXIT THREAD
                  exit 1;
                }
                elsif( ! defined $successtest1 || $successtest1 eq '' || $successtest1 != $MAXDOMAIN{$regionname}[$IWINDOW] ) 
                {
                  print $PRINTFH "*** $moad ERROR EXIT: WRFPREP.PL successtest1=${successtest1} !=$MAXDOMAIN{$regionname}[$IWINDOW] => hinterp log error for IWINDOW,LWINDOWRESTART= ${IWINDOW},${LWINDOWRESTART} \n";
                  print $PRINTFH "check files in BASEDIR/WRF/wrfsi/domains/${moad}/log/ \n";
                  print $PRINTFH "note: if successtest1=?!=$MAXDOMAIN{$regionname}[$IWINDOW], check that NUM_DOMAINS=$MAXDOMAIN{$regionname}[$IWINDOW] and NUM_ACTIVE_SUBNEST in BASEDIR/WRF/wrfsi/domains/${moad}/static/wrfsi.nl and MAX_DOM=$MAXDOMAIN{$regionname}[$IWINDOW] in BASEDIR/WRF/wrfsi/domains/${moad}/static/wrf.nl \n";
                  ### EXIT THREAD
                  exit 1;
                }
                elsif( ! defined $successtest2 || $successtest2 eq '' || $successtest2 != 1 ) 
                {
                  print $PRINTFH "*** $moad ERROR EXIT: WRFPREP.PL successtest2=${successtest2} !=1 => vinterp log error for IWINDOW,LWINDOWRESTART= ${IWINDOW},${LWINDOWRESTART} \n";
                  ### EXIT THREAD
                  exit 1;
                }
                elsif( ! defined $successtest3 || $successtest3 eq '' || $successtest3 != 1 ) 
                {
                  print $PRINTFH "*** $moad ERROR EXIT: WRFPREP.PL successtest3=${successtest3} !=1 => wrfprep log error for IWINDOW,LWINDOWRESTART= ${IWINDOW},${LWINDOWRESTART} \n";
                  ### EXIT THREAD
                  exit 1;
                }
                elsif( $lrunerr != 0 ) 
                {
                  print $PRINTFH "*** $moad ERROR EXIT: WRFPREP.PL non-zero ReturnCode = ${lrunerr} \n";
                  ### EXIT THREAD
                  exit 1;
                }
                else
                {
                  if ($LPRINT>2) { print $PRINTFH "      Exited $moad wrfprep.pl with no detected error \n"; }
                }
                ### INITIALIZATION
                $wrfnamelistfile = "$WRFBASEDIR/WRFV2/RASP/$moad/namelist.input" ;
                ### START OF GENERATION OF INITIALIZATION FILES FOR ALL DOMAINS       
                ### must run real.exe for domain 2,3 cases by creating files and namelist as if domain 1
                for ( $kdomain=$MAXDOMAIN{$regionname}[$IWINDOW]; $kdomain>=1; $kdomain-- )
                {
### ONLY CALL REAL.EXE INIT.COND. TO COME FROM FILE
### but must allow for window domain2 case when using fake start time for domain2
if( $IWINDOW == 1 || $starthh4dom[$kdomain] == $starthh4dom[1] )
{
                  ### SETUP INITIAL CONDITIONS FOR REAL-DATA RUN
                  ### FOR *NON-DOMAIN1* MUST TREAT AS *DOMAIN1* FOR INITIAL/BC KLUDGE
                  `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/wrf_real_input* 2>/dev/null`;
                  ### create needed links to ../siprd/wrf_real_input_em files  
                  @filelist = split /\s+/,`cd $ENV{MOAD_DATAROOT}/siprd/ ; ls -1 wrf_real_input* 2>/dev/null`;
                  foreach $filename (@filelist)
                  {
                    jchomp($filename);
                    if( $filename =~ m/wrf_real_input_em.d0${kdomain}/ )
                    {
                     ( $filenamelink = $filename ) =~ s/d0${kdomain}/d01/ ;
                     `ln -fs $ENV{MOAD_DATAROOT}/siprd/$filename $WRFBASEDIR/WRFV2/RASP/$moad/$filenamelink`;
                      if ($LPRINT>3) {print $PRINTFH "         creating real.exe input link $WRFBASEDIR/WRFV2/RASP/$moad/$filenamelink -> $ENV{MOAD_DATAROOT}/siprd/$filename \n";}
                    }
                  }
  $intervalseconds =  $BOUNDARY_UPDATE_PERIODHRS{$regionname}[$IWINDOW] * 3600 ;
                  ### create model input - namelist.input with correct data BASED ON namelist.template
                  if( $kdomain == 1 && $IWINDOW == 0 )
                  {
                    &template_to_namelist( $moad, $intervalseconds, 1 );
                  }
                  else
                  {
                    ### create fake namelist from template, which will process as domain 1 - added args & changes to routine itself
                    ### require start=end same as domain1 - should be true for normal and not matter for windowed run and allows arbitrary start for latter
                    ### temporarily use non-window start time (ndown later uses actual time) to ensure a wrfprep data file is available
                    ### FOR WINDOWED RUN, TEMPORARILY SET START DAY/TIME TO NON-WINDOW VALUES FOR real RUN (whatta mess!)
                    if( $IWINDOW == 1 )
                    {
                      if( $LWINDOWRESTART != 1 )
                      {
                        ### remember here [0] is for non-window run
                        $startyyyy4dom[$kdomain] = $fakedomain1_startyyyy[0] ;
                        $startmm4dom[$kdomain]   = $fakedomain1_startmm[0] ;
                        $startdd4dom[$kdomain]   = $fakedomain1_startdd[0] ;
                        $starthh4dom[$kdomain]   = $fakedomain1_starthh[0] ;
                      }
                      else
                      {
                        ### $LWINDOWRESTART =1 FOR RESTART FROM NON-WINDOW IC/BC WITH EXISTING GRIB FILE USED FOR NEEDED LANDUSE, ETC DATA
                        ###                   (USE HARD-WIRED DAY/TIME FOR AN EXISTING GRIB FILE)
                        $startyyyy4dom[$kdomain] = '2005' ; 
                        $startmm4dom[$kdomain]   = '04' ;
                        $startdd4dom[$kdomain]   = '02' ;
                        $starthh4dom[$kdomain]   = '18' ;
                        print $PRINTFH "   $moad grib_prep uses landuse,etc data from existing grib file with hard-wired date! \n"; 
                      }
                    }
                    &template_to_fake1namelist( $moad, $intervalseconds );  
                    ### FOR WINDOWED RUN, SET START DAY/TIME BACK TO CORRECT WINDOW VALUES FOR ndown RUN (whatta mess!)
                    if( $IWINDOW == 1 )
                    {
                      $startyyyy4dom[$kdomain] = $truewindow_startyyyy4dom[$kdomain] ;
                      $startmm4dom[$kdomain]   = $truewindow_startmm4dom[$kdomain] ;
                      $startdd4dom[$kdomain]   = $truewindow_startdd4dom[$kdomain] ;
                      $starthh4dom[$kdomain]   = $truewindow_starthh4dom[$kdomain] ;
                    }
                  }
                  ### CREATE INITIAL/BC FOR REAL-DATA RUN 
                  ### copy any existing log file from previous run
                  `cd $WRFBASEDIR/WRFV2/RASP/$moad ; cp namelist.input real.namelist.$kdomain 2>&1`;
                  ### delete any existing output file from previous run
                  `cd $WRFBASEDIR/WRFV2/RASP/$moad ; rm -f wrfbdy_d0${kdomain} ; rm -f wrfinput_d0${kdomain}`;
                  ### WINDOWRESTART - requires altered day/time in namelist.input 
                  ### add ${JOBARG}:${regionkey} as argument so ps can differentiate jobs, but not used by executable
                  ### must send real.exe stderr somewhere as otherwise 'drjack.info -- rsl_nproc_all 1, rsl_myproc 0' is written to this program's stderr !?
                  $realexe_errout = `cd $WRFBASEDIR/WRFV2/RASP/$moad ; ./real.exe "${JOBARG}:${regionkey}" >| real.out.${kdomain} 2>&1`;
                  ### test for run errors
                  $lrunerr = $?;
                  chomp( $successtest = `grep -c -i 'SUCCESS COMPLETE' $WRFBASEDIR/WRFV2/RASP/$moad/real.out.${kdomain}` ) ;
                  if ( $realexe_errout !~ m|^\s*$| )
                  {
                    print $PRINTFH "*** $moad ERROR EXIT : REAL.EXE => error found in STDERR = $realexe_errout \n";
                    ### EXIT THREAD
                    exit 1;
                  }
                  elsif( ! defined $successtest || $successtest eq '' || $successtest != 1 ) 
                  {
                    print $PRINTFH "*** $moad ERROR EXIT: REAL.EXE successtest= $successtest !=1 => error reported in log file $WRFBASEDIR/WRFV2/RASP/$moad/real.out.${kdomain} \n";
                    ### EXIT THREAD
                    exit 1;
                  }
                  elsif( $lrunerr != 0 )
                  {
                    print $PRINTFH "*** $moad ERROR EXIT: REAL.EXE $kdomain non-zero ReturnCode = ${lrunerr} \n";
                    ### EXIT THREAD
                    exit 1;
                  }
                  else
                  {
                    ### if successful, remove created wrfout links to prevent problems/confusion
                   `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/wrf_real_input* 2>/dev/null`;
                    if ($LPRINT>2) { print $PRINTFH "      Exited $moad real.exe with no detected error for domain $kdomain - existing $moad links deleted \n"; }
                  }
                  ### rename output file to correct domain name (if not domain 1)
                  if( $kdomain != 1 )
                    { `cd $WRFBASEDIR/WRFV2/RASP/$moad ; mv -f wrfinput_d01 wrfinput_d0${kdomain} 2>/dev/null`; }
}
                  if( $IWINDOW == 1 )
                  {
                  ### create "find grid" input file needed by ndown by renaming  real.exe output file
                  $wrf_init_timestring = sprintf  "%4d-%02d-%02d_%02d:00:00", $startyyyy4dom[$kdomain],$startmm4dom[$kdomain],$startdd4dom[$kdomain],$starthh4dom[$kdomain];
                  `mv $WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d0${kdomain} $WRFBASEDIR/WRFV2/RASP/$moad/wrf_real_input_em.d02.$wrf_init_timestring `;
                  ### create "coarse grid" input files needed by ndown by linking to existing "stage-1" output files of correct domain
                  ( $nonwindow_moad = $moad ) =~ s/-WINDOW//i;
                  $nwrfoutputfilecount = 0; 
                  @filelist = split /\s+/,`cd $WRFBASEDIR/WRFV2/RASP/$nonwindow_moad/ ; ls -1 wrfout* 2>/dev/null`;
                  $kdomainp1 = $kdomain +1;
                  foreach $filename (@filelist)
                  {
                    jchomp($filename);
                    if( $filename =~ m/wrfout_d0${kdomain}/ )
                    {
                      ( $filenamelink = $filename ) =~ s/d0${kdomain}/d01/ ;
                      `ln -fs $WRFBASEDIR/WRFV2/RASP/$nonwindow_moad/$filename $WRFBASEDIR/WRFV2/RASP/$moad/$filenamelink`;
                      $nwrfoutputfilecount++; 
                      if ($LPRINT>3) {print $PRINTFH "         creating ndown.exe input link $WRFBASEDIR/WRFV2/RASP/$moad/$filenamelink -> $WRFBASEDIR/WRFV2/RASP/$nonwindow_moad/$filename \n";}
                    }
                    elsif( $filename =~ m/wrfout_d0${kdomainp1}/ )
                    {
                      ( $filenamelink = $filename ) =~ s/d0${kdomainp1}/d02/ ;
                      `ln -fs $WRFBASEDIR/WRFV2/RASP/$nonwindow_moad/$filename $WRFBASEDIR/WRFV2/RASP/$moad/$filenamelink`;
                      $nwrfoutputfilecount++; 
                      if ($LPRINT>3) {print $PRINTFH "         creating ndown.exe input link $WRFBASEDIR/WRFV2/RASP/$moad/$filenamelink -> $WRFBASEDIR/WRFV2/RASP/$nonwindow_moad/$filename \n";}
                    }
                  }
                  $intervalseconds = $NDOWN_BOUNDARY_UPDATE_PERIODHRS{$regionname}[$IWINDOW] * 3600 ;
                  if ($nwrfoutputfilecount > 0)
                  {
                    ### create model input - namelist.input with correct data BASED ON namelist.template
                    if( $kdomain == 1 )
                    {
                      &template_to_namelist( $nonwindow_moad, $intervalseconds, 0 );
                    }
                    else
                    {
                      ### create fake namelist from template, which will process as domain 1 
                      &template_to_ndownnamelist( $nonwindow_moad, $intervalseconds );  
                    }
                    ### run ndown.exe
                    ### copy any existing log file from previous run
                    `cd $WRFBASEDIR/WRFV2/RASP/$moad ; cp namelist.input ndown.namelist.$kdomain 2>&1`;
                    ### delete any existing output file from previous run
                    `cd $WRFBASEDIR/WRFV2/RASP/$moad ; rm -f wrfbdy_d0${kdomain} ; rm -f wrfinput_d0${kdomain}`;
                    ### WINDOWRESTART uses regular namelist.input used - ndown.out => # **WARNING** Time in input file not equal to time on domain
                    ### add ${JOBARG}:${regionkey} as argument so ps can differentiate jobs, but not used by executable
                    ### NDOWN start hour change - as of v2.1.2 can start window run only at grib file times
                    ###   I believe that "fine grid" input file used to ingest higher resolution terrestrial fields and corresponding land-water masked soil fields from file produced by SI, with other data being overwritten by "nesting down" the "coarse grid" input data
                    ###   SI initialization must use time at which grib file is available (creates WRFSI/.../siprd file read by real.exe)
                    ###   so to start at time for which grib file _not_ available, I've used dummy time for real.exe, then rename its output file with desired time
                    ###      this would generate warning messages in both ndown and wrf ala
                    ###         **WARNING** Time in input file not equal to time on domain" 
                    ###      yet seemed to work
                    ###   but with v2.1.2 wrf.exe get additional warning and fatal messages
                    ###         **WARNING** Trying next time in file wrfinput_d01 ...
                    ###         1  input_wrf: wrf_get_next_time current_date: 2005-04-02_18:00:00 Status =            -$
                    ###         FATAL CALLED FROM FILE:  input_wrf.b  LINE:     374
                    ###         ... Could not find matching time in input file wrfinput_d01
                    ###   so now must start stage-2 "window" run only at hour for which grib file available
                    ###   WOULD LIKE TO LATER OVER-RIDE THIS TEST AND ALLOW START AT ARBITRARY HOUR
                    ###   caveat: if ingested fields vary with time then over-riding not exactly valid (but how much can the fields change in 1-2 hours?)
                    ### must send ndown.exe stderr somewhere as otherwise 'drjack.info -- rsl_nproc_all 1, rsl_myproc 0' is written to this program's stderr !?
                    $ndownexe_errout = `cd $WRFBASEDIR/WRFV2/RASP/$moad ; ./ndown.exe "${JOBARG}:${regionkey}" >| ndown.out.${kdomain} 2>&1`;
                    ### test for run errors
                    $lrunerr = $?;
                    chomp( $successtest = `grep -c -i 'SUCCESS COMPLETE' $WRFBASEDIR/WRFV2/RASP/$moad/ndown.out.${kdomain}` ) ;
                    if ( $ndownexe_errout !~ m|^\s*$| )
                    {
                      print $PRINTFH "*** $moad ERROR EXIT : NDOWN.EXE => error found in STDERR = $ndownexe_errout \n";
                      ### EXIT THREAD
                      exit 1;
                    }
                    elsif( ! defined $successtest || $successtest eq '' || $successtest != 1 ) 
                    {
                      print $PRINTFH "*** $moad ERROR EXIT: NDOWN.EXE $kdomain successtest= ${successtest} !=1 => error reported in file  $WRFBASEDIR/WRFV2/RASP/$moad/ndown.out.${kdomain} - STDERR= $ndownexe_errout ";
                      ### if error here, remove created wrfout links to avoid plotting them
                      `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfout_* 2>/dev/null`;
                      ### EXIT THREAD
                      exit 1;
                    }
                    elsif ( $lrunerr != 0 )
                    {
                      print $PRINTFH "*** $moad ERROR EXIT: NDOWN.EXE $kdomain non-zero ReturnCode = ${lrunerr} - STDERR= $ndownexe_errout ";
                      ### if error here, remove created wrfout links to avoid plotting them
                      `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfout_* 2>/dev/null`;
                      ### EXIT THREAD
                      exit 1;
                    }
                    else
                    {
                      ### remove created wrfout links to prevent problems/confusion
                      `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfout_* 2>/dev/null`;
                      if ($LPRINT>2) { print $PRINTFH "      Exited $moad ndown.exe with no detected error for domain $kdomain - input wrfout links removed \n"; }
                    }
                  }
                  else
                  {
                      print $PRINTFH "*** ERROR EXIT: NDOWN RUN - EXPECTED WRFOUT FILES NEEDED BY NDOWN MISSING \n";
                      print $PRINTFH "    (perhaps were pre-pended with 'previous.' by last job run ?) \n";
                      ### EXIT THREAD
                      exit 1;  
                  }
                  if( $kdomain == 1 )
                  {
                    ### for domain 1, rename output initial/bc files
                    `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d02 $WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d0${kdomain} 2>/dev/null`;
                    `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfbdy_d02 $WRFBASEDIR/WRFV2/RASP/$moad/wrfbdy_d0${kdomain} 2>/dev/null`;
                  }  
                  else
                  {
                    ### for non-domain 1, save output initial files with temporary nemes for later recovery
                    `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d02 $WRFBASEDIR/WRFV2/RASP/$moad/tmp.wrfinput_d0${kdomain} 2>/dev/null`;
                  }
                  }
                ### END OF GENERATION OF INITIALIZATION FILES FOR ALL DOMAINS       
                }
                if( $IWINDOW == 1 )
                {
                for ( $kdomain=$MAXDOMAIN{$regionname}[$IWINDOW]; $kdomain>=2; $kdomain-- )
                {
                  `mv -f $WRFBASEDIR/WRFV2/RASP/$moad/tmp.wrfinput_d0${kdomain} $WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d0${kdomain} 2>/dev/null`;
                }
                ### remove wrfout links to non-window directory (no output not sent there!)
                ### THIS MEANS CANNOT SAVE OLD wrfout FILES IN WINDOWED RUN
                `rm -f $WRFBASEDIR/WRFV2/RASP/$moad/wrfout*`;
                }
                ### SAVE DESIRED WRF NON-WINDOW INIT FILES (namelist.input,wrfbdy_d01,wrfinput_d0*) even though run not known successful, since difficult to do later
                if( $LSAVE > 0 && $IWINDOW == 0 )
                {
                  `rm -f  $savesubdir{$regionname}/namelist.input.gz ; gzip $WRFBASEDIR/WRFV2/RASP/$moad/namelist.input -c >| $savesubdir{$regionname}/namelist.input.gz`;
                }
                if( $LSAVE > 2 && $IWINDOW == 0 )
                {
                  `rm -f  $savesubdir{$regionname}/wrfbdy_d01.gz ; gzip $WRFBASEDIR/WRFV2/RASP/$moad/wrfbdy_d01 -c >| $savesubdir{$regionname}/wrfbdy_d01.gz`;
                   for ( $idomain=1; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW]; $idomain++ )
                   {   
                     ### domain init file  non-existent when domain initialized internally via interpolation
                     if( -f "$WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d0${idomain}" )
                     {
                       `rm -f $savesubdir{$regionname}/wrfinput_d0${idomain}.gz ; gzip $WRFBASEDIR/WRFV2/RASP/$moad/wrfinput_d0${idomain} -c >| $savesubdir{$regionname}/wrfinput_d0${idomain}.gz`;
                     }
                   }
                  ### make read-only to prevent accidental over-write
                  `chmod -f 444 $savesubdir{$regionname}/*`;
                  if ($LPRINT>1) { $time = `date +%H:%M:%S` ; print $PRINTFH "      $moad wrf init files SAVED to $savesubdir{$regionname} at $time"; } 
                }       
              }
              else
              {
                if ($LPRINT>1)
                {
                  print $PRINTFH "   ** LMODELINIT=0, so *SKIP* $moad wrfprep.pl & real.exe \n";
                  print $PRINTFH "   WILL USE EXISTING $moad namelist.input & wrfbdy_d01 & wrfinput_d* IN RUN DIRECTORY \n";
                }
              }
              ### DO MODEL RUN LMODELRUN 
              if ($LMODELRUN>1)
              {
                if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time) ; print $PRINTFH "   $moad MODEL RUN BEGINS at $time \n"; }
                ### RUN MODEL - send stdout containing iteration prints to file
                ### create namelist used for actual run
                ### uses latest $intervalsecons which is for wrfout interval time
                &template_to_namelist( $moad, $intervalseconds, 0 );
                ### cannot make a single command (to create only one ps) since then namelist cant be read
                `cd $WRFBASEDIR/WRFV2/RASP/$moad/ ; cp namelist.input wrf.namelist`;
                ### add ${JOBARG}:${regionkey} as argument so ps can differentiate jobs, but not used by executable
                ### must send wrf.exe stderr somewhere as otherwise 'drjack.info -- rsl_nproc_all 1, rsl_myproc 0' is written to this program's stderr !?
				
				my $wrf_start_time = time();
				
                $wrfexe_errout = `NCPUS=$NCPUS ; export NCPUS ; cd $WRFBASEDIR/WRFV2/RASP/$moad/ ; ./wrf.exe "${JOBARG}:${regionkey}" >| wrf.out 2>&1`;
				
				my $wrf_duration = time() - $wrf_start_time;
				my $wrf_hh = int($wrf_duration / 3600);
				$wrf_duration = $wrf_duration % 3600;
				my $wrf_mm = int($wrf_duration / 60);
				my $wrf_ss = $wrf_duration % 60;
				
				print $PRINTFH "WRF Runtime: ${wrf_hh}:${wrf_mm}:${wrf_ss} \n";
				
                ### test for run errors
                ### note: "exceeded cfl" error can produce a NaN which kills execution so badly that these tests not reached, with script ending with "just-finished child runmodel" processing
                $lrunerr = $?;
                $lastoserr = $!;
                ### must test for errors in log file since fatals still return code of 0
                chomp( $successtest = `grep -c -i 'SUCCESS COMPLETE' $WRFBASEDIR/WRFV2/RASP/$moad/wrf.out` ) ;
                if( $lrunerr != 0 || ! defined $successtest || $successtest eq '' ||  $successtest != 1 || $wrfprep_errout !~ m|^\s*$| ) 
                {
                  if ( $wrfexe_errout !~ m|^\s*$| )
                  {
                    print $PRINTFH "*** $moad ERROR EXIT : WRF.EXE => error found in STDERR = $wrfexe_errout \n";
                    ### EXIT THREAD
                    exit 1;
                  }
                  elsif ( ! defined $successtest || $successtest eq '' || $successtest != 1 )
                  {
                    &write_err( "*** $moad ERROR: WRF.EXE EXIT ERROR: successtest= ${successtest} !=1 => error reported in logfile $WRFBASEDIR/WRFV2/RASP/$moad/wrf.out");
                  }
                  elsif( $lrunerr != 0 )
                  { 
                    &write_err( "*** $moad ERROR: WRF.EXE EXIT ERROR: non-zero ReturnCode = ${lrunerr} - lastOSerr=${lastoserr} \n");
                  }
                  ### if batch mode, send email error notice to admininstrator
                  if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'WRF_EXECUTION'})
                  {
                    $mailout='';
                    $subject = "$program wrf.exe ERROR rc=${lrunerr} successtest=${successtest} for $moad - $rundayprt #${groupnumber}";
                    jchomp( $mailout = `echo "STDERR= $wrfexe_errout" | mail -s "${subject}" "$ADMIN_EMAIL_ADDRESS" 2>&1` );
                    if ($LPRINT>1) { print $PRINTFH "*** ERROR NOTICE EMAILED - wrf.exe error \n"; }
                  }
                  $gridcalcendtime = `date +%H:%M` ; jchomp($gridcalcendtime);
                  ### WRITE THREAD TIME SUMMARY FILE
                  printf { $SUMMARYFH{$regionkey} } "%d: %s - %s = RUN ERROR ", $groupnumber,$gridcalcstarttime,$gridcalcendtime;
                  print $PRINTFH "***>>> $regionkey THREADED CHILD RUNMODEL wrf.exe ERROR EXIT for $regionkey at $gridcalcendtime under $RUNPID \n";
                  ### EXIT THREAD
                  exit 1;
                }
                else
                {
                  if ($LPRINT>2) { print $PRINTFH "     Exited $moad wrf.exe with no detected error\n"; }
if( $moad eq 'GREATBRITAIN' || $moad eq 'GB-NOAH' || $moad eq 'GB-RUC' )
{
  $wrfoutfile = "$WRFBASEDIR/WRFV2/RASP/$moad/wrf.out" ;
  if( `grep -c '^SFCFLXOUT' $wrfoutfile` > 0 )
  {
    $wrfoutstorename = "${yymmdd{'curr.'}}.sfcflxout" ;
    `grep '^SFCFLXOUT' $wrfoutfile >| ${savesubdir{$regionname}}/${wrfoutstorename} ; gzip ${savesubdir{$regionname}}/${wrfoutstorename}`;
  }
  print $PRINTFH "** SFCFLXOUT output stored to ${savesubdir{$regionname}}/${wrfoutstorename}\n"; 
}
                  ### DO PLOTTING/FTPING IF NON-THREADED
                  ### ($LTHREADEDREGIONRUN=0 intended for testing so domain to be plotted hard-wired into &output_model_results_hhmm)
                  ### intended for testing so domain to be plotted hard-wired into &output_model_results_hhmm
                  if(  $LTHREADEDREGIONRUN == 0 )
                    { &output_model_results_hhmm ( @{$PLOT_HHMMLIST{$regionname}[$IWINDOW]} ) ; }
                }
                if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time); print $PRINTFH "   END $regionname MODEL RUN LOOP $IWINDOW FOR $moad at $time\n";}
              }
              else
              {
                if ($LPRINT>1) { print $PRINTFH "   ** LMODELRUN=0, so *SKIP* $regionname MODEL RUN LOOP $IWINDOW FOR $moad WITH ${starthh4dom[1]}Z INITIALIZATION *** \n"; }
              }
              ####### SAVE ??? ####### might want to save 21z output file/plots
              ### NOTE THAT GRIB FILES OVER-WRITTEN EACH DAY SO NEED TO BE SAVED IF WANT TO KEEP
              ### NOTE THAT WRF OUTPUT FILES REMOVED ABOVE SO NEED TO BE SAVED IF WANT TO KEEP
              ### NOTE THAT IMAGE FILES OVER-WRITTEN EACH DAY SO NEED TO BE SAVED IF WANT TO KEEP
            }
            $gridcalcendtime = `date +%H:%M` ; jchomp($gridcalcendtime);
            ### WRITE THREAD TIME SUMMARY FILE
            $gridcalcrunhrs = &hhmm2hour($gridcalcendtime) - &hhmm2hour($gridcalcstarttime) ;
            if( $gridcalcrunhrs < 0 ) { $gridcalcrunhrs += 24. ; }
            printf { $SUMMARYFH{$regionkey} } "%d: %s - %s = %4.2f hr  ", $groupnumber,$gridcalcstarttime,$gridcalcendtime,$gridcalcrunhrs ;
            ### cancel timeout for entire model init/run section (thread)
            alarm ( 0 );
            ### FOR THREADED REGIONRUN, THIS IS CHILD PROCESS SO EXIT
            if( $LTHREADEDREGIONRUN == 1 )
            {
              print $PRINTFH "   >>> $regionkey THREADED CHILD RUNMODEL ENDED for $regionkey at $gridcalcendtime under $RUNPID \n";
              ### EXIT THREAD
              exit 0;
            }
            else
            {
              print $PRINTFH "   >>> $regionkey NON-THREADED RUNMODEL ENDED at $gridcalcendtime \n";
            }
        ### END OF THREADEDREGIONRUN IF FOR CHILD CREATION
        }
        ### FOR THREADED REGIONRUN, THIS IS PARENT PROCESS 
        if( $LTHREADEDREGIONRUN == 1 )
        {
          ### CREATE ARRAY TO TRACK STARTED CHILDREN (not used if not threaded)
          push @childrunmodellist, $kpid ;
          print $PRINTFH "   >>> $regionkey CHILD RUNMODEL $kpid SPUN OFF by $RUNPID for $program $JOBARG \n";
        }
        ### END OF SECTION PROCESSED IF ALL NEEDED GRIB FILES OBTAINED FOR A FORECAST RUN
      ########## END OF LOOP OVER GRIDS !!! ##########
      }
      ### FOR THREADED REGIONRUN, CHECK WHETHER ALL CHILD PROCESSES FOR EACH REGION HAVE ENDED
      ### ALSO  LOOK FOR COMPLETED OUTPUT FILES AND PROCESS THEM
      if ( $LTHREADEDREGIONRUN == 1 && $nstartedchildren > 0 )
      {
        ### initialization for child test
        $nrunningchildren = $nstartedchildren ;
        $nfinished = 0;
        $ifinishedloop = 0;
        for ( $ichild=0; $ichild<=$#childrunmodellist; $ichild++ ) 
        {
          $child_exitvalue_list[$ichild] = -999;
          $child_signum_list[$ichild] = -999;
        }
        $time = `date +%H:%M:%S` ; jchomp($time);
        printf $PRINTFH "   >>> LOOK FOR RUNNING RUNMODEL CHILDREN with #children = %d & %d and sleepsec= %d sec at %s \n",$nstartedchildren,(1+$#childrunmodellist),$finishloopsleepsec,$time;
        ### require a child to be still running to stay in loop
        ### (since a child might end for mysterious reasons and not be caught by normal processing)
        ### two ways to exit loop - normally second one used
        while ( $nrunningchildren > 0 && $nfinished < $nstartedchildren )
        {
          $time = `date +%H:%M:%S` ; jchomp($time);
          $ifinishedloop++;
          ### TEST CHILD STATUS 
          ### if child NOT ended, $childtest=0 $childstatus=-1
          ### if child IS  ended, $childtest=$kpid $childstatus=see_below('exit 0'=>0,'exit 1'=>256)=>$child_signal_num=0,$child_exit_value=rc 
          ### SLEEP AT EACH ITER
          sleep $finishloopsleepsec;
          ### LOOP OVER STARTED CHILD PROCESSES
          $nrunningchildren = 0;
          for ( $ichild=0; $ichild<=$#childrunmodellist; $ichild++ ) 
          {
            $childrunmodel = $childrunmodellist[$ichild];
            ### LOOK FOR JUST-FINISHED CHILDREN FROM THOSE CHILD PIDS STILL ACTIVE 
            if( $childrunmodel > 0 )
            {
              $nrunningchildren++;
              ### *** $childtest = 0 while child still running, pid# on first waitpid call after finish, then -1 ***
              $childtest = waitpid ( $childrunmodel, &WNOHANG ) ; 
              ### if just finished, set pid array value to -1 to indicate job finished and add to finished count
              if( $childtest > 0 ) 
              {
                $childrunmodellist[$ichild] = -1;
                $nfinished++;
                ### determine child exist status
                $child_exit_value  = $? >> 8 ;
                $child_signal_num  = $? & 127 ;
                $child_exitvalue_list[$ichild] = $child_exit_value ;
                $child_signum_list[$ichild] = $child_signal_num ;
                ### PRINT FINISHED JOB INFO
                $time = `date +%H:%M:%S` ; jchomp($time);
                print $PRINTFH "   > $ichild JUST-FINISHED CHILD RUNMODEL PID= $childrunmodel = $childtest  RCs= $child_exit_value & $child_signal_num at $time \n";
              }
            }
          }
          ### LOOK FOR AND PROCESS NEWLY CREATED OUTPUT FILES
          foreach $regionkey (@REGION_DOLIST)
          {
            $regionname = $regionkey;
            ### SET NAME OF CURRENT CASE HERE
           ( $regionname_lc = $regionname ) =~ tr/A-Z/a-z/; 
            $moad = ${regionname};
            ### generate list of available wrfout files (add -window files for window runs)
            @outputfilelist = ();
            for( $IWINDOW=$iwindowstart{$regionkey}; $IWINDOW<= $iwindowend{$regionkey}; $IWINDOW++ )
            {
              ### include stage2-only case
              if ( $LRUN_WINDOW{$regionkey} > 0 && $IWINDOW == 1 )
              {
                $moad = $regionname . "-WINDOW" ;
              }
              ### look for newly created output files (exclude links)
              ### must have removed output files from previous jobs for this to work!
              ### PLOT DOMAIN FOR WHICH PLOT SIZE IS NOT BLANK
              ### set non-window/window array index
              @findfilelist = ();
              for ( $idomain=1; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW]; $idomain++ )
              {
                if( defined $PLOT_IMAGE_SIZE{$regionname}[$IWINDOW][$idomain-1] && $PLOT_IMAGE_SIZE{$regionname}[$IWINDOW][$idomain-1] !~ '^ *$' )
                  { push @findfilelist, `find "$WRFBASEDIR/WRFV2/RASP/$moad" -name "wrfout_d0${idomain}*" \! -type l -maxdepth 1 -follow -print 2>/dev/null` ; }
              }
              ### ONLY ADD FILES SELECTED TO BE PLOTTTED
              for ( $iifile=0; $iifile<=$#findfilelist; $iifile++ )
              {
                jchomp( $findfilelist[$iifile] );
                ( $historyhhmm = $findfilelist[$iifile] ) =~ s|.*/wrfout_d.*_([0-9][0-9]:[0-9][0-9]):.*|$1|;
                $historyhhmm =~ s|:||;
                if( grep ( m/$historyhhmm/, @{$PLOT_HHMMLIST{$regionname}[$IWINDOW]} ) > 0 )
                { 
                  ### do not need to test whether link due to use of ! -type l in find command
                  push @outputfilelist, $findfilelist[$iifile] ; 
                }
              }
              ### DAY/HR SELECTION - moved call inside iwindow loop - - this depends upon start/end time of run
              foreach $wrffilename (@outputfilelist)
              {
                jchomp($wrffilename);
                ### multiple days have "+" in directory name so must allow for it
                ( $wrffilenametest = $wrffilename ) =~ s|\+|\\+|g ;
                if( grep ( m/^${wrffilenametest}$/, @{$finishedoutputhour{$regionkey}} ) == 0 )
                  { 
                    push @{$finishedoutputhour{$regionkey}}, $wrffilename ;
                    ### do output for this file
                    &output_wrffile_results ( $wrffilename );
                  }
              }
            }
          }     
        }
        $time = `date +%H:%M:%S` ; jchomp($time);
        printf $PRINTFH "   > END CHILD RUNMODEL PROCESSING WITH %d/%d CHILDREN ENDED - AFTER %d ITERS OF %d sec at $time \n", $nfinished,(1+$#childrunmodellist),$ifinishedloop,$finishloopsleepsec ;
      }
      SUCCESS_CYCLE_END:
      ### THE ABOVE LABEL USED PRIMARILY FOR TEST RUNS, TO AVOID CALC IN PERL DEBUG MODE BY JUMPING HERE
      ### DO SUCCESSFUL PROCESSING SUMMARY
      $time = `date +%H:%M:%S` ; jchomp($time);
      $successfultimescount = $successfultimescount + 1;
      $timehhmm = `date +%H:%M` ; jchomp($timehhmm);
      $filestatus{$ifile} = $status_processed; 
      ### following saves info needed for skipping of older valid time cases - now done only for _successful_ times!
      $latestfcsttime[$fileextendedvalidtime] = $filefcsttime; 
      ### DO SUCCESSFUL CYCLE PRINT
      if ($LPRINT>1) {printf $PRINTFH ("   GRIB_FILE_PROCESSING_COMPLETE : %s \n", $time );}
    STRANGE_CYCLE_END:
    ### SENT HERE AFTER *UNEXPECTED* FILE PROCESSING OCCURS, FOR CYCLE-ENDING TESTS (INSTEAD OF DIRECTLY STARTING NEW CYCLE)
    ### IMMEDIATELY PRIOR TO HERE SHOULD CONSIDER (1) $filestatus{$ifile} for next attempt  (2) sleep  SINCE WILL IMMEDIATELY RE-CYCLE
      ### remember this filename during next cycle
      $lastfilename = $filename;
      ### to only create 1 blipmap: if($foundfilecount==1) &final_processing;
      ### TEST IF SWITCHING TIME SHUTDOWN NEEDED - similar test also done just after gribget
      if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' )
      {
        $switchingtestjda2z = `date -u +%d` ; jchomp($switchingtestjda2z);
        $switchingtesthhmmz = `date -u +%H:%M` ; jchomp($switchingtesthhmmz);
        $switchingtesttimez = &hhmm2hour( $switchingtesthhmmz );
        ##_for_next_day_switchingtime:
        $switchingtimetestz = $switchingtimehrz{$GRIBFILE_MODEL} - ($minftpmin{$GRIBFILE_MODEL}+$mincalcmin{$GRIBFILE_MODEL})/60. ;
        if ( $switchingtesttimez > $switchingtimetestz && $switchingtestjda2z != $jda2 )
        ##_for_same_day_switchingtime: if ( $switchingtesttime > $switchingtimetest || $switchingtestjda2 == $jda2 )
        { 
           print $PRINTFH ("LOOP-END CYCLE EXIT: SWITCHING TIME Z $switchingtesttimez '>' $switchingtimetestz AND DAY $switchingtestjda2z '!=' $jda2 \n");
          last CYCLE;
        }
      }
      ### EXIT IF ALL FILES PROCESSED
      $oktotal = $successfultimescount + $oldtimescount + $nextskipcount ;
      if( $oktotal >= $dofilecount )
      {
        ###  file processing done
        print $PRINTFH ("LOOP-END CYCLE EXIT: OKtimescount = DOfilecount = $dofilecount \n");    
        last CYCLE;
      }
      ### FOR RUN THAT DID NOT REQUEST ANY GRIB DOWNLOAD, EXIT AFTER ONE FILESET (= $GRIBFILES_PER_FORECAST_PERIOD files) PROCESSED
      ### since no new files are to be downloaded, 
      if( $LGETGRIB==0 && $nstartedchildren > 0 )
      {
        print $PRINTFH ("LOOP-END CYCLE EXIT: $successfultimescount files processed when LGETGRIB=0 \n");    
        last CYCLE;
      }
      ### EXIT IF GRIB FILE INPUT CASE
      if( $LGETGRIB == -1 )
      {
        print $PRINTFH ("LOOP-END CYCLE EXIT: LGETGRIB=-1 SPECIFIED GRIB FILE CASE \n");    
        last CYCLE;
      }    
    }
### END CYCLE LOOP OVER TIME
  }  
  if ($LMODELRUN>0)
  {
    foreach $regionkey (@REGION_DOLIST)
    {
      #####  JOB END IMAGE TEST - check for last image expected, if missing send email
      ### if batch mode, send email error notice to admininstrator
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'JOBEND_IMAGE'} )
      {
        ### undecided as to what criteria to use to identify "run failure"
        ###    decided to test for expected final output plot images as test of entire process
        ###    but wish it could be less complex
        ### use final parameter for test image
        $testparam = ${$PARAMETER_DOLIST{$regionkey}}[$#{$PARAMETER_DOLIST{$regionkey}}] ;
        ### use final run (stage-1 or stage-2) for test image
        if ( $LRUN_WINDOW{$regionkey} == 0 ) 
        { 
          $teststage = 0 ;
          $testdir = "${OUTDIR}/${regionkey}" ;
        }
        else
        { 
          $teststage = 1 ;
          $testdir = "${OUTDIR}/${regionkey}-WINDOW" ;
        }
        ### use final output time for test image
        $testgmt = ${$PLOT_HHMMLIST{$regionkey}[$teststage]}[$#{$PLOT_HHMMLIST{$regionkey}[$teststage]}] ;
        $testlst = $testgmt + $LOCALTIME_ADJ{$regionkey} * 100 ;
        if( $testlst < 0 ) 
        { $testlst += 2400 ;}
        elsif( $testlst >= 2400 ) 
        { $testlst -= 2400 ;}
        $testlst = sprintf "%04d", $testlst ;
        ### mimic $localsoarday calc since $localsoarday may not be available here if error exit
        if( $JOBARG =~ m|\+1| )     { $testday = 'curr+1.'; }
        elsif( $JOBARG =~ m|\+2| )  { $testday = 'curr+2.'; }
        elsif( $JOBARG =~ m|\+3| )  { $testday = 'curr+3.'; }
        else                        { $testday = 'curr.'; }
        ### use output directory so not influenced by LSEND,LSAVE flags
        $testfile = "${testdir}/${testparam}.${testday}${testlst}lst.d2.png" ;
        if ($LPRINT>1) { print $PRINTFH "JOB END - CHECK LAST $regionkey IMAGE = $testfile \n"; }
        if ( -f $testfile )
        {
          ### existing file should be less than 18 hours old!
          chomp( $fileepochsec = `stat --format "%X" $testfile` ) ; 
          chomp( $currentepochsec = `date +%s` ); 
          $agehr = ( $currentepochsec - $fileepochsec ) / 3600. ;    
          if ( $agehr > 18. )
          {
            `echo -e " EXPECTED FINAL IMAGE NOT FOUND \n Latest final image file: \n   $testfile \n   agehr= $agehr > 18" | mail -s "$program RASP ERROR - JOB END IMAGE CHECK for $regionkey - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
            if ($LPRINT>1) { print $PRINTFH "*** ERROR NOTICE EMAILED - JOB END IMAGE CHECK - OLD final image file: $testfile - agehr= $agehr > 18 \n"; }
          }
        }
        else
        {
          `echo -e " EXPECTED FINAL IMAGE NOT FOUND \n NON-EXISTENT final image file: \n   $testfile" | mail -s "$program RASP ERROR - JOB END IMAGE CHECK for $regionkey - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
          if ($LPRINT>1) { print $PRINTFH "*** ERROR NOTICE EMAILED - JOB END IMAGE CHECK - NON-EXISTENT final image file: $testfile \n"; }
        }
      }
    }  
    ### CALL FINAL PROCESSING ROUTINE
    if ($LPRINT>1) {print $PRINTFH "Doing BLIP - call final blip processing\n";}
    &final_processing;
  }
  else
    { print $PRINTFH "LMODELRUN=0 => Skip final processing\n"; }
  exit;
###########  END OF MAIN PROGRAM  ############
#########################################################################
##################   START OF SUBROUTINE DEFINITIONS   ##################
#########################################################################
sub template_to_namelist
{  
  my $inputmoad = $_[0];
  my $intervalseconds = $_[1];
  my $numdoms = $_[2];
  if ($LPRINT>3) {print $PRINTFH "         using template_to_namelist with @_\n";}
  ### CREATE RUN NAMELIST FROM TEMPLATE
  ### keep a copy of the previous namelists input
  ###  RUN_HOURS should be 0 so ignored, else it (not END_HOUR ) controls model end !
  ###  get error 'Exiting subroutine via last at ./rasp.pl' at next line if don't use quotes !?
  if ( -f "${wrfnamelistfile}.last" ) { `mv -f "${wrfnamelistfile}.last" "${wrfnamelistfile}.lastlast" 2>/dev/null`; }
  open(OLDNAMELISTINPUT,"<$WRFBASEDIR/WRFV2/RASP/$inputmoad/namelist.template") or die "Missing namelist.input file for $regionkey - run aborted" ;
  open(NEWNAMELISTINPUT,">${wrfnamelistfile}") ;
  @namelistlines = <OLDNAMELISTINPUT>;
  close(OLDNAMELISTINPUT);
  for ($iline=0; $iline<=$#namelistlines; $iline++ )
  {
    $line = $namelistlines[$iline];
    if ( $line =~  m/START_YEAR/i )
      { $namelistlines[$iline] = sprintf "  START_YEAR = " . "%4d, " x $#startyyyy4dom . "\n", @startyyyy4dom[1 .. $#startyyyy4dom] ; }
    if ( $line =~  m/START_MONTH/i )
      { $namelistlines[$iline] = sprintf "  START_MONTH = " . "%02d, " x $#startmm4dom . "\n", @startmm4dom[1 .. $#startmm4dom] ; }
    if ( $line =~  m/START_DAY/i )
      { $namelistlines[$iline] = sprintf "  START_DAY = " . "%02d, " x $#startdd4dom . "\n", @startdd4dom[1 .. $#startdd4dom] ; }
    if ( $line =~  m/START_HOUR/i )
       { $namelistlines[$iline] = sprintf "  START_HOUR = " . "%02d," x $#starthh4dom . "\n", @starthh4dom[1 .. $#starthh4dom] ; }
    if ( $line =~  m/END_YEAR/i )
      { $namelistlines[$iline] = sprintf "  END_YEAR = " . "%4d, " x $#endyyyy4dom . "\n", @endyyyy4dom[1 .. $#endyyyy4dom] ; }
    if ( $line =~  m/END_MONTH/i )
      { $namelistlines[$iline] = sprintf "  END_MONTH = " . "%02d, " x $#endmm4dom . "\n", @endmm4dom[1 .. $#endmm4dom] ; }
    if ( $line =~  m/END_DAY/i )
      { $namelistlines[$iline] = sprintf "  END_DAY = " . "%02d, " x $#enddd4dom . "\n", @enddd4dom[1 .. $#enddd4dom] ; }
    if ( $line =~  m/END_HOUR/i )
       { $namelistlines[$iline] = sprintf "  END_HOUR = " . "%02d, " x $#endhh4dom . "\n", @endhh4dom[1 .. $#endhh4dom] ; }
    if ( $line =~  m/MAX_DOM/i && $numdoms > 0 )
    { $namelistlines[$iline] = sprintf "  MAX_DOM = %d,\n", $numdoms ; }
    if ( $line =~  m/NUM_METGRID_LEVELS/i )
    { $namelistlines[$iline] = sprintf "  NUM_METGRID_LEVELS = %2d, \n",$num_metgrid_levels{$GRIBFILE_MODEL} ; }
    if ( defined $intervalseconds )
    {
      if ( $line =~  m/INTERVAL_SECONDS/i )
      { $namelistlines[$iline] = sprintf "  INTERVAL_SECONDS = %d,\n", $intervalseconds ; }
    } 
    ### IF $DOMAIN1_TIMESTEP IN PARAMETERS FILE, OVERWRITE namelist.template TIME_STEP
    ### note $regionname global variable used in parameters file
    if ( defined $DOMAIN1_TIMESTEP{$regionname}[$IWINDOW] )
    {
      if ( $line =~  m/ TIME_STEP  *=/i )
      { $namelistlines[$iline] = sprintf "  TIME_STEP = %d,\n", $DOMAIN1_TIMESTEP{$regionname}[$IWINDOW] ; }
    }
  }
  print NEWNAMELISTINPUT @namelistlines ;
  close(NEWNAMELISTINPUT);
  ### keep a copy of the previous namelists input
  `cp -f $wrfnamelistfile "${wrfnamelistfile}.last"`;
}
#########################################################################
#########################################################################
sub template_to_fake1namelist
{  
  ### require start=end same as domain1 - should be true for normal and not matter for windowed run and allows arbitraty start for latter
  my $inputmoad = $_[0];
  my $intervalseconds = $_[1];
  if ($LPRINT>3) {print $PRINTFH "         using template_to_fakenamelist with @_\n";}
  ### CREATE RUN NAMELIST TO RUN *DOMAIN2* real.exe FROM TEMPLATE
  ### uses external $kdomain which is never 1
  open(OLDNAMELISTINPUT,"<$WRFBASEDIR/WRFV2/RASP/$inputmoad/namelist.template") or die "Missing namelist.input file for $regionkey - run aborted" ;
  open(NEWNAMELISTINPUT,">${wrfnamelistfile}") ;
  @namelistlines = <OLDNAMELISTINPUT>;
  close(OLDNAMELISTINPUT);
  for ($iline=0; $iline<=$#namelistlines; $iline++ )
  {
    ### FOR THIS CASE END TIME MUST EQUAL START TIME
    $line = $namelistlines[$iline];
     if ( $line =~  m/START_YEAR/i )
        { $namelistlines[$iline] = sprintf "  START_YEAR = %4d,\n",$startyyyy4dom[$kdomain] ; }
     if ( $line =~  m/START_MONTH/i )
        { $namelistlines[$iline] = sprintf "  START_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
     if ( $line =~  m/START_DAY/i )
        { $namelistlines[$iline] = sprintf "  START_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
     if ( $line =~  m/START_HOUR/i )
       { $namelistlines[$iline] = sprintf "  START_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    if ( $line =~  m/END_YEAR/i )
      { $namelistlines[$iline] = sprintf "  END_YEAR = %4d,,\n",$startyyyy4dom[$kdomain] ; }
    if ( $line =~  m/END_MONTH/i )
      { $namelistlines[$iline] = sprintf "  END_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
    if ( $line =~  m/END_DAY/i )
      { $namelistlines[$iline] = sprintf "  END_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
    if ( $line =~  m/END_HOUR/i )
      { $namelistlines[$iline] = sprintf "  END_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    ### SPECIFY ONLY A SINGLE DOMAIN 
    if ( $line =~  m/MAX_DOM/i )
      { $namelistlines[$iline] = sprintf "  MAX_DOM = 1,\n" ; }
    if ( $line =~  m/NUM_METGRID_LEVELS/i )
       { $namelistlines[$iline] = sprintf "  NUM_METGRID_LEVELS = %2d, \n",$num_metgrid_levels{$GRIBFILE_MODEL} ; }
    if ( defined $intervalseconds )
    {
      if ( $line =~  m/INTERVAL_SECONDS/i )
        { $namelistlines[$iline] = sprintf "  INTERVAL_SECONDS = %d,\n", $intervalseconds ; }
    }
    ### SELECT DOMAIN VALUES SPECIFIC TO THIS DOMAIN
    if ( $line =~m/^ *e_we *=/i || $line =~m/^ *e_sn *=/i || $line =~m/^ *e_vert *=/i || $line =~  m/^ *d[xy] *=/i )
    { 
      for ( $ii=1; $ii<=($kdomain-1); $ii++ )
      { 
        $namelistlines[$iline] =~ s/=[^,]*,/ =/ ;
      }
    }
  }
  print NEWNAMELISTINPUT @namelistlines ;
  close(NEWNAMELISTINPUT);
}
#########################################################################
#########################################################################
sub template_to_ndownnamelist
{  
###### ALA template_to_fake1namelist EXCEPT
###### 2 domains instead of 1
###### removes column _after_ first col for i_parent_start,j_parent_start
###### dont require start=end same as domain1
  my $inputmoad = $_[0];
  my $intervalseconds = $_[1];
  if ($LPRINT>3) {print $PRINTFH "         using template_to_ndownnamelist with @_\n";}
  ### CREATE RUN NAMELIST TO RUN *DOMAIN2* real.exe FROM TEMPLATE
  ### uses external $kdomain which is never 1
  open(OLDNAMELISTINPUT,"<$WRFBASEDIR/WRFV2/RASP/$inputmoad/namelist.template") or die "Missing namelist.input file for $regionkey - run aborted" ;
  open(NEWNAMELISTINPUT,">${wrfnamelistfile}") ;
  @namelistlines = <OLDNAMELISTINPUT>;
  close(OLDNAMELISTINPUT);
  for ($iline=0; $iline<=$#namelistlines; $iline++ )
  {
    ### FOR THIS CASE END TIME MUST EQUAL START TIME
    $line = $namelistlines[$iline];
     if ( $line =~  m/START_YEAR/i )
        { $namelistlines[$iline] = sprintf "  START_YEAR = %4d,\n",$startyyyy4dom[$kdomain] ; }
     if ( $line =~  m/START_MONTH/i )
        { $namelistlines[$iline] = sprintf "  START_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
     if ( $line =~  m/START_DAY/i )
        { $namelistlines[$iline] = sprintf "  START_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
     if ( $line =~  m/START_HOUR/i )
       { $namelistlines[$iline] = sprintf "  START_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    if ( $line =~  m/END_YEAR/i )
      { $namelistlines[$iline] = sprintf "  END_YEAR = %4d,,\n",$startyyyy4dom[$kdomain] ; }
    if ( $line =~  m/END_MONTH/i )
      { $namelistlines[$iline] = sprintf "  END_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
    if ( $line =~  m/END_DAY/i )
      { $namelistlines[$iline] = sprintf "  END_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
    if ( $line =~  m/END_HOUR/i )
      { $namelistlines[$iline] = sprintf "  END_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    ### SPECIFY ONLY A SINGLE DOMAIN 
    if ( $line =~  m/MAX_DOM/i )
      { $namelistlines[$iline] = sprintf "  MAX_DOM = 1,\n" ; }
    if ( $line =~  m/NUM_METGRID_LEVELS/i )
       { $namelistlines[$iline] = sprintf "  NUM_METGRID_LEVELS = %2d, \n",$num_metgrid_levels{$GRIBFILE_MODEL} ; }
    if ( defined $intervalseconds )
    {
      if ( $line =~  m/INTERVAL_SECONDS/i )
        { $namelistlines[$iline] = sprintf "  INTERVAL_SECONDS = %d,\n", $intervalseconds ; }
    }
    if( $IWINDOW == 1 )
    {
      if ( $line =~  m/MAX_DOM/i )
        { $namelistlines[$iline] = "  MAX_DOM = 2, \n"; }
      if ( $line =~  m/i_parent_start/i  || $line =~  m/j_parent_start/i )
        { $namelistlines[$iline] =~ s/(_parent_start\s*=\s*[0-9]+\s*,)\s*[0-9]+\s*,/$1/ ; }
      if ( $line =~  m/parent_grid_ratio/i )
        { $namelistlines[$iline] =~ s/(parent_grid_ratio\s*=\s*[0-9]+\s*,)\s*[0-9]+\s*,/$1/ ; }
    }
    ### SELECT DOMAIN VALUES SPECIFIC TO THIS DOMAIN
    if ( $line =~m/^ *e_we *=/i || $line =~m/^ *e_sn *=/i || $line =~m/^ *e_vert *=/i || $line =~  m/^ *d[xy] *=/i )
    { 
      for ( $ii=1; $ii<=($kdomain-1); $ii++ )
      { 
        $namelistlines[$iline] =~ s/=[^,]*,/ =/ ;
      }
    }
  }
  print NEWNAMELISTINPUT @namelistlines ;
  close(NEWNAMELISTINPUT);
}
#########################################################################
#########################################################################
sub output_model_results_hhmm ()
### CALL ROUTINE FOR EACH OUTPUT TIME TO DO WRF PLOTS, DO FTPING + SAVE
### this routine is called when $LTHREADEDREGIONRUN=0 - intended for testing so domain to be plotted hard-wired below
{
  if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time); print $PRINTFH "   $regionname model plot start at $time\n";}
sleep 30 ;
  my @historyhhmmlist = @_;
  foreach $historyhhmm (@historyhhmmlist)
  {
    $historyhh = substr  $historyhhmm, 0, 2 ;
    $historymm = substr  $historyhhmm, 2, 2 ;
    ### set wrf output filename
    ### need criteria for determining when tomorrow's julian date needed 
    ### DAY/HR SELECTION - to determine wrfout files available for processing
    ### this routine is called when $LTHREADEDREGIONRUN=0 - intended for testing so domain to be plotted hard-wired here
    if ( $historyhhmm >= $historyhhmmlist[$IWINDOW][0] )
    { 
      ### PLOT SINGLE DOMAIN
      $wrffilename = sprintf "$WRFBASEDIR/WRFV2/RASP/$moad/wrfout_d02_%4d-%02d-%02d_%02d:%02d:00",${jyr4},${jmo2},${jda2},${historyhh},${historymm};
    }
    else
    {
      ### PLOT SINGLE DOMAIN
        $wrffilename = sprintf "$WRFBASEDIR/WRFV2/RASP/$moad/wrfout_d02_%4d-%02d-%02d_%02d:%02d:00",${jyr4p1},${jmo2p1},${jda2p1},${historyhh},${historymm};
    }
    if ( -s "$wrffilename" ) 
    {
      &output_wrffile_results ( $wrffilename );
    }
    else
    {
      if ($LPRINT>1) { print $PRINTFH "   ** NO output result call for hr $historyhhmm - nonexistent ${wrffilename} \n";}
    }
  }
}
#########################################################################
#########################################################################
sub output_wrffile_results (@)
### CREATE WRF PLOTS FOR WRF FILES , DO FTPING + SAVE FOR SINGLE OUTPUT TIME
### *NB* DEPENDS ON EXTERNAL $IWINDOW,$regionkey,$regionname
{
  ### note that input can be array, though generally is just a single filename
  my @wrffilename = @_;
  my ( $moad, $kdomain, $domainid, $historyhhmm );
  print $PRINTFH "   -- RESULTS OUTPUT for $IWINDOW $regionkey $regionname @wrffilename\n";
  ### LOOP OVER ALL INPUT WRF FILENAMES
  foreach $wrffilename (@wrffilename)
  {
    ### EXTRACT $moad FROM FILENAME
    ( $moad = $wrffilename ) =~ s|$WRFBASEDIR/WRFV2/RASP/([^/]+)/.*|$1|;
    ### AT PRESENT, PLOT 2 DOMAINS
    ### EXTRACT $kdomain FROM FILENAME
    ### allow inclusion of "previous" in filename so can use routine with those filenames
    ( $kdomain = $wrffilename ) =~ s|.*wrfout_d0([1-9]).*|$1|;
    ### SET DOMAIN NAME 3 FOR WINDOWED CASE
    ### $domainid d/w is posted&saved id used in $regionname directory (vice $moad) for normal/windowed domain
    if( $moad =~ m|-WINDOW|i && $LRUN_WINDOW{$regionkey} > 0 )
      { $domainid = 'w' ; }
    else
      { $domainid = 'd' ; }
    ( $historyhhmm = $wrffilename ) =~ s/.*wrfout_d.*_([0-9][0-9]:[0-9][0-9]):.*/$1/;
    $historyhhmm =~ s|:||;
    ### set date variables for display
    my ( $historyhhmmplus, $fcstperiod ); 
    ### DAY/HR SELECTION - used to set historyhhmmplus
    if ( $historyhhmm >= $PLOT_HHMMLIST{$regionkey}[$IWINDOW][0] )
    { $historyhhmmplus = $historyhhmm ; }
    else 
    { $historyhhmmplus = $historyhhmm + 2400 ; }
    ### allow forecast period string to be decimal hours but strip off any .0 
    $raspfcstperiod = sprintf "%.1f", substr ( ${historyhhmmplus}, 0, 2 ) +0.01667*substr ( ${historyhhmmplus}, 2, 2 ) - $hhinit ;
    if( $raspfcstperiod < 0 ) { $raspfcstperiod += 24; }
    $fcstperiod = sprintf "%.1f", ($gribfcstperiod + $raspfcstperiod ) ;
    ( $fcstperiodprt = $fcstperiod ) =~ s|.0$|| ;
    $time = `date +%H:%M:%S`; jchomp( $time );
    print $PRINTFH "      NEW WRF OUTPUT FILE FOUND at $time : $wrffilename => $moad  & $kdomain & $domainid & $historyhhmm & $historyhhmmplus & $fcstperiod & $LRUN_WINDOW{$regionkey} \n";
    ### CREATE WEB IMAGES FROM WRF OUTPUT FILE
    $imagedir = "$OUTDIR/$moad" ;
    ### ncl-environment variables
    $ENV{'ENV_NCL_REGIONNAME'} = $regionname ;
    $ENV{'ENV_NCL_FILENAME'} = $wrffilename ;
    $ENV{'ENV_NCL_OUTDIR'} = $imagedir ;
     ### use local time for plot print
    ( $filename = $wrffilename ) =~ s|.*/([^/]*)|$1| ;
    ( $head,$filemm,$tail ) = split /-/, $filename ;
    ( $fileyyyy = $head ) =~ s|.*_([0-9][0-9][0-9][0-9]).*|$1| ;
    ( $filedd = $tail ) =~ s|([0-9][0-9])_.*|$1| ;
    ( $filehh = $tail ) =~ s|.*_([0-9][0-9]):.*|$1| ;
    ( $filemin = $tail ) =~ s|.*_[0-9][0-9]:([0-9][0-9]).*|$1| ;
    ( $localyyyy,$localmm,$localdd,$localhh, $localmin ) = &GMT_plus_mins( $fileyyyy, $filemm, $filedd, $filehh, $filemin, (60*$LOCALTIME_ADJ{$regionkey}) );
    ( $localday = $localdd ) =~ s|^0|| ;
    $localmon = $mon{$localmm} ;
    $localdow = $dow[ &dayofweek( $localdd, $localmm, $localyyyy ) ];     # uses Date::DayOfWeek
    ### set "day" used in image filename based on run argument
    if( $JOBARG =~ m|\+1| )     { $localsoarday = 'curr+1.'; }
    elsif( $JOBARG =~ m|\+2| )  { $localsoarday = 'curr+2.'; }
    elsif( $JOBARG =~ m|\+3| )  { $localsoarday = 'curr+3.'; }
    else                        { $localsoarday = 'curr.'; }
    $postday = $localsoarday ;    
    ### determine data creation time (gmt)
    ( my $ztime = &zuluhhmm ) =~ s|:|| ;
    $ENV{'ENV_NCL_ID'} = sprintf "Valid %02d%02d %s ~Z75~(%02d%02dZ)~Z~ %s %s %s %d ~Z75~[%shrFcst@%sz]~Z~", $localhh,$localmin, $LOCALTIME_ID{$regionkey}, $filehh,$filemin, $localdow, $localday, $localmon, $localyyyy, $fcstperiodprt,$ztime ;
    ### datafile info - add blank at end as separator
    $ENV{'ENV_NCL_DATIME'} = sprintf "Day= %d %d %d %s ValidLST= %d%02d %s ValidZ= %d%02d Fcst= %s Init= %d ",  $localyyyy,$localmm,$localdd,$localdow, $localhh,$localmin,$LOCALTIME_ID{$regionkey}, $filehh,$filemin, $fcstperiod, $gribfcstperiod ; 
    ### set parameter list sent to rasp.ncl
    $ENV{'ENV_NCL_PARAMS'} = sprintf "%s", ( join ':',@{$PARAMETER_DOLIST{$regionkey}} )  ;
    ### run ncl for this file to create individual ncgm files
    ### remove ncgm/data file so do not plot old data if ncl failure
    `rm -f $ENV{'ENV_NCL_OUTDIR'}/*.ncgm 2>/dev/null`;
    $paramiddatastring = '' ;
    for ($iimage=0; $iimage<=$#{$PARAMETER_DOLIST{$regionkey}}; $iimage++ )
    {
      $paramiddatastring .= "$PARAMETER_DOLIST{$regionkey}[$iimage] " ;
    }
   `cd $ENV{'ENV_NCL_OUTDIR'} ; rm -f $paramiddatastring 2>/dev/null`;
    ### put timeout on ncl after once hung for unknown reasons
    $rctimelimit = &system_child_timeout ( "cd $NCLDIR ; $NCARG_ROOT/bin/ncl < rasp.ncl >| rasp.ncl.out.$moad.0${kdomain} 2>&1", $ncltimeoutsec, 30 );
    if ( $rctimelimit > 0 )
    {
      &write_err( "*** ERROR: $wrffilename NCL TIMEOUT: $rctimelimit" );
      print STDERR `cat $NCLDIR/rasp.ncl.out.${moad}.0${kdomain}`;
      ### if batch mode, send email error notice to admininstrator
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'NCL_TIMEOUT'} )
      {
        `cp -p "$NCLDIR/rasp.ncl.out.$moad.0${kdomain}" "$NCLDIR/rasp.ncl.out.$moad.0${kdomain}.timelimiterror"` ;
        `echo " RC= $rctimelimit \n NCL log copy = $NCLDIR/rasp.ncl.out.$moad.0${kdomain}.error \n" | mail -s "$program NCL TIMEOUT for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
    }
    ### test for premature end of ncl script
    chomp( $successtest = `grep -c -i 'normal end' $NCLDIR/rasp.ncl.out.${moad}.0${kdomain} 2>/dev/null` ) ;
    ### not defined occurs if rasp.ncl missing
    if ( ! defined $successtest || $successtest eq '' || $successtest != 1 )
    {
      &write_err( "*** $moad ERROR: $wrffilename NCL ENDED ABNORMALLY - error reported in log file rasp.ncl.out.${moad}.0${kdomain} \n" );
      print STDERR `cat $NCLDIR/rasp.ncl.out.${moad}.0${kdomain}`;
      ### if batch mode, send email error notice to admininstrator
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'NCL_TIMEOUT'} )
      {
        `cp -p "$NCLDIR/rasp.ncl.out.$moad.0${kdomain}" "$NCLDIR/rasp.ncl.out.$moad.0${kdomain}.error"` ;
        `echo " RC= $rctimelimit \n NCL log copy = $NCLDIR/rasp.ncl.out.$moad.0${kdomain}.error \n" | mail -s "$program NCL TIMEOUT for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
    }
    ### set image size for  region-specific {$regionkey}[$IWINDOW=0,1]
    $imagesize =  $PLOT_IMAGE_SIZE{$regionkey}[$IWINDOW][${kdomain}-1] ;
    if( $imagesize =~ m|\*| )
    {
      ### for poor-man anti-aliasing using over-large ctrans output raster image
      ### but black gets progressively lighter as multiplier increases
      ### and image size increased by factor of ~9 !
      $imagesize =~ s|\*|x| ;
      ($imagewidth,$imageheight) =  split( /x/, $imagesize );
      $ctransimagesize = sprintf "%dx%d", (2*$imagewidth),(2*$imageheight) ;
    }
    else
    {
      $ctransimagesize = $imagesize ;
    }
    ### START OF LOOP OVER ALL NCGM FILES CREATED 
    @imagedonelist = () ;
    @datadonelist = () ;
    for ($iimage=0; $iimage<=$#{$PARAMETER_DOLIST{$regionkey}}; $iimage++ )
    {
      $paramid = $PARAMETER_DOLIST{$regionkey}[$iimage] ;
      $ncgmname = sprintf "%s.ncgm", $paramid ;
      ### AT PRESENT, PLOT 2 DOMAINS
      ### "d" indicates "domain" for plots in run directory, but "w" for "windowed grid" when posted/stored 
      ###     since window domains combined with non-window domains when posted/stored
      ### below should agree with $pngfilename used for $LSEND>0 and $LSAVE>0 below  and also with $localfiletail & $ftpfiletail used for $LSEND<0 below
      $pngfilename = sprintf "%s.%s%02d%02dlst.d${kdomain}.png", $paramid,$localsoarday,$localhh,$localmin ;
      ### remove old files to prevent inadvertent use
      `rm -f $imagedir/tmp.rasp.sun $imagedir/$pngfilename`;
      ### skip if non-existent or stub ncgm file (needed for domains with an invalid soundings location)
      if( -f "$ENV{'ENV_NCL_OUTDIR'}/$ncgmname" && -s "$ENV{'ENV_NCL_OUTDIR'}/$ncgmname" > 4000 )
      {
        ### convert individual ncgm files into png images
        ### NCAR CTRANS CONVERTS METAFILE TO SQUARE BITMAP
        jchomp( my $ctransout = `NCARG_ROOT=$NCARG_ROOT ; export NCARG_ROOT ; $CTRANS -resolution $ctransimagesize -d sun -outfile $imagedir/tmp.rasp.sun $ENV{'ENV_NCL_OUTDIR'}/$ncgmname 2>&1` );
        ### convert converts square bitmap to (sometimes) non-square png
        jchomp( my $convertout = `$CONVERT $imagedir/tmp.rasp.sun -resize $imagesize $imagedir/$pngfilename 2>&1` );
        ### write output info
        if ($LPRINT>1) { print $PRINTFH "      PLOTTED $paramid for $moad ${domainid}${kdomain} at ${historyhhmmplus}Z = $localsoarday ${localhh}${localmin} $LOCALTIME_ID{$regionkey} $localday $localmon $localyyyy to $imagedir $ncgmname \n"; }
        ### CREATE IMAGE FILE NAME LIST
        push @imagedonelist, $paramid ;
      }
      else
        { if ($LPRINT>1) { print $PRINTFH "  ** WARNING: SKIPPING BAD PLOT METAFILE $ENV{'ENV_NCL_OUTDIR'}/$ncgmname (OK if sounding/cross-section location is outside domain) \n"; } }
      ### COPY DATAFILE TO INCLUDE TIME AND GRID INFO
        ### CREATE DATA FILE NAME LIST
        ### write datafile to html location, saving previous datafile
        ### have two wind datafiles for each wind image
        if( $paramid =~ m|wind| && $paramid !~ m|windshear| )
        {
          if( -s "$imagedir/${paramid}spd.data" )
          {
            $outdatafilename = sprintf "%sspd.%s%02d%02dlst.d${kdomain}.data", $paramid,$localsoarday,$localhh,$localmin ;
            my $copyout = `cp -p "$imagedir/${paramid}spd.data" "$imagedir/$outdatafilename" 2<&1`;
            push @datadonelist,"${paramid}spd";
          }
          if( -s "$imagedir/${paramid}dir.data" )
          { 
            $outdatafilename = sprintf "%sdir.%s%02d%02dlst.d${kdomain}.data", $paramid,$localsoarday,$localhh,$localmin ;
            my $copyout = `cp -p "$imagedir/${paramid}dir.data" "$imagedir/$outdatafilename" 2<&1`;
            push @datadonelist,"${paramid}dir";
          }
        } 
        ### no data file for some parameters but those skipped by tests for file existence
        elsif( -s "$imagedir/${paramid}.data" )
        {
          $outdatafilename = sprintf "%s.%s%02d%02dlst.d${kdomain}.data", $paramid,$localsoarday,$localhh,$localmin ;
          my $copyout = `cp -p "$imagedir/${paramid}.data" "$imagedir/$outdatafilename" 2<&1`;
          push @datadonelist,"${paramid}";
        }
    ### END OF LOOP OVER ALL NCGM FILES CREATED 
    }
    $time = `date +%H:%M:%S`;
    ### SEND IMAGE & DATA FILES TO WEBSITE
    if( $LSEND > 0 )
    {
      ### SEND IMAGE FILES
      foreach $paramid (@imagedonelist)
      {
        ### write image file to html location, saving previous image file
        ### allow for tests using filename pre-pended with "test."
        ### below should agree with $pngfilename used for plot creation above
        $pngfilename = sprintf "%s.%s%02d%02dlst.d${kdomain}.png", $paramid,$localsoarday,$localhh,$localmin ;
        $pngpostname = sprintf "%s.%s%02d%02dlst.${domainid}${kdomain}.png", $paramid,$postday,$localhh,$localmin ;
        if( $LSEND == 1 ) { $pngpostname = "test.${pngpostname}"; }
        ## quit making previous just overwrite tjo `mv -f $HTMLBASEDIR/$regionname/FCST/${pngpostname}  $HTMLBASEDIR/$regionname/FCST/previous.${pngpostname} 2>/dev/null`;
        `cp -pf $imagedir/${pngfilename} $HTMLBASEDIR/$regionname/FCST/${pngpostname}`;
        ###### CREATE IMAGE LOOP (CREATED IN WEBSITE DIRECTORY BUT NOT SAVED)
        ### use additional if requirements for windowed case (i dont remember why!)
        if( $#{$PLOT_LOOP_HHMMLIST{$regionkey}[$IWINDOW]} > -1 
            && (  ( $IWINDOW == 0 && ( $kdomain == 2 ) ) ||
            ( $IWINDOW == 1 && ( ( $LRUN_WINDOW{$regionkey} == 0 && $kdomain == $MAXDOMAIN{$regionkey}[$IWINDOW] ) || ( $LRUN_WINDOW{$regionkey} > 0 && $moad =~ m|-WINDOW|i && $kdomain == $MAXDOMAIN{$regionkey}[$IWINDOW] ) ) )  ) )
        {
          if( grep /$historyhhmm/, @{$PLOT_LOOP_HHMMLIST{$regionkey}[$IWINDOW]} ) 
          {
            $imageloopfilelist{$moad}{$paramid} .= " $pngfilename";
          }
          ### for final selected time, create the image loop
          if( $historyhhmm eq $PLOT_LOOP_HHMMLIST{$regionkey}[$IWINDOW][$#{$PLOT_LOOP_HHMMLIST{$regionkey}[$IWINDOW]}] ) 
          {
            ### create loop title image if requested
            if( grep /title/, @{$PLOT_LOOP_HHMMLIST{$regionkey}[$IWINDOW]} ) 
            {
              if ( ! defined $paraminfo{$paramid} ) {  $paraminfo{$paramid} = $paramid ; }
              my $plttextout = `cd $imagedir ; $BASEDIR/UTIL/plt_text.exe -rMNVH \"$paraminfo{$paramid}\" \"\" \"$localdow  ${localday} $localmon\"`;
              jchomp( my $ctransout = `NCARG_ROOT=$NCARG_ROOT ; export NCARG_ROOT ; $CTRANS -resolution $ctransimagesize -d sun -outfile $imagedir/tmp.rasp.sun $imagedir/gmeta 2>&1` );
              jchomp( my $convertout = `$CONVERT $imagedir/tmp.rasp.sun -resize $ctransimagesize $imagedir/looptitle.gif 2>&1` );
              ### add title to loop image list
              $imageloopfilelist{$moad}{$paramid} = "looptitle.gif $imageloopfilelist{$moad}{$paramid}";
            }
            my $loopcreateout = `cd $imagedir ; $CONVERT -loop 30 -delay 100 $imageloopfilelist{$moad}{$paramid} "$imagedir/$paramid.${localsoarday}loop.d${MAXDOMAIN{$regionkey}[$IWINDOW]}.gif"`;
            $loopfilename = "${paramid}.${localsoarday}loop.d${MAXDOMAIN{$regionkey}[$IWINDOW]}.gif" ;
            $looppostname = "${paramid}.${postday}loop.${domainid}${kdomain}.gif" ;
            `mv -f "$HTMLBASEDIR/$regionname/FCST/${looppostname}" "$HTMLBASEDIR/$regionname/FCST/previous.${looppostname}" 2>/dev/null`;
            `cp -pf "$imagedir/$loopfilename" "$HTMLBASEDIR/$regionname/FCST/${looppostname}"`;
        ### write output info
        if ($LPRINT>1) { print $PRINTFH "      LOOP PLOT $paramid for $moad ${domainid}${kdomain} for $postday $localday $localmon to $imagedir\n"; }
          }
        }                  
      }
	###################  put annotations on the surface wind maps
	## if ($LPRINT>1) { print $PRINTFH "tjo After moving files from RUN/OUT to $HTMLBASEDIR/$regionname/FCST/  domainid=${domainid} time=${localhh}${localmin}"; }
        ##################
      ### SEND DATA FILES
      ### WEBSITE DATAFILES ARE *NOT* COMPRESSED 
      foreach $paramid (@datadonelist)
      {
        ### not all images have datafiles
        $datafilename = "${paramid}.data" ; 
        if ( -s "$imagedir/${datafilename}" )
        {
          $datapostname = sprintf "%s.%s%02d%02dlst.${domainid}${kdomain}.data",$paramid,$postday,$localhh,$localmin ;
          if( $LSEND == 1 ) { $datapostname = "test.${datapostname}";  }
          `mv -f $HTMLBASEDIR/$regionname/FCST/${datapostname}  $HTMLBASEDIR/$regionname/FCST/previous.${datapostname} 2>/dev/null`;
          `cp -pf $imagedir/${datafilename} $HTMLBASEDIR/$regionname/FCST/${datapostname}`;
        }
      }
      ### SEND VALID DAY INFO FILES - so validation day associated with time file can be determined via web if needed
      $hrinfopostname = sprintf "valid.%s%02d%02dlst.${domainid}${kdomain}.txt", $postday,$localhh,$localmin ;
      if( $LSEND == 1 ) { $hrinfopostname = "test.${hrinfopostname}";  }
      `echo "$julianyyyymmddprt{$localsoarday}" >| $HTMLBASEDIR/$regionname/FCST/${hrinfopostname}`;
      $latestinfopostname = sprintf "valid.%s${domainid}${kdomain}.txt", $postday ;
      if( $LSEND == 1 ) { $latestinfopostname = "test.${latestinfopostname}";  }
      `echo "$julianyyyymmddprt{$localsoarday} ${localhh}${localmin}" >| $HTMLBASEDIR/$regionname/FCST/${latestinfopostname}`;
      ### PRINT PROGRESS MESSAGE
      if ($LPRINT>1) { print $PRINTFH "      POSTED $moad ${domainid}${kdomain} plots for ${historyhhmmplus}Z = $postday ${localhh}:${localmin} $LOCALTIME_ID{$regionkey} $localday $localmon $localyyyy at $time" ; }
    }
    elsif( $LSEND < 0 )
    {
      ### FTP IMAGE TO REMOTE WEBSITE
      ### NOT TESTED !!!
      ### DOES NOT INCLUDE DATAFILES
      ### below should agree with $pngfilename & $pngpostname used for $LSEND>0 above
      $localfiletail = sprintf "%s%02d%02dlst.d${kdomain}.png", $localsoarday,$localhh,$localmin ;
      $ftpfiletail = sprintf "%s%02d%02dlst.${domainid}${kdomain}.png", $postday,$localhh,$localmin ;
      my $ftpout = &system_child_timeout ( "$UTILDIR/rasp.multiftp $imagedir ${regionname}/FCST $localfiletail $ftpfiletail $LSEND @imagedonelist", $ftptimeoutsec, 60 );
      if ($LPRINT>1) { print $PRINTFH "      FTP $moad ${domainid}${kdomain} plots for ${historyhhmmplus}Z = $postday ${localhh}:${localmin} $LOCALTIME_ID{$regionkey} $localday $localmon $localyyyy at $time" ; } 
      if ($LPRINT>1) { print $PRINTFH " ** WARNING ** $LSEND<0 OPTION HAS NOT BEEN TESTED \n" ; } 
      exit 1;
    }
    ### START OF SAVE DESIRED DATA/IMAGE FILES
    ### save directory based on region-specific julian date intended to represent soaring day
    ### include dependence on non-window/window run and domain (through PLOT_IMAGE_SIZE)
    if( $LSAVE > 0 && defined $PLOT_IMAGE_SIZE{$regionkey}[$IWINDOW][${kdomain}-1] && $PLOT_IMAGE_SIZE{$regionkey}[$IWINDOW][${kdomain}-1] ne '' && grep ( m/^${historyhhmm}$/, @{$SAVE_PLOT_HHMMLIST{$regionkey}[$IWINDOW]} ) > 0 )
    {
      ### SAVE IMAGE FILES 
      if( $LSAVE > 1 )
      {
        foreach $paramid (@imagedonelist)
        { 
          ###  SAVE HASH MUST BE RESTRICTIVE (if wanted to allow it to also be inclusive would have to move grep(m/^${historyhhmm}$/,@{$SAVE_PLOT_HHMMLIST{$regionkey}[$IWINDOW]})>0 to top of thie loop
          if( defined $LSAVE{$regionkey}{$paramid}{$historyhhmm}[$IWINDOW] && $LSAVE{$regionkey}{$paramid}{$historyhhmm}[$IWINDOW] <= 1 )
          {  next;  }
          ### below should agree with $pngfilename used for plot creation above
          $pngfilename = sprintf "%s.%s%02d%02dlst.d${kdomain}.png", $paramid,$localsoarday,$localhh,$localmin ;
          ### SAVE IMAGE FILES 
          ### skip if non-existent ncgm file (should happen only for soundings)
          if( -s "$imagedir/${pngfilename}" )
          {
            ### AT PRESENT, PLOT 2 DOMAINS BUT SAVE ONLY DOMAIN 2
            ### these lines should match those in image creation loop above
            ### "d" indicates "domain" for plots in run directory, but "w" for "windowed grid" when posted/stored 
            ###     since window domains combined with non-window domains when posted/stored
            $pngstorename = sprintf "%s.%s%02d%02dlst.${domainid}${kdomain}.png", $paramid,$localsoarday,$localhh,$localmin ;
            `cp -pf $imagedir/${pngfilename} ${savesubdir{$regionname}}/${pngstorename}`;
          }
        }
        if ($LPRINT>1) { $time = `date +%H:%M:%S` ; print $PRINTFH "      SAVED $moad ${domainid}${kdomain} plot images for ${historyhhmmplus}Z = $localsoarday ${localhh}:${localmin} $LOCALTIME_ID{$regionkey} $localday $localmon $localyyyy to $savesubdir{$regionname} at $time"; } 
      }
      ### SAVE DATA FILES
      ### SAVED DATAFILES ARE ZIP COMPRESSED 
      if( $LSAVE > 0 )
      {
        foreach $paramid (@datadonelist)
        {
          ###  SAVE HASH MUST BE MORE RESTRICTIVE (if wanted to allow it to also be inclusive would have to move grep(m/^${historyhhmm}$/,@{$SAVE_PLOT_HHMMLIST{$regionkey}[$IWINDOW]})>0 to top of thie loop
          if( defined $LSAVE{$regionkey}{$paramid}{$historyhhmm}[$IWINDOW] && $LSAVE{$regionkey}{$paramid}{$historyhhmm}[$IWINDOW] <= 0 )
          { next; }
          $datafilename = "${paramid}.data" ; 
          $datastorename = sprintf "%s.%s%02d%02dlst.${domainid}${kdomain}.data.zip", $paramid,$localsoarday,$localhh,$localmin ;
          ### forecast period must be decimal hours
          $raspfcstperiod = sprintf "%.1f", substr ( ${historyhhmmplus}, 0, 2 ) +0.01667*substr ( ${historyhhmmplus}, 2, 2 ) - $hhinit  ;
          if( $raspfcstperiod < 0 ) { $raspfcstperiod += 24; }
          $fcstperiod = sprintf "%.1f", ($gribfcstperiod + $raspfcstperiod ) ;
          ### use ":" delimiter since $fcstperiod contains "."
          $zipinternalname = "blipmap:rasp:${regionname_lc}-${domainid}${kdomain}:${paramid}:${filevalidday}:${localhh}${localmin}${LOCALTIME_ID{$regionkey}}:${fcstperiod}h:${gribfcstperiod}h:${jyr4}${jmo2}${jda2}=${localyyyy}${localmm}${localdd}:${localhh}${localmin}lst" ;
          ### skip if non-existent data file 
          if( -s "$imagedir/${datafilename}" )
          {
            ### THIS USES SEPARATE ZIP FILE FOR EACH PARAM,DAY,TIME deleting any previous zip file to prevent combining multiple daily run fcst pds into same zip file
            ### (if do not delete, need chmod since despite -f option Debian produces writes when no file exists ?)
            `rm -f ${savesubdir{$regionname}}/${datastorename} ; cd $imagedir ; ln -sf $datafilename $zipinternalname ; $ZIP ${savesubdir{$regionname}}/${datastorename} $zipinternalname ; rm $zipinternalname`;
          }
        }
        if ($LPRINT>1) { $time = `date +%H:%M:%S` ; print $PRINTFH "      SAVED $moad ${domainid}${kdomain} plot  data  for ${historyhhmmplus}Z = $localsoarday ${localhh}:${localmin} $LOCALTIME_ID{$regionkey} $localday $localmon $localyyyy to $savesubdir{$regionname} at $time"; } 
      }
      ### MAKE IMAGE+DATA FILES READ-ONLY TO PREVENT ACCIDENTAL OVER-WRITE
      `chmod -f 444 $savesubdir{$regionname}/*`;
    ### END OF SAVE DESIRED DATA/IMAGE FILES
    }
  ### HOOK TO RUN EXTERNAL PROGRAM AFTER PROCESSING EACH OUTPUT FILE IMAGES (dont wait for it to finish - put child process in background)
  ### spun-off child might be terminated if this program terminates (if so, if I want a child program run at termination of job, might create a second "hook" call which waits for child to finish, ala $output_foregroundhook=`${DIR}/RUN/LOCAL/results_output.foregroundhook $outputhookargs`)
  $outputhookcommand = "${DIR}/RUN/LOCAL/results_output.hook";
  if( -x $outputhookcommand )
  {
    chomp( $datime = `date +%Y-%m-%d_%H:%M:%S` );
    $outputhookargs = join ',', ( $JOBARG,$datime,$rundayprt,$moad,$regionname,$IWINDOW,"${domainid}${kdomain}",$localsoarday,$localyyyy,$localmm,$localdd,$localhh,$localmin,$LOCALTIME_ID{$regionkey},"${historyhhmmplus}Z" );
    my $outputhookproc = Proc::Background->new( $outputhookcommand, $outputhookargs );
    if ($LPRINT>1) { print $PRINTFH "      OUTPUT HOOK COMPLETED: $outputhookargs \n"; } 
  }
  if ($LPRINT>1) { print $PRINTFH "   -- RESULTS OUTPUT COMPLETE \n"; } 
  ### END OF LOOP OVER ALL INPUT WRF FILENAMES
  }
}
#########################################################################
#########################################################################
sub setup_getgrib_parameters
### SET  MODEL-DEPENDENT LGETGRIB AND SCHEDULING PARAMETERS
{
  if ( $GRIBFILE_MODEL eq 'ETA' )
  {
    ###### SET MODEL-SPECIFIC GRIBGET PARAMETERS
    ### set max ftp time for grib get
    $getgrib_waitsec = 4 * 60 ;                # sleep time, _not_ a timeout time
    ### minimum grib filesize (smaller grib files are ignored)
    $mingribfilesize = 5000000;
    ### time for download of grib file (max so far 120+ mins)
    ### *NB* should match that used for curl in script gribftpget
    $gribgetftptimeoutmaxsec = 15 *60 ;
    ###### SET SCHEDULING GRIBGET PARAMETERS
    ### SET LGETGRIB=2 for scheduled get (1=LStests)
    if( $LGETGRIB>1)
      { $LGETGRIB = 2; }
    ### SET FILE AVAILABLITY SCHEDULE TIMES (Z)
    ### 11 march 2004 NCEP ETA TIMES:
    ### gribavailhrzoffset used to _add_ cushion to actual expected availabilty
    if( ! defined $gribavailhrzoffset )
    {
      $gribavailhrzoffset = $gribavailhrzoffset{ETA}; 
    }
    ### gribavailhrzinc is hr increment per forecast hour
    $gribavailhrzinc = 11 / ( 12 * 60 );
    ### gribavailhrz0 is hour of analysis availability for each init.time
    ### 04jan2005 - essentially same as to ones used for blip awip218 files
    ### NOTE THESE ARE ZULU VICE LOCAL TIME USED IN CRONTAB
    $gribavailhrz0{'00'} = &hhmm2hour( '01:40' );      # checked 20jan2005
    $gribavailhrz0{'06'} = &hhmm2hour( '07:14' );
    $gribavailhrz0{'12'} = &hhmm2hour( '13:40' );
    $gribavailhrz0{'18'} = &hhmm2hour( '19:14' );
  }
  elsif ( $GRIBFILE_MODEL eq 'GFSN' || $GRIBFILE_MODEL eq 'GFSA' || $GRIBFILE_MODEL eq 'AVN' )
  {
    ###### SET MODEL-SPECIFIC GRIBGET PARAMETERS
    ### set max ftp time for grib get
    $getgrib_waitsec = 4 * 60 ;                # sleep time, _not_ a timeout time
    ### minimum grib filesize (smaller grib files are ignored)
    $mingribfilesize = 21000000;
    ### time for download of grib file (max so far 120+ mins)
    ### *NB* should match that used for curl in script gribftpget
    $gribgetftptimeoutmaxsec = 15 *60 ;
    ###### SET SCHEDULING GRIBGET PARAMETERS
    ### SET LGETGRIB=2 for scheduled get (1=LStests)
    if( $LGETGRIB>1)
      { $LGETGRIB = 2; }
    ### SET FILE AVAILABLITY SCHEDULE TIMES (Z)
    ### gribavailhrzoffset used to _add_ cushion to actual expected availabilty
    ### allow $gribavailhrzoffset to be set by reading initialization file (rasp.run.parameters or rasp.site.parameters) for test purposes
    if( ! defined $gribavailhrzoffset )
    {
      $gribavailhrzoffset = $gribavailhrzoffset{$GRIBFILE_MODEL}; 
    }
    ### gribavailhrzinc is hr increment per forecast hour
    $gribavailhrzinc = 10 / ( 24 * 60 );
    ### gribavailhrz0 is hour of analysis availability for each init.time
    ### NOTE THESE ARE ZULU VICE LOCAL TIME USED IN CRONTAB
    $gribavailhrz0{'00'} = &hhmm2hour( '03:26' );      # checked 16aug2005
    $gribavailhrz0{'06'} = &hhmm2hour( '09:26' );
    $gribavailhrz0{'12'} = &hhmm2hour( '15:26' );
    $gribavailhrz0{'18'} = &hhmm2hour( '21:26' );
  }
  elsif ( $GRIBFILE_MODEL eq 'RUCH' )
  {
    ###### SET MODEL-SPECIFIC GRIBGET PARAMETERS
    ### set max ftp time for grib get
    $getgrib_waitsec = 4 * 60 ;                # sleep time, _not_ a timeout time
    ### minimum grib filesize (smaller grib files are ignored)
    $mingribfilesize = 45000000;
    ### time for download of grib file (max so far 120+ mins)
    ### *NB* should match that used for curl in script gribftpget
    $gribgetftptimeoutmaxsec = 15 *60 ;
    ###### SET SCHEDULING GRIBGET PARAMETERS
    ### SET LGETGRIB=2 for scheduled get (1=LStests)
    if( $LGETGRIB>1)
      { $LGETGRIB = 2; }
    ### SET FILE AVAILABLITY SCHEDULE TIMES (Z)
    ### gribavailhrzoffset used to _add_ cushion to actual expected availabilty
    if( ! defined $gribavailhrzoffset )
    {
      $gribavailhrzoffset = $gribavailhrzoffset{RUCH}; 
    }
    ### gribavailhrzinc is hr increment per forecast hour
    $gribavailhrzinc = 12 / ( 12 * 60 );
    ### gribavailhrz0 is hour of analysis availability for each init.time
    ### NOTE THESE ARE ZULU VICE LOCAL TIME USED IN CRONTAB
    ### here zero time actually for appearance of 1sthr - hr0 appears 15mins earlier
    $gribavailhrz0{'00'} = &hhmm2hour( '01:31' );      
    $gribavailhrz0{'03'} = &hhmm2hour( '04:23' );      #est from previous/next values
    $gribavailhrz0{'06'} = &hhmm2hour( '07:16' );
    $gribavailhrz0{'09'} = &hhmm2hour( '10:23' );      #est from previous/next values      
    $gribavailhrz0{'12'} = &hhmm2hour( '13:31' );
    $gribavailhrz0{'15'} = &hhmm2hour( '16:23' );      #est from previous/next values      
    $gribavailhrz0{'18'} = &hhmm2hour( '19:16' );
    $gribavailhrz0{'21'} = &hhmm2hour( '22:23' );      #est from previous/next values      
  }
}
#####################################################################################################
#####################################################################################################
sub setup_ftp_parameters ()
### SET  FTP PARAMETERS
{
  #####################  START OF ETA FTP PARAMETER SETUP  ####################
  if ( $GRIBFILE_MODEL eq 'ETA' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
      ###tjo  changing to http nomads site
      #### http://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/
      ### can curl get there with ftp?  No. So change gribftpget to remove the ftp://  tjo
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    $gribftpsite1 = 'http://nomads.ncep.noaa.gov';
##    $gribftpsite1 = 'nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'ETA';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/nam/prod";
    ### at present only need single directory for eta since no "minus" times used
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
    #### IF PREVIOUS ("negative") DAY NEEDED, USE $gribftpdirectory[2]
  }
  elsif ( $GRIBFILE_MODEL eq 'GFSN' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    $gribftpsite1 = 'http://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'GFS';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/gfs/prod";
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
    #### IF PREVIOUS ("negative") DAY NEEDED, USE $gribftpdirectory[2]
  }
  elsif ( $GRIBFILE_MODEL eq 'GFSA' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    $gribftpsite1 = 'http://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'GFSA';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/gfs/prod";
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
  }
  elsif ( $GRIBFILE_MODEL eq 'AVN' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    $gribftpsite1 = 'http://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'AVN';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/gfs/prod";
    ### at present only need single directory for eta since no "minus" times used
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
    #### IF PREVIOUS ("negative") DAY NEEDED, USE $gribftpdirectory[2]
  }
  elsif ( $GRIBFILE_MODEL eq 'RUCH' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    $gribftpsite1 = 'gsdftp.fsl.noaa.gov';
    $gribftpsiteid1 = 'FSL';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "13kmruc/maps_fcst20";
    ### at present only need single directory for eta since no "minus" times used
    #### NEVER NEED PREVIOUS ("negative") DAY SINCE ALL IN ONE DIRECTORY
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    ### even though FSL DIRECTORY STRUCTURE *DOESNT* DEPEND ON INITIALIZATION TIME, UNLIKE NWS 
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
  }
  #####################  END OF FTP PARAMETER SETUP  ####################
}
#####################################################################################################
#####################################################################################################
sub do_aging ()
### "AGE" LATEST MAPS TO PREVIOUS DAY AND REMOVE FIRST,LAST MAPS
{
  ### AGE DEGRIB DIRS 
  $ivalidday = -1;
  foreach $dummyvalidday (@validdaylist)
  {
    ### need upper case for directory name 
    ### !!! need to isolate validday to avoid upper-case affecting @validdaylist !!!  PERL BUG !!!
    $validday = $dummyvalidday;
    $validday =~ tr/a-z/A-Z/;
    ### get previous valid day
    $ivalidday++;
    if( $ivalidday == 0 ) 
      {
         $newvalidday = "PREVIOUS.";
      }
    else
      { ( $newvalidday = $validdaylist[$ivalidday-1] ) =~ tr/a-z/A-Z/ ; }
    ### loop over valid.times 
    foreach $validtime (@blipmapvalidtimelist)
    {  
      ### move directory
      if ( -d "${DEGRIBBASEDIR}/${validday}${validtime}Z" )
      {
        `rm -fr ${DEGRIBBASEDIR}/${newvalidday}${validtime}Z ; mv ${DEGRIBBASEDIR}/${validday}${validtime}Z ${DEGRIBBASEDIR}/${newvalidday}${validtime}Z`;
print STDOUT "AGING DEGRIB SUBDIR ${validday}${validtime}Z TO ${newvalidday}${validtime}Z \n";
      }
    }
  }
  ### do this for all possible days
  my $dummy = 0;
  for ( $i=0; $i<=$#validdaylist; $i++ )
  {
    ### create "not available" PNG/TXT containing date though don't expect all to be needed
    if ( ${validdaylist[$i]} ne '' )
      {
      ### previousday blipspot for eta not used, but put in to keep parallelism with blipmap 
      jchomp( $availableout = `$UTILDIR/no_blipspot_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}} ; cd $OUTDIR ; mv -f no_blipspot_available.txt no_blipspot_available.${validdaylist[$i]}txt 2>/dev/null` );
      jchomp( $availableout = `$UTILDIR/no_blipmap_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}} ; cd $OUTDIR ; mv -f no_blipmap_available.png no_blipmap_available.${validdaylist[$i]}png 2>/dev/null` );
      }
     else
      {
      jchomp( $availableout = `$UTILDIR/no_blipspot_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}}` );
      jchomp( $availableout = `$UTILDIR/no_blipmap_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}}` );
      }
    ### create PNG containing month/day/dow
    jchomp( my $getdowpng = `cd $OUTDIR ; $UTILDIR/plt_chars.pl $validdow{${validdaylist[$i]}} ; mv -f plt_chars.png dow.${validdaylist[$i]}${dow_localid}.png  2>/dev/null` );
    jchomp( my $getmonpng = `cd $OUTDIR ; $UTILDIR/plt_chars.pl $validmon{${validdaylist[$i]}} ; mv -f plt_chars.png mon.${validdaylist[$i]}${mon_localid}.png  2>/dev/null` );
    jchomp( my $getda1png = `cd $OUTDIR ; $UTILDIR/plt_chars.pl $validda1{${validdaylist[$i]}} ; mv -f plt_chars.png day.${validdaylist[$i]}${day_localid}.png  2>/dev/null` );
  }
  foreach $regionkey (@REGION_DOLIST)
  {
    if( ! defined( $firstofday{$regionkey} ) )
    {
      $firstofday{$regionkey} = 1;
      ### must loop over all validation times, with ftp for each
      ### use timeout limit as once hung here
      `rm -f $OUTDIR/${regionkey}/blipmap.cp2previousday.out`;
      $ltimelimiterr = &timelimitexec ( $previousdayftptimeoutsec, "\$previousdayout = `cd $OUTDIR ; $UTILDIR/blipmap.cp2previousday $GRIBFILE_MODEL/$regionkey @validdaylist @{$blipmapvalidtimes{$regionkey}} >  ${regionkey}/blipmap.cp2previousday.out 2>&1`;" );
      if ( $ltimelimiterr ne '' )
      {
        &write_err( "*WARNING* $regionkey BLIPMAP PREVIOUS DAY TIMEOUT
          MIGHT HAVE HUNG FTP JOB - see printout ps list" );
        jchomp( $ftppslist = `ps -f -u $USERNAME | grep "ftp -n -i drjack.info" | grep -v 'grep'` ); 
        print $PRINTFH "          ftp2previousday FTP previousdayout= $previousdayout & PS LIST for job $$ = \n $ftppslist \n";
      }
      if ( $previousdayout ne "" ) 
      {
        &write_err( " *** ERROR: $program BLIPMAP PREVIOUS DAY FTP for $regionkey
        previousdayout= $previousdayout" );
      } 
      if ($LPRINT>1) {print $PRINTFH ("CLEARED BLIPMAPs, created previous day files for $regionkey\n");}
    }
  }    
}
#####################################################################################################
#####################################################################################################
sub do_getgrib_selection ()
### GET GRIB ALA LGETGRIB
{
  ### set initial gribftpsite to avoid error if lgetgrib=0
  $gribftpsite = '';
  $gribftpsiteid = $GRIBFILE_MODEL . '-noftp';
  ### START OF IF FOR LGETGRIB>1
  if( $LGETGRIB > 1 )
  {
    ### START OF LGETGRIB=2 FILE DETERMINATION SECTION (using scheduled times)
    if( $LGETGRIB == 2 )
    {
      ### AT PRESENT ONLY USE FIRST FTP STIE FOR SCHEDULED ACCESS
      $gribftpsite = $gribftpsite1;
      $gribftpsiteid = $gribftpsiteid1;
      ### can't know gribfilesize at this point
      $remotegribfilesize = '';
      ### SET PRESENT HOUR TO MATCH TO AVAILABILTY HOUR
      $zhhmm = `date -u +%H:%M` ; jchomp $zhhmm;
      $zhour = &hhmm2hour( $zhhmm );
      ### allow model to run into following zulu day
      $zjday = `date -u +%j` ; jchomp($zjday);
      if ( $zjday > $julianday )
      { $zhour = $zhour + 24 };
      if ( $filename ne '' ) {$lastcyclesleep = 0; }
      else                   {$lastcyclesleep = 1; }
      $filename = '';
      $last_available_grib = '';
      $lalldone = 1;
      ### START OF LOOP OVER POSSIBLE ATTEMPTS
### SCHEDULED GRIBGET FILESTATUS MEANINGS
      for ( $iattempt=1; $iattempt<=$max_schedgrib_attempts; $iattempt++ )
      {
        $ifiledolistindex = -1; 
        FILESEARCH: foreach $file (@filenamedolist)
        {
           ### FILE is grib filename
           ### IFILE is file index string (eg 21Z+6) in filedolist
           $ifiledolistindex = $ifiledolistindex + 1; 
           $ifile = $filedolist[$ifiledolistindex];
           ### if this filestatus too high for this attempt loop, skip it
           if ( $filestatus{$ifile} <= $max_schedgrib_attempts )
             { $lalldone = 0 ; }
           if ( $filestatus{$ifile} > ($iattempt-1) )
             { next FILESEARCH; }
           ### START OF NEW SKIP OF OLDER VALID TIME CASE
           ### don't process fcst time if shorter term one already done for this valid time
           ### dont skip for test mode since normal ordering then gives mostly skips!
           ### changed to fileextendedvalidtime for eta
           if ( $filefcsttimes{$ifile} > $latestfcsttime[$fileextendedvalidtimes{$ifile}] && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
           {
             if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER FILESEARCH $ifile - previous $filevalidtimes{$ifile}Z validation time (extended=${fileextendedvalidtimes{$ifile}}) had shorter fcst time = $latestfcsttime[$fileextendedvalidtime]\n" );}
             ### setting this status will caused file to be ignored later
             $filestatus{$ifile} = $status_skipped; 
             $oldtimescount++;
             next FILESEARCH;
           }
           ### END OF NEW SKIP OF OLDER VALID TIME CASE
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
           ### DON'T PROCESS IF PREVIOUSLY STARTED FTP FOR SAME VALID TIME HAS SHORTER FCST TIME
           ### (this allows a restart at "non-normal" times without creating unneccessary ftps of longer forecast period files)
           if ( defined $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} && $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} < $filefcsttimes{$ifile} && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
           {
             if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER START FILESEARCH $ifile - previously started $filevaliddays{$ifile} $filevalidtimes{$ifile}Z validation time had shorter fcst time = $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}}\n" );}
             ### setting this status will caused file to be ignored later
             $filestatus{$ifile} = $status_skipped; 
             $oldtimescount++;
             next FILESEARCH;
           }
           ### if reach this point, there must be more files needing processing
           $lalldone = 0;
           ### IF HR>AVAIL SET STATUS
           if ( $iattempt==1 && $gribavailhrz{$ifile} < $zhour )
           {
             $filestatus{$ifile} = 0; 
             ### append to file for later examination of "first available" times
             $gribavailhhmm = &hour2hhmm( $gribavailhrz{$ifile} ) ;
            `echo "--- $rundayprt $cycletime - GETGRIB first scheduled for ${gribavailhhmm}Z" >> ${GRIBFILE_MODELDIR}/gribftpget.notavailable.${ifile}`;
           }
           ### IF THIS FILE AVAILABLE, EXIT LOOP WITH FILENAME
           if ( $filestatus{$ifile} == ($iattempt-1) )
           {
             if ( $LPRINT>1 && $lastcyclesleep == 0 ) {printf $PRINTFH ("SCHEDULED GETGRIB: %d trialfile = %7s (%d) => %s %s\n",$iattempt,$ifile,$filestatus{$ifile},$gribftpdirectory[$filenamedirectoryno{$ifile}],$file);}
             $filename = $file;
             ### PARTIAL SPECIFICATION OF MODEL GRIB FILENAME HERE
             ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so must set $gribftpdirectory[1] in routine do_getgrib_selection
             ### DAY/HR SELECTION - this depends upon analysis (initialization) time of file
             ###  ASSUMES THAT WILL NEVER ASK FOR FILE WITH INIT(ANAL) TIME BEYOND CURRENT JULIAN DAY !
             ###  if not, add test based on day of init(anal) time
             if ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
             {     
               $gribftpdirectory[1] = sprintf 'MT.nam_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4,$jmo2,$jda2);
               $gribftpdirectory[2] = sprintf 'MT.nam_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4m1,$jmo2m1,$jda2m1);
               $gribftpdirectory[3] = sprintf 'MT.nam_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4p1,$jmo2p1,$jda2p1);
             }
             elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' )
             {
               $gribftpdirectory[1] = sprintf 'MT.gfs_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4,$jmo2,$jda2);
               $gribftpdirectory[2] = sprintf 'MT.gfs_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4m1,$jmo2m1,$jda2m1);
               $gribftpdirectory[3] = sprintf 'MT.gfs_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4p1,$jmo2p1,$jda2p1);
             }
             elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' )
             {
               print $PRINTFH "ERROR STOP: Limited Area GFSA grib file available only on NCEP server"; 
               exit 1;
             }
             elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' )
             {
               print $PRINTFH "ERROR STOP: truncated AVN grib file available only on NCEP server"; 
               exit 1;
             }
             elsif ( $gribftpsite eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'RUCH' )
             {
               $gribftpdirectory[1] = "";
               $gribftpdirectory[2] = "";
               $gribftpdirectory[3] = "";
             }
             elsif ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
             {     
               $gribftpdirectory[1] = sprintf 'nam.%04d%02d%02d',$jyr4,$jmo2,$jda2;
               $gribftpdirectory[2] = sprintf 'nam.%04d%02d%02d',$jyr4m1,$jmo2m1,$jda2m1;
               $gribftpdirectory[3] = sprintf 'nam.%04d%02d%02d',$jyr4p1,$jmo2p1,$jda2p1;
             }
	     elsif ( $gribftpsite eq 'nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
             {     
               $gribftpdirectory[1] = sprintf 'nam.%04d%02d%02d',$jyr4,$jmo2,$jda2;
               $gribftpdirectory[2] = sprintf 'nam.%04d%02d%02d',$jyr4m1,$jmo2m1,$jda2m1;
               $gribftpdirectory[3] = sprintf 'nam.%04d%02d%02d',$jyr4p1,$jmo2p1,$jda2p1;
             }  
             elsif ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' || $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' ||  $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' )
             {
               $gribftpdirectory[1] = sprintf 'gfs.%04d%02d%02d%02d',$jyr4,$jmo2,$jda2,$fileanaltimes{$ifile};
               $gribftpdirectory[0] = sprintf 'gfs.%04d%02d%02d%02d',$jyr4m1,$jmo2m1,$jda2m1,$fileanaltimes{$ifile};
               $gribftpdirectory[2] = sprintf 'gfs.%04d%02d%02d%02d',$jyr4p1,$jmo2p1,$jda2p1,$fileanaltimes{$ifile};
             }
             $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
             $filename{$ifile} = $file;
             $filenamedirectory{$ifile} = $gribftpdirectory[$filenamedirectoryno{$ifile}];
             ### increment filestatus so indicates number of attempts
             $filestatus{$ifile}++ ;
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
             $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} = $filefcsttimes{$ifile} ;
             $last_available_grib = $file;
             goto GETTHISGRIBFILE;
           }
        }  
      } 
      ### END OF LOOP OVER POSSIBLE ATTEMPTS
    }
    ### END OF LGETGRIB=2 FILE DETERMINATION SECTION
    ### START OF LGETGRIB=1 FILE DETERMINATION SECTION (using ls files)
    elsif( $LGETGRIB == 3 )
    {
       ### CREATE FTP LS LIST
       ### use subroutine to ftp ls list - with timeout enabled to recover from hung ftp
       ### FIRST TRY FIRST FTP STIE
       $gribftpsite = $gribftpsite1;
       $gribftpsiteid = $gribftpsiteid1;
       `rm -f $LSOUTFILE1`;
       `rm -f $LSOUTFILE2`;
       `rm -f $LSOUTFILEERR`;
   ### RHES3.0 PERL 5.8.0 timeout failure here seems to produce additional LFs thereafter (due to eval's in routine?)
        $ltimelimiterr = &timelimitexec ( $lsgetftptimeoutsec, '&gribftpls( $gribftpsite, $gribftpdirectory0, $gribftpdirectory[1], $gribftpdirectory[2] );' );
       ### errout messages: "Connection timed out" "Unknown Host"
       ### stdout messages: "Not connected"
       ### below combines parts of above 3 messages
       jchomp( $lconnecterr = `grep -c '[oUuNn][nno][ kt][tn ][ioc][mwo][enn][d n][ Hhe][ooc][ust][tte]' $LSOUTFILEERR` );
       ### test that lsoutfile1 was produced
       $lsoutfilesize = -s $LSOUTFILE1 ;
       if ( ! defined $lsoutfilesize ) { $lsoutfilesize = -1; }
       ### treat ftp failure condition
       if ( $ltimelimiterr ne '' || $lconnecterr > 0 || $lsoutfilesize <= 0 )
       {
         print $PRINTFH "FTP1 LS FAILURE:  $ltimelimiterr $lconnecterr $lsoutfilesize to $gribftpsite1\n";
         jchomp( $ftppslist = `ps -f -u $USERNAME | grep "ftp -i -n $gribftpsite" | grep -v 'grep'` ); 
         if ( $ftppslist ne '' )
         {
           print $PRINTFH "                  PS LIST= \n $ftppslist \n";
           jchomp( $runningps=`echo "$ftppslist" | sort -n | sed -n 1p` );
           $runningpid = substr( $runningps, 8,6 );
           jchomp( my $killout=`(kill -9 $runningpid 2>&1) 2>&1` );
           print $PRINTFH "     Job $$ killed $runningps $killout\n";
         }
         if ( $gribftpsite2 ne '' )
         {
           if ($LPRINT>1) { print $PRINTFH ("TRY FTP#2 to $gribftpsite2\n"); }
           `rm -f $LSOUTFILE1`;
           `rm -f $LSOUTFILE2`;
           `rm -f $LSOUTFILEERR`;
           $gribftpsite = $gribftpsite2;
           $gribftpsiteid = $gribftpsiteid2;
           $ltimelimiterr = &timelimitexec ( $lsgetftptimeoutsec, '&gribftpls($gribftpsite, $gribftpdirectory0, $gribftpdirectory[1], $gribftpdirectory[2]);' );
           jchomp( $lconnecterr = `grep -c '[oUuNn][nno][ kt][tn ][ioc][mwo][enn][d n][ Hhe][ooc][ust][tte]' $LSOUTFILEERR` );
           ### test that lsoutfile1 was produced
           $lsoutfilesize = -s $LSOUTFILE1 ;
           if ( ! defined $lsoutfilesize ) { $lsoutfilesize = -1; }
           ### treat ftp failure condition
           if ( $lconnecterr > 0 || $ltimelimiterr ne '' || $lsoutfilesize <= 0 )
           {
             print $PRINTFH "FTP#2 LS FAILURE:  $ltimelimiterr $lconnecterr $lsoutfilesize to $gribftpsite1\n";
             jchomp( $ftppslist = `ps -f -u $USERNAME | grep "ftp -i -n $gribftpsite" | grep -v 'grep'` ); 
             if ( $ftppslist ne '' )
             {
               print $PRINTFH "                  PS LIST= \n $ftppslist \n";
               jchomp( $runningps=`echo "$ftppslist" | sort -n | sed -n 1p` );
               $runningpid = substr( $runningps, 8,6 );
               jchomp( my $killout=`(kill -9 $runningpid 2>&1) 2>&1` );
               print $PRINTFH "     Job $$ killed $runningps $killout\n";
             }
             print $PRINTFH "MUST START NEW CYCLE due to ftp failures - SLEEP $cycle_waitsec sec\n";
             ### sleep to prevent immediate re-cycle 
             sleep $cycle_waitsec;
             $totsleepsec += $cycle_waitsec;
             goto STRANGE_CYCLE_END;
           }
         }
         else
         {      
            ### sleep to prevent immediate re-cycle 
             print $PRINTFH "START NEW CYCLE AFTER SLEEP $cycle_waitsec sec\n";
             sleep $cycle_waitsec;
             $totsleepsec += $cycle_waitsec;
             goto STRANGE_CYCLE_END;
         }
         `echo "$startdate $cycletime  $gribftpsite LS_FTP1_FAILURE $lconnecterr $ltimelimiterr $lsoutfilesize" >> $RUNDIR/ftp1.log`;
           print $PRINTFH "MUST START NEW CYCLE due to ftp failure \n";
       }
       else
       {
         `echo "$startdate $cycletime  $gribftpsite LS_FTP1_OK" >> "$RUNDIR/ftp1.log"`;
       }
       if (! defined( $lsoutstdout ) )
       {
          ### sleep to prevent immediate re-cycle 
          print $PRINTFH "MISSING LSOUTSTDOUT - CONTINUE AFTER SLEEP OF $cycle_waitsec sec\n";
          sleep $cycle_waitsec;
          $totsleepsec += $cycle_waitsec;
          goto STRANGE_CYCLE_END;
       }
       ### GET LS OUTPUT
       jchomp( $lsout1 = `cat $LSOUTFILE1` );
       @lslist1 = split( /\n/, $lsout1 );
       if( $gribftpdirectory[2] ne '' && -s $LSOUTFILE2 )
         {
         jchomp( $lsout2 = `cat $LSOUTFILE2` );
         @lslist2 = split( /\n/, $lsout2 );
         }
       ### search for an available unprocessed filename
       $ifiledolistindex = -1; 
       if ( $filename ne '' ) {$lastcyclesleep = 0; }
       else                   {$lastcyclesleep = 1; }
       FILESEARCH: foreach $file (@filenamedolist)
       {
          ### FILE is grib filename
          ### IFILE is file index string (eg 21Z+6) in filedolist
          $ifiledolistindex = $ifiledolistindex + 1; 
          $ifile = $filedolist[$ifiledolistindex];
          if ( $filestatus{$ifile} < 1 )
          {
            ### START OF NEW SKIP OF OLDER VALID TIME CASE
            ### don't process fcst time if shorter term one already done for this valid time
            ### dont skip for test mode since normal ordering then gives mostly skips!
            ### changed to fileextendedvalidtime for eta
            if ( $filefcsttimes{$ifile} > $latestfcsttime[$fileextendedvalidtimes{$ifile}] && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
            {
              if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER $file - previous $filevalidtimes{$ifile}Z validation time (extended=${fileextendedvalidtimes{$ifile}}) had shorter fcst time = $latestfcsttime[$fileextendedvalidtime]\n" );}
              ### set successfultimeend id
              $oldtimescount++;
              ### setting this status will caused file to be ignored later
              $filestatus{$ifile} = $status_skipped; 
              next FILESEARCH;
            }
            ### END OF NEW SKIP OF OLDER VALID TIME CASE
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
           ### DON'T PROCESS IF PREVIOUSLY STARTED FTP FOR SAME VALID TIME HAS SHORTER FCST TIME
           ### (this allows a restart at "non-normal" times without creating unneccessary ftps of longer forecast period files)
           if ( defined $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} && $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} < $filefcsttimes{$ifile} && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
           {
             if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER START FILESEARCH $ifile - previously started $filevaliddays{$ifile} $filevalidtimes{$ifile}Z validation time had shorter fcst time = $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}}\n" );}
             ### setting this status will caused file to be ignored later
             $filestatus{$ifile} = $status_skipped; 
             $oldtimescount++;
             next FILESEARCH;
           }
            ### if reach this point, there must be more files needing processing
            $lalldone = 0;
            if ( $LPRINT>1 && $lastcyclesleep == 0 ) {printf $PRINTFH ("FTP-LS GETGRIB: trial file = %7s (%d) => %s %s\n",$ifile,$filestatus{$ifile},$gribftpdirectory[$filenamedirectoryno{$ifile}],$file);}
            ### choose correct directory
            if ( $ifile =~ /^ *-/ ||  $gribftpdirectory[2] eq '' )
              { @lslist = @lslist1; }
            else
              { @lslist = @lslist2; }
            for ( $ii=0; $ii <= $#lslist; $ii++ )
            {
              ### added filesize test to avoid getting truncated files
              if ( $lslist[$ii] =~ m/$file/  )
              {
                if( $gribftpsite eq 'gsdftp.fsl.noaa.gov' || $gribftpsite eq 'eftp.fsl.noaa.gov' )
                  { $remotegribfilesize = (split(/  */,$lslist[$ii],6))[4]; }
                elsif( $gribftpsite eq 'http://nomads.ncep.noaa.gov' )
                  {
                    $remotegribfilesize = (split(/  */,$lslist[$ii],6))[4];
                  }
                elsif( $gribftpsite eq 'narf.fsl.noaa.gov' )
                  { $remotegribfilesize = (split(/  */,$lslist[$ii],6))[3]; }
                else
                  { print $PRINTFH "BAD gribftpsite= $gribftpsite "; exit 1; }
                if ( defined $remotegribfilesize )  
                {
                  if ( $remotegribfilesize >= $mingribfilesize )  
                  {
                    ### not-yet-proceessed file found
                    $filename = $file ;
                    $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
                    $filestatus{$ifile} = 1 ;
                    $filename{$ifile} = $file;
                    $filenamedirectory{$ifile} = $gribftpdirectory[$filenamedirectoryno{$ifile}];
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
                    $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} = $filefcsttimes{$ifile} ;
                    last FILESEARCH; 
                  }
                  else
                  {
                  if ( $LPRINT>1 && $lastcyclesleep == 0 ) {print $PRINTFH ("      ( grib file too small: $remotegribfilesize < $mingribfilesize )\n");}
                  }
                }
                else
                {
                  $remotegribfilesize = '';
                }
              }
            }
          }      
          $filename = '';
       }  
    }
    ### END OF LGETGRIB=3 FILE DETERMINATION SECTION 
    GETTHISGRIBFILE:
    ### TREAT NO FILENAME CASES => processing done or no available file
    if ( $lalldone == 1 )
    {
      ###  file processing done
      print $PRINTFH ("PRE-CALC CYCLE EXIT: FILE SELECTION FINDS ALL FILES PROCESSED\n");    
      &final_processing;
    }
    elsif ( $filename eq '' )
    { 
      ###  SLEEP then continue cycle loop
      print $PRINTFH "   PAUSE CYCLE LOOP FOR $cycle_waitsec sec\n";
      sleep $cycle_waitsec;
      $totsleepsec += $cycle_waitsec;
      goto NEWGRIBTEST;
    }
  ### END OF IF FOR LGETGRIB>1
  }
  ### TREAT GRIB FILE INPUT CASE
  elsif ( $LGETGRIB == -1 )
  {
    ### TREAT GRIB FILE INPUT CASE
    $filename = $specifiedfilename ;
    ### extract ifile from grib file name
    ### for NWS ETA filename
    if ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m|fh.(00[0-9][0-9])_tl.press_gr.awip3d$| )
    {
      ### set initialization time since not apparent from filename
      if    ( $1==18 || $1==21 || $1==42 || $1==45 || $1==66 || $1==69 )
        { $ifile = "0Z+${1}"; }
      elsif ( $1==12 || $1==15 || $1==36 || $1==39 || $1==60 || $1==63 )
        { $ifile = "6Z+${1}"; }
      elsif ( $1==6  || $1==9  || $1==30 || $1==33 || $1==54 || $1==57 )
        { $ifile = "12Z+${1}"; }
      elsif ( $1==24 || $1==27 || $1==48 || $1==51 || $1==72 || $1==75 )
        { $ifile = "18Z+${1}" }
      else
        { $ifile = "99Z+${1}"; }
    }
    ### for NWS GFS filename
    elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m|fh.(00[0-9][0-9])_tl.press_gr.onedeg$| )
    {
      ### set initialization time since not apparent from filename
      if    ( $1==18 || $1==21 || $1==42 || $1==45 || $1==66 || $1==69 )
        { $ifile = "0Z+${1}"; }
      elsif ( $1==12 || $1==15 || $1==36 || $1==39 || $1==60 || $1==63 )
        { $ifile = "6Z+${1}"; }
      elsif ( $1==6  || $1==9  || $1==30 || $1==33 || $1==54 || $1==57 )
        { $ifile = "12Z+${1}"; }
      elsif ( $1==24 || $1==27 || $1==48 || $1==51 || $1==72 || $1==75 )
        { $ifile = "18Z+${1}" }
      else
        { $ifile = "99Z+${1}"; }
    }
   ### for FSL filename
    elsif ( $gribftpsite eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'RUCH' && $filename =~ m|^0....([0-9][0-9])....([0-9][0-9])\.grib$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m|^nam\.t([0-9][0-9])z\.awip3d([0-9][0-9])\.tm00.grib2$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' && $filename =~ m|^gfs\.t([0-9][0-9])z\.pgrb2f([0-9][0-9])$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' && $filename =~ m|^gfs\.t([0-9][0-9])z\.pgrbf([0-9][0-9])$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m|^gfs\.t([0-9][0-9])z\.pgrbf([0-9][0-9])$| )
    {
      $ifile = "${1}Z+${2}";
    }
    else
    {
      print $PRINTFH (" LGETGRIB=-1 CYCLE EXIT: ifile not extracted \n");    
      &final_processing;
    }
    $ifile =~ s/^0([0-9])/$1/;
    $ifile =~ s/\+0/+/;
    ### test for valid ifile
    ($ifilegreptest = $ifile ) =~ s/\+/\\\+/g;
    if(  grep ( m/^${ifilegreptest}$/, @filedolist ) == 0 )
      {
      print $PRINTFH (" LGETGRIB=-1 CYCLE EXIT: invalid ifile = $ifile \n");    
      &final_processing;
      }
    ### test for file existence
    if( ! -f "${GRIBDIR}/${filename}" )
      {
      print $PRINTFH (" LGETGRIB=-1 CYCLE EXIT: specified grib file $filename NOT FOUND\n");    
      &final_processing;
      }
    $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
    print $PRINTFH ("*EXISTING*GRIB*FILE* run with *NO*GETGRIB*\n");
    push @childftplist, $ifile;
    $filename{$ifile} = $filename;
    $filenamedirectory{$ifile} = '*EXISTING*GRIB*';
  }
  else
  {
    ### TREAT CASE WITHOUT GET-GRIB
    $filename = $filenamedolist[$icycle-1];
    $ifile = $filedolist[$icycle-1]; 
    if( ! defined($ifile) )
      {
      print $PRINTFH (" LGETGRIB=0 CYCLE EXIT: undefined ifile \n");    
      &final_processing;
      }
    $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
    ### i dont understand logic behind following and interferes with xi test runs so hvae commented this out
    print $PRINTFH ("*TEST*MODE* run with *NO*GETGRIB*\n");
    push @childftplist, $ifile;
    $filename{$ifile} = $filename;
    $filenamedirectory{$ifile} = '*NO*GETGRIB*';
  }
}
#################################################################################################
#################################################################################################
sub signal_endcycle()
####### INTERRUPT (Ctrl-C) WILL END CYCLE AND SKIP TO END PROCESSING #######
### MAKE SURE TO SEND "kill -2" TO PERL SCRIPT NOT TO SHELL ! 
{ 
  print "CYCLE TERMINATED by SIGNAL 2 (Ctrl-C)\n";
  if ($LPRINT>1) { print $PRINTFH "CYCLE TERMINATED by SIGNAL 2 (Ctrl-C)\n";}
  &final_processing;
}
#########################################################################
#########################################################################
sub final_processing ()
### FINALPROCESSING put into subroutine so can use with interrput signal
{
  print $PRINTFH "FINALPROCESSING-TESTING finalprocessing0 $LSAVE \n";
  ### CLOSE THREAD TIME SUMMARY FILES
  foreach $regionkey (@REGION_DOLIST)
  {    
    if ( defined $SUMMARYFH{$regionkey} )
    {
      close  ( $SUMMARYFH{$regionkey} ) ;
    }    
  }
  ### KILL ANY EXISTING CHILD MODEL RUN PROCESSES
  foreach $childrunmodelpid (@childrunmodellist)
  {
    ### value of -1 indicates that child already exited
    if(  $childrunmodelpid > 0 )
    {
      my $killout = &kill_pstree( $childrunmodelpid );
      if ($LPRINT>1) { print $PRINTFH ("FINAL PROCESSING KILL OF CHILD RUNMODEL PS TREE: $childrunmodelpid => $killout \n"); }
    }
  }
  foreach $ifile (@childftplist)
  {
    $childftppid = $childftppid{$ifile};
    my $killout = &kill_pstree( $childftppid );
    if ($LPRINT>1) { print $PRINTFH ("FINAL PROCESSING KILL OF CHILD gribftpget PS TREE: $childftppid => $killout \n"); }
  }
  ### KILL EXISTING wrf.exe PROCESSES with argument $JOBARG
  jchomp( $wrfexejobpids = `ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID}" | grep "$USERNAME .*wrf.exe ${JOBARG}:" | tr -s ' ' | cut -f2 -d' ' | tr '\n' ' '` );
  if ( $wrfexejobpids !~ m|^\s*$| )
  {
    if ($LPRINT>1) { print $PRINTFH "*** !!! FINAL PROCESSING KILL OF RUNNING wrf.exe $JOBARG PROCESSES: $wrfexejobpids \n"; }
    ### send stderr to stdout as once tried to kill non-existent job
    jchomp( my $killout = `kill -9 $wrfexejobpids 2>&1` );
  }
  if ( $#childrunmodellist > -1 || $#childftplist > -1 ) { sleep 30; }
  ### MAKE DOUBLY SURE THAT ANY LEFT-OVER CURL JOBS ARE KILLED
  ### be sure to eliminate present job !
  jchomp( $previousjobpids = `ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID}" | grep "$USERNAME .* $BASEDIR/UTIL/curl .*${JOBARG}" | tr -s ' ' | cut -f2 -d' ' | tr '\n' ' '` );
  if ( $previousjobpids !~ m|^\s*$| )
  {
    if ($LPRINT>1) { print $PRINTFH "*** !!! UNEXPECTED CURL PROCESSES FOUND SO WILL BE KILLED !!!  PID= $previousjobpids \n"; }
    ### send stderr to stdout as once tried to kill non-existent job
    jchomp( my $killout = `kill -9 $previousjobpids 2>&1` );
  }
  $time = `date +%H:%M:%S` ; jchomp($time);
  #####  PRINT UNANALYZED TIMES
  if ( $lalldone==0 && $LPRINT>1 )
  {
    print $PRINTFH ("UN-PROCESSED TIMES AT FINAL PROCESSING:\n");
    $ifiledolistindex = -1; 
    foreach $file (@filenamedolist)
    {
      ### ifile is file index number in filedolist
      $ifiledolistindex = $ifiledolistindex + 1; 
      $ifile = $filedolist[$ifiledolistindex];
      if ( $filestatus{$ifile} < $status_problem )
      {
        print $PRINTFH ("    $ifile \n");
      }      
    }      
    print $PRINTFH ("PROCESSED BUT UNSUCCESFUL TIMES AT FINAL PROCESSING:\n");
    $ifiledolistindex = -1; 
    foreach $file (@filenamedolist)
    {
      ### ifile is file index number in filedolist
      $ifiledolistindex = $ifiledolistindex + 1; 
      $ifile = $filedolist[$ifiledolistindex];
      if ( $filestatus{$ifile} >= $status_problem && $filestatus{$ifile} < $status_skipped )
      {
        print $PRINTFH ("    $ifile \n");
      }      
    }      
  }      
  ### GET SCRIPT END TIME
  $endtime = `date +%H:%M` ; jchomp($endtime);
  $elapsed_runhrs = sprintf("%4.1f",$elapsed_runhrs);
  if ($LPRINT>1) {print $PRINTFH "$endtime : END $program for $JOBARG & ${RUNTYPE} on $rundayprt : process $$ (runhr=${elapsed_runhrs}/${cycle_max_runhrs} cycle=${icycle}/${cycle_max} files=${foundfilecount}/${dofilecount})\n";}
  exit;
}
#########################################################################
#########################################################################
sub gribftpls ()
### subroutine gribftpls - gets ls info from server
### $FTPDIRECTORY2 is optional
{
  my ($FTPSITE,$FTPDIRECTORY0,$FTPDIRECTORY1,$FTPDIRECTORY2) = @_;
  ### SET LSFTPMETHOD
  ### curl uses timeout to prevent unkilled ftp processes, can also be verbose
  ###      (and might later use other features, such as filename-only-list, macros, etc)
  my $LSFTPMETHOD = 'CURL';
  my ( $ID );
  if ( $FTPSITE eq 'http://nomads.ncep.noaa.gov' )
  {
    $ID = "anonymous $ADMIN_EMAIL_ADDRESS";
  }
   elsif ( $FTPSITE eq 'http://nomads.ncep.noaa.gov' )
  {
    $ID = "anonymous $ADMIN_EMAIL_ADDRESS";
  }
    elsif ( $FTPSITE eq 'nomads.ncep.noaa.gov' )
  {
    $ID = "";
  } 
  elsif ( $FTPSITE eq 'gsdftp.fsl.noaa.gov' )
  {
    $ID = 'ftp glendening@drjack.net';
  }
  else
  { print $PRINTFH "*** ERROR EXIT in gribftpls: UNKNOWN SITE= $FTPSITE"; exit 1; }
  ### USE DIFFERENT CODE FOR DIFFERENT NO OF ARGUMENTS
  ### ASSUME FIRST FOR RUC AND 2ND FOR ETA
  if( $FTPDIRECTORY2 eq '' ) 
  {
  ### LS OF SINGLE DIRECTORIES TREATED HERE
    if( $LSFTPMETHOD eq 'FTP' )
    {
      jchomp( $lsoutstdout = `( 
      echo "user $ID";
    echo "debug";
      echo "ascii";
      echo "cd $FTPDIRECTORY0";
      echo "ls $FTPDIRECTORY1 $LSOUTFILE1";
      echo "bye";
      ) | ftp -i -n $FTPSITE  2> $LSOUTFILEERR` ); 
      ### NB ### NEED DIFFERENT FILESIZE STATEMENTS FOR narf VS spur !!! !!!
    }
    elsif( $LSFTPMETHOD eq 'CURL' )
    {
      $ID =~ s/ /:/; 
      jchomp( $lsoutstdout = `$BASEDIR/UTIL/curl -v -s --user $ID --max-time $lsgetftptimeoutsec --disable-epsv -o $LSOUTFILE1 "ftp://${FTPSITE}/${FTPDIRECTORY0}/${FTPDIRECTORY1}/" 2>$LSOUTFILEERR`);
    }
  }
  else
  {
  ### LS OF TWO DIRECTORIES TREATED HERE
    if( $LSFTPMETHOD eq 'FTP' )
    {
      jchomp( $lsoutstdout = `( 
      echo "user $ID";
    echo "debug";
      echo "ascii";
      echo "cd $FTPDIRECTORY0";
      ### ASSUME THIS IS FOR ETA - ls on filename to eliminate unwanted files
      echo "ls $FTPDIRECTORY1 $LSOUTFILE1";
      echo "ls $FTPDIRECTORY2 $LSOUTFILE2";
      echo "bye";
      ) | ftp -i -n $FTPSITE  2> $LSOUTFILEERR` ); 
    }
    elsif( $LSFTPMETHOD eq 'CURL' )
    {
      $ID =~ s/ /:/; 
      ### connect only once, listing 2 directorys to 2 different files - so must rename them afterward
      jchomp( $lsoutstdout = `$BASEDIR/UTIL/curl -v -s --user $ID --max-time $lsgetftptimeoutsec --disable-epsv -o "$GRIBFILE_MODELDIR/gribftpls.#1.list" "ftp://${FTPSITE}/${FTPDIRECTORY0}/{${FTPDIRECTORY1},${FTPDIRECTORY2}}/" 2>$LSOUTFILEERR`);
      `mv -f $GRIBFILE_MODELDIR/gribftpls.${FTPDIRECTORY1}.list $LSOUTFILE1 2>/dev/null ; mv -f $GRIBFILE_MODELDIR/gribftpls.${FTPDIRECTORY2}.list $LSOUTFILE2 2>/dev/null`
    }
  }
}
#########################################################################
#########################################################################
sub write_err ()
### write line to printout and also to stderr if printout is to file
{
  my $line = shift @_;
  print $PRINTFH ("$line \n");
  if ( $PRINTFH eq 'FILEPRINT' )
  { print STDERR ("$line \n"); }
}
#########################################################################
#########################################################################
sub strip_leading_zero ()
### subroutine strip_leading_zero
{
  my $string = shift @_;
  my $value;
  if ( substr( $string, 0,1 ) == 0 )
    { $value = substr( $string, 1); }
  else
    { $value = $string; }
  return $value;
}
#########################################################################
#########################################################################
sub repeating_printf ()  
### prints arrays with $nrepeats values per line using printf
### such that partial lines dont give "uninitialized value" message
###    more perl shit !!!
### $formatarg = format repeated to output entire array
### $nrepeats = no. of values printed per line
### @a = array to be printed
### $FH = filehandle
{
  ### initialization
  my ( $FH,$formatarg,$nrepeats, @a ) = @_;
  my ( $nvalues,$index,$index1,$index2,$i );
  $nvalues = $#a + 1;
  $index1 = 0;
  $format = '';
  ### first do setup
  if ( $nvalues < $nrepeats )
    ### treat case of less than $nrepeats array values 
    {
    $index2 = $#a;
    }
  else
    ### create format for normal "full" line
    { 
      for ($i=1; $i <= $nrepeats; $i++)
      {
        $format = "$format$formatarg";
      }
      $index2 = $nrepeats - 1;
    }
  ### now do printing
  while ( defined($a[$index1]) )
  {
    if ( $index2 < $#a )
    {
      ### print most lines here with $nrepeats values per line
      printf $FH "$format\n", @a[ $index1 .. $index2 ];
      $index2 = $index2 + $nrepeats;
    }
    else
   {
      ### print any final "partial" line here (and final "full" line if exact)
      $format = '';
      for ($index=$index1; $index <= $#a; $index++)
      {
        $format = "$format$formatarg";
      }
      printf $FH "$format\n", @a[ $index1 .. $#a ];
   }
    $index1 = $index1 + $nrepeats;
  }
}
#########################################################################
#########################################################################
sub hmstimediff ()
### TIMEDIFF compute difference between times ($starttime,$endtime)
### where $start,$end have format "hh:mm:ss" or "hh:mm"
### output difference given in choice of hrs/mins/secs
{
  my ( $starttime, $endtime ) = @_;
  ($hr1,$min1,$sec1) = split( /:/,$starttime );
  ($hr2,$min2,$sec2) = split( /:/,$endtime );
  ### allow hh:mm also
  if ( ! defined $sec1 ) { $sec1 = 0 ; }
  if ( ! defined $sec2 ) { $sec2 = 0 ; }
  $secs = int( 3600 * ( $hr2 - $hr1 ) + 60 * ( $min2 - $min1 ) + ( $sec2 - $sec1 ) );
  if ( $secs < 0 ) { $secs = $secs + 24*3600; }
  $mins = sprintf( "%5.1f",($secs/60) );
  $hrs = sprintf( "%5.1f",($secs/3600) );
  return $hrs,$mins,$secs;
}
#########################################################################
#########################################################################
### inverse sine
### inverse cosine
#########################################################################
#########################################################################
sub timelimitexec ()
### PUT TIME LIMIT ON SERIES OF COMMANDS
### RHES3.0 PERL 5.8.0 - extra lfs appear to result from one of these eval's when FTP1 message triggered
{   
  my ( $timelimitsec, $commands ) = @_;
  $SIG{'ALRM'} = sub { die 'timeout' };
    alarm($timelimitsec);      # set timeout prior to operations
    ### do "timeout enabled" operations here
    eval $commands ;
    $evalerrorinner = $@;
    alarm(0);                   # clear alarm when operations finished
  if ($evalerrorinner)              # check syntax error message from command eval 
  {
     if ($evalerrorinner =~ /timeout/)
     {
       ### process timed out so take appropriate action here
       return $evalerrorinner;
     }
     else
     {
      ### non-timeout errors like $commands syntax error reach here
      alarm(0);                 # clear the still-pending alarm
      print $PRINTFH "$program: timelimitexec eval inner ERROR = $evalerrorinner for $commands";    # to propagate unexpected error
      die "$program: timelimitexec eval inner ERROR = $evalerrorinner for $commands";    # to propagate unexpected error
    } 
  } 
  ### non-error return
  return '';
} 
########################################################################
########################################################################
sub print_download_speed ()
### PRINT FTP DOWNLOAD TIME AND SPEED
### ** NOW DIFFERS FROM ROUTINE IN gribftpget.pl (argument includes times) ***
{
  my ( $arg, $ftptime0, $time) = @_;
  $arg = sprintf "%s",$arg;
  my ( $remotegribfilesize,$localgribfilesize);
  ### now gets $localgribfilesize, $remotegribfilesize internally
  if ( -s "${GRIBFTPSTDERR}.${ifile}" )
  { 
    $remotegribfilesize = `grep 'Getting file with size:' "${GRIBFTPSTDERR}.${ifile}" | cut -d':' -f2`; jchomp($remotegribfilesize);
  }
  else
  {
    $remotegribfilesize = -1;
  }
  jchomp( $remotegribfilesize );
  if ( -s "${GRIBDIR}/${filename}" )
  { 
    ($dum,$dum,$dum,$dum,$dum,$dum,$dum,$localgribfilesize,$dum,$dum,$dum,$dum,$dum) = stat "$GRIBDIR/$filename";
  }
  else
  {
    $localgribfilesize = -1;
  }
  ### find download time
  my ($dummy,$ftpmins,$ftpsecs) = &hmstimediff( $ftptime0, $time );
  if ( $ftpsecs <= 0 )
  {
    print $PRINTFH "GRIB DOWNLOAD ERROR - 0 second download for GRIB ${arg} ${filenamedirectory}/${filename} at $ftptime0 PT\n";
    return -1;
  }    
  ### ADD server,port info from curl output
  $serverinfo = `grep 'Connecting to ' "${GRIBFTPSTDERR}.${ifile}" | cut -d' ' -f4,7` ; jchomp($serverinfo);
  $serverinfo =~ s/\.ncep\.noaa\.gov//;
  $serverinfo =~ s/\.nws\.noaa\.gov//;
  my $kbytespersec = sprintf( "%3.0f", (0.001*$localgribfilesize/$ftpsecs) );
  print $PRINTFH "GRIB ${arg} $ftptime0 - $time PT = ${ftpmins} min for ${filenamedirectory}/${filename}[${remotegribfilesize}] & ${localgribfilesize} b = $kbytespersec Kb/s  @ $serverinfo\n";
  ### log download speed:
  `echo "$rundayprt $ftptime0 - $time PT : $JOBARG $arg ${filenamedirectory}/${filename}=${remotegribfilesize}b = ${localgribfilesize}b / ${ftpmins}min = $kbytespersec Kb/s  @ $serverinfo" >> "$RUNDIR/grib_download_speed.log"`;
  ### LOG GRIB DOWNLOAD END
  $localgribfilesize = sprintf "%9s",$localgribfilesize;
  ### use file for two fields to match fields written by log_grib_download_size
  ( $hhmm = $time ) =~ s/:..$//;
  `echo "$arg  $rundayprt $hhmm $hhmm ${filename} ${localgribfilesize} = ${ftpmins} min  $kbytespersec Kb/s  @ $serverinfo" >> "$GRIBFILE_MODELDIR/download.log"`;
}
########################################################################
########################################################################
sub zulu2local ()
### CONVERT LOCAL TIME TO ZULU (if input includes : then output is colon-version)
{
  my $ztime = $_[0];
  ### SUBTRACT LOCAL - ZULU TIME TO GET HOUR DIFFERENCE
  my ( $time,$hourz,$tail, $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) ;
  ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = localtime(time);
  ( $sec,$min,$hourz,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = gmtime(time);
  $zuluhrdiff = $hour - $hourz ;
  ### DETERMINE IF HOUR OR HH:MM<:SS>
  if ( $ztime !~ m|:| )
  {
     $time = $ztime + $zuluhrdiff;
     if   ( $time > 24.0 ) { $time -= 24.0 ; }
     elsif ( $time < 0.0 ) { $time += 24.0 ; }
  }
  else
  {
     ( $hourz,$tail ) = split /:/,$ztime,2 ;
     $hourz =~ s/^0//;
     $hour = $hourz + $zuluhrdiff;
     if   ( $hour > 23 ) { $hour -= 24 ; }
     elsif ( $hour < 0 ) { $hour += 24 ; }
     $time = sprintf "%02d:%s", $hour,$tail;
  } 
  return $time;
} 
#########################################################################
#########################################################################
sub local2zulu ()
### CONVERT ZULU TIME TO LOCAL (if input includes : then output is colon-version)
{
  my $time = $_[0];
  ### SUBTRACT LOCAL - ZULU TIME TO GET HOUR DIFFERENCE
  my ( $timez,$hourz,,$tail, $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) ;
  ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = localtime(time);
  ( $sec,$min,$hourz,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = gmtime(time);
  $zuluhrdiff = $hour - $hourz ;
  ### DETERMINE IF HOUR OR HH:MM<:SS>
  if ( $time !~ m|:| )
  {
     $ztime = $time - $zuluhrdiff;
     if   ( $ztime > 24.0 ) { $ztime -= 24.0 ; }
     elsif ( $ztime < 0.0 ) { $ztime += 24.0 ; }
  }
  else
  {
     ( $hour,$tail ) = split /:/,$time,2 ;
     $hour =~ s/^0//;
     $hourz = $hour - $zuluhrdiff;
     if   ( $hourz > 23 ) { $hourz -= 24 ; }
     elsif ( $hourz < 0 ) { $hourz += 24 ; }
     $timez = sprintf "%02d:%s", $hourz,$tail;
  } 
  return $timez;
} 
#########################################################################
#########################################################################
sub hhmm2hour ()
### CONVERT INPUT hh:mm INTO DECIMAL HOUR
{
  my ($hh,$mm) = split ( /:/, $_[0] );
  my $decimalhour = $hh + $mm/60. ;
  return $decimalhour;
} 
#########################################################################
#########################################################################
sub hour2hhmm ()
### CONVERT INPUT DECIMAL hour INTO hh:mm
{
  ### to get integer mins, do for time + 30-sec
  my $hour = $_[0] +0.00833 ; 
  my $hh = int( $hour ); 
  my $mm = int(  ( $hour - $hh ) * 60 );
  my $hhmm = sprintf "%02d:%02d",$hh,$mm;
  return $hhmm;
} 
#########################################################################
#########################################################################
sub print_memory
### PRINT MEMORY INFO FOR TESTS
{
  jchomp( $statm = `cat /proc/$$/statm` ); 
  print $PRINTFH "STATM: @_ = $statm\n";
}
#########################################################################
#########################################################################
sub latest_ls_file_info ()
### FIND LATEST FILE IN ls -l OUTPUT LISTING
{
  my @data = @_;
  ### ignores year, returns last "latest" file in list if there are several
  my %pmon = ( 'Jan','0', 'Feb','1', 'Mar','2', 'Apr','3', 'May','4', 'Jun','5',
               'Jul','6', 'Aug','7', 'Sep','8', 'Oct','9', 'Nov','10', 'Dec','11' );
  my ( $latesttimestamp, $hr, $min, $timestamp, $fileinfo );
  $latesttimestamp = 0;
  my $yy = 100;
  my $ilatest = -1;
  for ( $i=0; $i<=$#data; $i++ )
  {
    ### skip over "total" line
    if ( $data[$i] =~ m/^ *total / ) { next; }
    my ($perm,$node,$uid,$pid,$size,$qmon,$day,$hhmm,$filename) = split ( /\s+/, $data[$i] );
    ($hr,$min) = split ( /:/, $hhmm );
    $timestamp = mktime( 0,$min,$hr,$day,$pmon{$qmon},$yy,0,0,0 );
    ### choice of "<=" will give last "latest" file in list
    ### (appropriate for ncep data listings when time is part of name)
    ### and only consider grib files of interest !
    if ( $latesttimestamp <= $timestamp && (
           ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m/\.press_gr\./ ) 
        || ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' && $filename =~ m/\.pgrbf\./ ) 
        || ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m/\.pgrbf\./ ) 
        || ( $gribftpsite eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'FSL' && $filename =~ m/\.grib$/ ) 
        || ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m/\.awip3dd/ ) 
        || ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' && $filename =~ m/\.pgrb2f/ ) 
        || ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' && $filename =~ m/\.pgrbf/ ) 
        || ( $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m/\.pgrbf/ ) 
       ) )
      {
        $ilatest = $i;
        $latesttimestamp = $timestamp;
      }
  }
  ### RETURN FILENAME + INFO
  if ( $ilatest > -1 )
    { ($dum,$dum,$dum,$dum,$dum,$fileinfo) = split(/\s+/,$data[$ilatest],6); }
  else
    { $fileinfo = "No 3d grib files found"; }
  jchomp( $fileinfo );
  return $fileinfo;
}
###########################################################################################
###########################################################################################
###########################################################################################
###########################################################################################
sub dayofweek
### Returns the NUMERICAL (0-6, 0=sunday) Day of the Week for any date between 1500 and 2699.
### >>> Month should be in the range 1..12 <<<  Year=yyyy (2 digit gives same result except for century)
### (extracted from Date::DayofWeek)
{
    my ($day, $month, $year) = @_;
  $day = &strip_leading_zero( $day );
  $month = &strip_leading_zero( $month );
    my $doomsday = &Doomsday( $year );
    my @base = ( 0, 0, 7, 4, 9, 6, 11, 8, 5, 10, 7, 12 );
    @base[0,1] = leapyear($year) ? (32,29) : (31,28);
    my $on = $day - $base[$month - 1];
    $on = $on % 7;
    return ($doomsday + $on) % 7;
}
sub Doomsday
### Doomsday is a concept invented by John Horton Conway to make it easier to
### figure out what day of the week particular events occur in a given year.
### Returns the day of the week (in the range 0..6) of doomsday in the particular
### year given. If no year is specified, the current year is assumed.
### (extracted from Date::Doomsday)
{
    my $year = shift;
    $year = ( localtime(time) )[5] unless $year;
    my $century = $year - ( $year % 100 );
    my $base = ( 3, 2, 0, 5 )[ ( ($century - 1500)/100 )%4 ];
    my $twelves = int ( ( $year - $century )/12);
    my $rem = ( $year - $century ) % 12;
    my $fours = int ($rem/4);
    my $doomsday = $base + ($twelves + $rem + $fours)%7;
    return $doomsday % 7;
}
sub leapyear
###  returns 1 or 0 if a year is leap or not  (4digit year - 2 digit gives same result except for century)
### (extracted from Date::Leapyear)
{
    my $year = $_[0];
    return 1 if (( $year % 400 ) == 0 ); # 400's are leap
    return 0 if (( $year % 100 ) == 0 ); # Other centuries are not
    return 1 if (( $year % 4 ) == 0 ); # All other 4's are leap
    return 0; # Everything else is not
}
###########################################################################################
###########################################################################################
sub kill_pstree()
### TO KILL JOB AND ALL ITS CHILDREN      
{
  ### from richard hanschu, @kills=(`pstree -p $previousjobpid` =~ /\(([0-9]+)/g); for ($i=1; $i<=@kills; ++$i){`/bin/kill -9 $kills[$i-1]`; }
  my $jobpid = $_[0];
  ### exit if no argument
  if( ! defined $jobpid ) { return -1; }
  my @kills = (`pstree -p $jobpid` =~ /\(([0-9]+)/g);
  my $killlist = join ' ',(@kills);
  ### send stderr to stdout as once tried to kill non-existent job
  jchomp( my $killout = `kill -9 $killlist 2>&1` );
  return $killout;
}
###########################################################################################
###########################################################################################
sub GMT_plus_mins ()
### CALC DAY/TIME AFTER ADDING $DELmins MINUTES TO INPUT DAY/TIME VALUES
### INPUT/OUTPUT YEAR=4digit MONTH=01-12 DAY=01-31
### MUST ALLOW FOR PERL ZERO INDEXING AND YEAR-1900
{
  use Time::Local;
  my ( $year1,$month1,$day1,$hr1,$min1, $DELmins ) = @_;
  my ( $csec, $year2,$month2,$day2,$hr2,$min2,$sec2, $wday,$jday,$isdst );
  $csec = timegm( 0,$min1,$hr1,$day1,($month1-1),($year1-1900) );
  $csec += 60*$DELmins ;
  ( $sec2,$min2,$hr2,$day2,$month2,$year2, $wday,$jday,$isdst ) = gmtime( $csec );;
  $min2 = sprintf "%02d", $min2 ;
  $hr2 = sprintf "%02d", $hr2 ;
  $day2 = sprintf "%02d", $day2 ;
  $month2 = sprintf "%02d", ($month2+1) ;
  $year2 += 1900 ;
  return $year2,$month2,$day2,$hr2,$min2;
}
###########################################################################################
###########################################################################################
sub system_child_timeout ()
### run system command $command (with args) - kill it+children after $timeout secs, tests every $waitsec secs
### return 0 if no timeout, 1 if timeout+kill
{
  my ( $command, $timeoutsec, $waitsec ) = @_ ;
  my $childproc = Proc::Background->new( "$command" );
  my $elapsedsec = 0;
  my $rc = 0;
  my $childpid = $childproc->pid ;
  while ( $childproc->alive )
  {
    if( $elapsedsec > $timeoutsec )
    {
      my $killout = &kill_pstree( $childpid );
      $rc = 1;
      last ;
    }
    sleep $waitsec ;
    $elapsedsec += $waitsec ;
  }   
  return $rc ;
}
###########################################################################################
###########################################################################################
sub zuluhhmm()
### RETURN GMT TIME HH:MM STRING
{
  my ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = gmtime(time);
  my $hhmm = sprintf "%02d:%02d",$hour,$min ;
  return $hhmm ;
}
###########################################################################################
###########################################################################################
sub fileage_delete ()
{
  ### DETERMINE MODIFICATION AGE OF FILES IN CURRENT DIRECTORY
  my ($dirname,$critagesec) = @_ ;
  ### DETERMINE CURRENT EPOCH SECS
  my $currentcsecs = time() ;
  ### READ FILES
  opendir DIR, $dirname ;
  my @filelist = readdir DIR ;
  closedir DIR ;
  ### LOOP OVER FILES
  my ( $ifile, $filename, $agesecs );
  for ($ifile=0; $ifile<=$#filelist; $ifile++)
  {
    $filename = $dirname . '/' . $filelist[$ifile] ;
    ### DETERMINE AGE IN SECS
    ### treat only regular files
    if( ! -f $filename ) { next; }
    ### get local file time (in epoch secs) using perl "stat"
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat $filename ;
    ### use_modification_age:
    $agesecs = $currentcsecs - $mtime ;
    ### use_access_age:   $agesecs = $currentcsecs - $atime ;
    ### ADDITIONAL TREATMENT OF FILES
    ### delete older files
    if( $agesecs > $critagesec )
    {
      `rm -f $filename 2>/dev/null` ;
    }
  }
}
###########################################################################################
###########################################################################################
### FIND NEAREST INTEGER
sub nint { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }
#########################################################################
###################   END OF SUBROUTINE DEFINITIONS   ###################
#########################################################################
