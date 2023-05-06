#! /usr/bin/perl  -w
if ( $#ARGV != -1 && $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Create a WRFV2 window directory \$PWD-WINDOW\n";
print "Optional argument over-rides internally set default STAGE *1* fine:coarse grid resolution ratio \n";
print "(Must be run from within the first-stage directory WRF/WRFV2/RASP/REGIONXYZ)\n";
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

### NOTE: SHIFTS 2ND & 3RD COLUMNS OVER BY ONE, ELIMINATING 1ST COLUMN
###       WHICH MIGHT BE DANGEROUS BUT DOES PRESERVE ANY DOMAIN-SPECIFIC PARAMETER VALUES

### DETERMINE THE RUN DIRECTORY 
$STAGE1_DIR = $ENV{'PWD'} ;

### EXTRACT THE REGION NAME
( $REGIONNAME = $ENV{'PWD'} ) =~ s|^.*/||;

### SET THE STAGE-2 "WINDOW" DIRECTORY
$STAGE2_DIR = "$ENV{'PWD'}-WINDOW" ;

### CREATE THE STAGE-2 "WINDOW" DIRECTORY
`mkdir -p $STAGE2_DIR` ;
print "Creating WINDOW directory $STAGE2_DIR \n";

### CREATE NEEDED LINKS 
`ln -sf ../../main/real.exe $STAGE2_DIR/real.exe` ;
`ln -sf ../../main/ndown.exe $STAGE2_DIR/ndown.exe` ;
`ln -sf ../../main/wrf.exe $STAGE2_DIR/wrf.exe` ;
`ln -sf ../../run/gribmap.txt $STAGE2_DIR/gribmap.txt` ;
`ln -sf ../../run/ETAMPNEW_DATA $STAGE2_DIR/ETAMPNEW_DATA` ;
`ln -sf ../../run/GENPARM.TBL $STAGE2_DIR/GENPARM.TBL` ;
`ln -sf ../../run/LANDUSE.TBL $STAGE2_DIR/LANDUSE.TBL` ;
`ln -sf ../../run/RRTM_DATA $STAGE2_DIR/RRTM_DATA` ;
`ln -sf ../../run/SOILPARM.TBL $STAGE2_DIR/SOILPARM.TBL` ;
`ln -sf ../../run/VEGPARM.TBL $STAGE2_DIR/VEGPARM.TBL` ;
`ln -sf ../../run/tr49t67 $STAGE2_DIR/tr49t67` ;
`ln -sf ../../run/tr49t85 $STAGE2_DIR/tr49t85` ;
`ln -sf ../../run/tr67t85 $STAGE2_DIR/tr67t85` ;
`ln -sf ../../run/README.namelist $STAGE2_DIR/README.namelist` ;

### CREATE STAGE_2 namelist.template NAMELIST FILE based on stage1 namelist file
`cp -pf $STAGE1_DIR/namelist.template $STAGE2_DIR/namelist.template.$REGIONNAME` ;
### loop over lines in input file - read all first to get needed data, them modify selected ones
@lines = `cat $STAGE1_DIR/namelist.template` ;

### find needed data in stage1 file
### for below extract value after first comma
@tmparray = grep /^ *I_PARENT_START *=/i, @lines ; @stage1_i_parent_start = split /,/, $tmparray[0] ;
@tmparray = grep /^ *J_PARENT_START *=/i, @lines ; @stage1_j_parent_start = split /,/, $tmparray[0] ;
@tmparray = grep /^ *PARENT_GRID_RATIO *=/i, @lines ; @stage1_parent_grid_ratio = split /,/, $tmparray[0] ; chomp $stage1_parent_grid_ratio[$#stage1_parent_grid_ratio] ; 
@tmparray = grep /^ *PARENT_TIME_STEP_RATIO *=/i, @lines ; @stage1_parent_time_step_ratio = split /,/, $tmparray[0] ; chomp $stage1_parent_time_step_ratio[$#stage1_parent_time_step_ratio] ;
#old @tmparray = grep /^ *E_WE *=/i, @lines ; @stage1_e_we = split /,/, $tmparray[0] ;
#old @tmparray = grep /^ *E_SN *=/i, @lines ; @stage1_e_sn = split /,/, $tmparray[0] ;
#old @tmparray = grep /^ *DX *=/i, @lines ; @stage1_dx = split /,/, $tmparray[0] ;
#old @tmparray = grep /^ *DY *=/i, @lines ; @stage1_dy = split /,/, $tmparray[0] ;

### for below extract value using reg.exp.
@tmparray = grep /^ *TIME_STEP *=/i, @lines ; ( $stage1_time_step = $tmparray[0] ) =~ s|^ *TIME_STEP *= *([^,]*).*$|$1|i; chomp $stage1_time_step ;

### set stage1 ratio based on value read from file
$STAGE1_RESOLUTION_RATIO = $stage1_parent_grid_ratio[1] ;
print "* Using stage *1* fine:coarse grid resolution ratio of ${STAGE1_RESOLUTION_RATIO}:1 \n";

### compute stage2 time step - must be integer
$stage2_time_step = int( ( $stage1_time_step ) / $STAGE1_RESOLUTION_RATIO ) ;
#old-noninteger $stage2_time_step = ( $stage1_time_step ) / $STAGE1_RESOLUTION_RATIO ;
#old $stage2_time_step = 0.33333333*( $stage1_time_step ) ;

### loop over all lines
for ( $iline=0; $iline<=$#lines; $iline++ )
{

  ###### SHIFT 2ND & 3RD COLUMNS OVER BY ONE, ELIMINATING 1ST COLUMN
  if( $lines[$iline] =~ m|^([^=]+)=([^,]+),([^,]+),(.*)$| )
  { $lines[$iline] = "${1}= ${3},${4} \n" ; }

  ###### "ENSURE" LINES JUST REPLACE ENTIRE LINE
  ### ensure  MAX_DOM = 2  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *MAX_DOM *=|i )
  {
    $lines[$iline] = " MAX_DOM = 2, \n";
    print "ensure WINDOW namelist.template MAX_DOM = 2, \n";
  }
  ### ensure  GRID_ID = 1, 2  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *GRID_ID *=|i )
  {
    $lines[$iline] = " GRID_ID = 1, 2, \n";
    print "ensure WINDOW namelist.template GRID_ID = 1, 2, \n";
  }
  ### ensure  PARENT_ID = 1, 1,  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *PARENT_ID *=|i )
  {
    $lines[$iline] = " PARENT_ID = 1, 1, \n";
    print "ensure WINDOW namelist.template PARENT_ID = 1, 1, \n";
  }
  ### ensure  INPUT_FROM_FILE = .true.,.true.,  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *INPUT_FROM_FILE *=|i )
  {
    $lines[$iline] = " INPUT_FROM_FILE = .true.,.true., \n";
    print "ensure WINDOW namelist.template  INPUT_FROM_FILE = .true.,.true., \n";
  }
  ### ensure  SPECIFIED = .true.,.false.,  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *SPECIFIED *=|i )
  {
    $lines[$iline] = " SPECIFIED = .true.,.false., \n";
    print "ensure WINDOW namelist.template  SPECIFIED = .true.,.false., \n";
  }
  ### ensure  NESTED = .false.,.true.,  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *NESTED *=|i )
  {
    $lines[$iline] = " NESTED = .false.,.true., \n";
    print "ensure WINDOW namelist.template  NESTED = .false.,.true., \n";
  }

  ###### "MODIFY" LINES KEEP A VALUE READ FROM NON-WINDOW FILE
  ### modify INTERVAL_SECONDS line
  if( $lines[$iline] =~ m|^ *INTERVAL_SECONDS *=|i )
  {
    $stage2_interval_seconds = 3600 ;
    $lines[$iline] = " INTERVAL_SECONDS = ${stage2_interval_seconds}, \n";
    print "set WINDOW namelist.template INTERVAL_SECONDS = ${stage2_interval_seconds}, \n";
  }
  ### modify HISTORY_INTERVAL line
  if( $lines[$iline] =~ m|^ *HISTORY_INTERVAL *=|i )
  {
    $stage2_history_interval = 30 ;
    $lines[$iline] = " HISTORY_INTERVAL = ${stage2_history_interval}, ${stage2_history_interval}, ${stage2_history_interval}, \n";
    print "set WINDOW namelist.template HISTORY_INTERVAL = ${stage2_history_interval}, ${stage2_history_interval}, ${stage2_history_interval}, \n";
  }
  ### modify TIME_STEP line
  if( $lines[$iline] =~ m|^ *TIME_STEP *=|i )
  {
    $lines[$iline] = sprintf " TIME_STEP = %i, \n", ${stage2_time_step};
    printf "set WINDOW namelist.template TIME_STEP = %i,\n", ${stage2_time_step};
    #old-noninteger $lines[$iline] = sprintf " TIME_STEP = %.3f, \n", ${stage2_time_step};
    #old-noninteger printf "set WINDOW namelist.template TIME_STEP = %.3f,\n", ${stage2_time_step};
  }
  ### modify I_PARENT_START line
  if( $lines[$iline] =~ m|^ *I_PARENT_START *=|i )
  {
    $lines[$iline] = " I_PARENT_START = 0, ${stage1_i_parent_start[2]}, \n";
    print "set WINDOW namelist.template I_PARENT_START =  0, ${stage1_i_parent_start[2]}, \n";
  }
  ### modify J_PARENT_START line
  if( $lines[$iline] =~ m|^ *J_PARENT_START *=|i )
  {
    $lines[$iline] = " J_PARENT_START = 0, ${stage1_j_parent_start[2]}, \n";
    print "set WINDOW namelist.template J_PARENT_START =  0, ${stage1_j_parent_start[2]}, \n";
  }
  ### modify PARENT_GRID_RATIO line
  if( $lines[$iline] =~ m|^ *PARENT_GRID_RATIO *=|i )
  {
    $lines[$iline] = " PARENT_GRID_RATIO = 1, ${stage1_parent_grid_ratio[2]}, \n";
    print "set WINDOW namelist.template PARENT_GRID_RATIO =  1, ${stage1_parent_grid_ratio[2]}, \n";
  }
  ### modify PARENT_TIME_STEP_RATIO line
  if( $lines[$iline] =~ m|^ *PARENT_TIME_STEP_RATIO *=|i )
  {
    $lines[$iline] = " PARENT_TIME_STEP_RATIO = 1, ${stage1_parent_time_step_ratio[2]}, \n";
    print "set WINDOW namelist.template PARENT_TIME_STEP_RATIO =  1, ${stage1_parent_time_step_ratio[2]}, \n";
  }
  #old ### modify E_WE line
  #old if( $lines[$iline] =~ m|^ *E_WE *=|i )
  #old {
  #old   $lines[$iline] = " E_WE = ${stage1_e_we[1]}, ${stage1_e_we[2]}, \n";
  #old   print "set WINDOW namelist.template E_WE =  ${stage1_e_we[1]}, ${stage1_e_we[2]}, \n";
  #old }
  #old ### modify E_SN line
  #old if( $lines[$iline] =~ m|^ *E_SN *=|i )
  #old {
  #old   $lines[$iline] = " E_SN = ${stage1_e_sn[1]}, ${stage1_e_sn[2]}, \n";
  #old   print "set WINDOW namelist.template E_SN =  ${stage1_e_sn[1]}, ${stage1_e_sn[2]}, \n";
  #old }
  #old ### modify DX line
  #old if( $lines[$iline] =~ m|^ *DX *=|i )
  #old {
  #old   $lines[$iline] = " DX = ${stage1_dx[1]}, ${stage1_dx[2]}, \n";
  #old   print "set WINDOW namelist.template DX =  ${stage1_dx[1]}, ${stage1_dx[2]}, \n";
  #old }
  #old ### modify DY line
  #old if( $lines[$iline] =~ m|^ *DY *=|i )
  #old {
  #old   $lines[$iline] = " DY = ${stage1_dy[1]}, ${stage1_dy[2]}, \n";
  #old   print "set WINDOW namelist.template DY =  ${stage1_dy[1]}, ${stage1_dy[2]}, \n";
  #old }

}
### save stage2 namelist.template
open( OUTPUTFILE, ">$STAGE2_DIR/namelist.template" );
print OUTPUTFILE @lines ;
close ( OUTPUTFILE );
