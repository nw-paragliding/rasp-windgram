#! /usr/bin/perl  -w
if ( $#ARGV != -1 && $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Create a WRFSI window directory \$PWD-WINDOW\n";
print "  Automatically uses STAGE*1* fine:coarse grid resolution ratio \n";
print "  (Must be run from within the first-stage directory WRF/WRFSI/domains/REGIONXYZ)\n";
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

########################################################

### DETERMINE THE RUN DIRECTORY 
$STAGE1_DIR = $ENV{'PWD'} ;

### EXTRACT THE REGION NAME
( $REGIONNAME = $ENV{'PWD'} ) =~ s|^.*/||;

### SET THE STAGE-2 "WINDOW" DIRECTORY
$STAGE2_DIR = "$ENV{'PWD'}-WINDOW" ;

### CREATE THE STAGE-2 "WINDOW" DIRECTORY
`mkdir -p $STAGE2_DIR` ;
print "Creating WINDOW directory $STAGE2_DIR \n";

### CREATE EMPTY STAGE-2 SUBDIRECTORIES
`cd $STAGE2_DIR ; mkdir -p log ; mkdir -p siprd ; mkdir -p wrfprd ; mkdir -p cdl ; mkdir -p static` ;

### CREATE STAGE-2 LINKS TO STAGE-1 DIRECTORY FILES
### subdirectory cdl
`ln -sf $STAGE1_DIR/cdl/wrfsi.cdl $STAGE2_DIR/cdl/wrfsi.cdl` ;
`ln -sf $STAGE1_DIR/cdl/wrfsi.d02.cdl $STAGE2_DIR/cdl/wrfsi.d01.cdl` ;
`ln -sf $STAGE1_DIR/cdl/wrfsi.d03.cdl $STAGE2_DIR/cdl/wrfsi.d02.cdl` ;
### subdirectory static
`ln -sf $STAGE1_DIR/static/created_wrf_static.dat $STAGE2_DIR/static/created_wrf_static.dat` ;
`ln -sf $STAGE1_DIR/static/latlon2d.d02.dat $STAGE2_DIR/static/latlon2d.d01.dat` ;
`ln -sf $STAGE1_DIR/static/latlon2d.d03.dat $STAGE2_DIR/static/latlon2d.d02.dat` ;
`ln -sf $STAGE1_DIR/static/latlon2d-mass.d02.dat $STAGE2_DIR/static/latlon2d-mass.d01.dat` ;
`ln -sf $STAGE1_DIR/static/latlon2d-mass.d03.dat $STAGE2_DIR/static/latlon2d-mass.d02.dat` ;
`ln -sf $STAGE1_DIR/static/latlon.d02.dat $STAGE2_DIR/static/latlon.d01.dat` ;
`ln -sf $STAGE1_DIR/static/latlon.d03.dat $STAGE2_DIR/static/latlon.d02.dat` ;
`ln -sf $STAGE1_DIR/static/latlon-mass.d02.dat $STAGE2_DIR/static/latlon-mass.d01.dat` ;
`ln -sf $STAGE1_DIR/static/latlon-mass.d03.dat $STAGE2_DIR/static/latlon-mass.d02.dat` ;
`ln -sf $STAGE1_DIR/static/static.wrfsi.d02 $STAGE2_DIR/static/static.wrfsi.d01` ;
`ln -sf $STAGE1_DIR/static/static.wrfsi.d03 $STAGE2_DIR/static/static.wrfsi.d02` ;
`ln -sf $STAGE1_DIR/static/topo.d02.dat $STAGE2_DIR/static/topo.d01.dat` ;
`ln -sf $STAGE1_DIR/static/topo.d03.dat $STAGE2_DIR/static/topo.d02.dat` ;
`ln -sf $STAGE1_DIR/static/topography.d02.dat $STAGE2_DIR/static/topography.d01.dat` ;
`ln -sf $STAGE1_DIR/static/topography.d03.dat $STAGE2_DIR/static/topography.d02.dat` ;
`ln -sf $STAGE1_DIR/static/topography-mass.d02.dat $STAGE2_DIR/static/topography-mass.d01.dat` ;
`ln -sf $STAGE1_DIR/static/topography-mass.d03.dat $STAGE2_DIR/static/topography-mass.d02.dat` ;
`ln -sf $STAGE1_DIR/static/topo-mass.d02.dat $STAGE2_DIR/static/topo-mass.d01.dat` ;
`ln -sf $STAGE1_DIR/static/topo-mass.d03.dat $STAGE2_DIR/static/topo-mass.d02.dat` ;
`ln -sf $STAGE1_DIR/static/wrfstatic_d02 $STAGE2_DIR/static/wrfstatic_d01` ;
`ln -sf $STAGE1_DIR/static/wrfstatic_d03 $STAGE2_DIR/static/wrfstatic_d02` ;

### CREATE STAGE_2 wrfsi.nl NAMELIST FILE based on stage1 namelist file
`cp -pf $STAGE1_DIR/static/wrfsi.nl $STAGE2_DIR/static/wrfsi.nl.$REGIONNAME` ;
### loop over lines in input file - read all first to get needed data, them modify selected ones
@lines = `cat $STAGE1_DIR/static/wrfsi.nl` ;
### find needed data in stage1 file
### for below extract value after first comma
@tmparray = grep /^ *DOMAIN_ORIGIN_LLI *=/i, @lines ; @stage1_origin_lli = split /,/, $tmparray[0] ;
@tmparray = grep /^ *DOMAIN_ORIGIN_LLJ *=/i, @lines ; @stage1_origin_llj = split /,/, $tmparray[0] ;
@tmparray = grep /^ *DOMAIN_ORIGIN_URI *=/i, @lines ; @stage1_origin_uri = split /,/, $tmparray[0] ;
@tmparray = grep /^ *DOMAIN_ORIGIN_URJ *=/i, @lines ; @stage1_origin_urj = split /,/, $tmparray[0] ;
chomp ( $stage1_origin_lli[$#stage1_origin_lli] ); chomp ( $stage1_origin_llj[$#stage1_origin_llj] ); chomp ( $stage1_origin_uri[$#stage1_origin_uri] ); chomp ( $stage1_origin_urj[$#stage1_origin_urj] );
@tmparray = grep /^ *RATIO_TO_PARENT *=/i, @lines ; @stage1_ratio_to_parent = split /,/, $tmparray[0] ; chomp ( $stage1_ratio_to_parent[$#stage1_ratio_to_parent] );
### for below extract value from reg.exp.
@tmparray = grep /^ *MOAD_DELTA_X *=/i, @lines ; ( $stage1_delta_x = $tmparray[0] ) =~ s|^ *MOAD_DELTA_X *= *([^,]*).*$|$1|i; chomp $stage1_delta_x ;
@tmparray = grep /^ *MOAD_DELTA_Y *=/i, @lines ; ( $stage1_delta_y = $tmparray[0] ) =~ s|^ *MOAD_DELTA_Y *= *([^,]*).*$|$1|i; chomp $stage1_delta_y ;

### set stage1 ratio based on value read from file
$STAGE1_RESOLUTION_RATIO = $stage1_ratio_to_parent[1] ;
print "* Using stage *1* fine:coarse grid resolution ratio of ${STAGE1_RESOLUTION_RATIO}:1 \n";

### compute stage2 coarse grid size 
$stage2_xdim = $STAGE1_RESOLUTION_RATIO*( $stage1_origin_uri[1] - $stage1_origin_lli[1] ) +1 ;
$stage2_ydim = $STAGE1_RESOLUTION_RATIO*( $stage1_origin_urj[1] - $stage1_origin_llj[1] ) +1 ;
#old $stage2_xdim = 3*( $stage1_origin_uri[1] - $stage1_origin_lli[1] ) +1 ;
#old $stage2_ydim = 3*( $stage1_origin_urj[1] - $stage1_origin_llj[1] ) +1 ;

### compute stage2 resolution
$stage2_delta_x = ( $stage1_delta_x ) / $STAGE1_RESOLUTION_RATIO ;
$stage2_delta_y = ( $stage1_delta_y ) / $STAGE1_RESOLUTION_RATIO ;
#old $stage2_delta_x = 0.33333333*( $stage1_delta_x ) ;
#old $stage2_delta_y = 0.33333333*( $stage1_delta_y ) ;
#4test print "stage2_xdim= $stage2_xdim =\n"; 

for ( $iline=0; $iline<=$#lines; $iline++ )
{

  ###### SHIFT 2ND & 3RD COLUMNS OVER BY ONE, ELIMINATING 1ST COLUMN
  ### ensure  NUM_DOMAINS=2 for WINDOW RUN
  if( $lines[$iline] =~ m|^ *NUM_DOMAINS *=|i )
  {
    $lines[$iline] = " NUM_DOMAINS = 2, \n";
    print "ensure WINDOW wrfsi.nl NUM_DOMAINS = 2, \n";
  }
  ### ensure  NUM_ACTIVE_SUBNESTS=1 for WINDOW RUN
  if( $lines[$iline] =~ m|^ *NUM_ACTIVE_SUBNESTS *=|i )
  {
    $lines[$iline] = " NUM_ACTIVE_SUBNESTS = 1, \n";
    print "ensure WINDOW wrfsi.nl NUM_ACTIVE_SUBNESTS = 1, \n";
  }
  ### ensure  ACTIVE_SUBNESTS=2 for WINDOW RUN
  if( $lines[$iline] =~ m|^ *ACTIVE_SUBNESTS *=|i )
  {
    $lines[$iline] = " ACTIVE_SUBNESTS = 2, \n";
    print "ensure WINDOW wrfsi.nl ACTIVE_SUBNESTS = 2, \n";
  }
  ### ensure  PARENT_ID = 1, 1,  for WINDOW RUN
  if( $lines[$iline] =~ m|^ *PARENT_ID *=|i )
  {
    $lines[$iline] = " PARENT_ID = 1, 1, \n";
    print "ensure WINDOW namelist.template PARENT_ID = 1, 1, \n";
  }


  ###### "MODIFY" LINES KEEP A VALUE READ FROM NON-WINDOW FILE
  ### modify INTERVAL line
  if( $lines[$iline] =~ m|^ *INTERVAL *=|i )
  {
    $stage2_interval = 3600 ;
    $lines[$iline] = " INTERVAL = ${stage2_interval}, \n";
    print "set WINDOW wrfsi.nl INTERVAL = ${stage2_interval}, \n";
  }
  ### modify XDIM line
  if( $lines[$iline] =~ m|^ *XDIM *=|i )
  {
    $lines[$iline] = " XDIM = ${stage2_xdim}, \n";
    print "set WINDOW wrfsi.nl XDIM = ${stage2_xdim}, \n";
  }
  ### modify YDIM line
  if( $lines[$iline] =~ m|^ *YDIM *=|i )
  {
    $lines[$iline] = " YDIM = ${stage2_ydim}, \n";
    print "set WINDOW wrfsi.nl YDIM = ${stage2_ydim}, \n";
  }
  ### modify DOMAIN_ORIGIN_LLI line
  if( $lines[$iline] =~ m|^ *DOMAIN_ORIGIN_LLI *=|i )
  {
    $lines[$iline] = " DOMAIN_ORIGIN_LLI = 1, ${stage1_origin_lli[2]}, \n";
    print "set WINDOW wrfsi.nl DOMAIN_ORIGIN_LLI = 1, ${stage1_origin_lli[2]}, \n";
  }
  ### modify DOMAIN_ORIGIN_LLJ line
  if( $lines[$iline] =~ m|^ *DOMAIN_ORIGIN_LLJ *=|i )
  {
    $lines[$iline] = " DOMAIN_ORIGIN_LLJ = 1, ${stage1_origin_llj[2]}, \n";
    print "set WINDOW wrfsi.nl DOMAIN_ORIGIN_LLJ = 1, ${stage1_origin_llj[2]}, \n";
  }
  ### modify DOMAIN_ORIGIN_URI line
  if( $lines[$iline] =~ m|^ *DOMAIN_ORIGIN_URI *=|i )
  {
    $lines[$iline] = " DOMAIN_ORIGIN_URI = ${stage2_xdim}, ${stage1_origin_uri[2]}, \n";
    print "set WINDOW wrfsi.nl DOMAIN_ORIGIN_URI = ${stage2_xdim}, ${stage1_origin_uri[2]}, \n";
  }
  ### modify DOMAIN_ORIGIN_URJ line
  if( $lines[$iline] =~ m|^ *DOMAIN_ORIGIN_URJ *=|i )
  {
    $lines[$iline] = " DOMAIN_ORIGIN_URJ = ${stage2_ydim}, ${stage1_origin_urj[2]}, \n";
    print "set WINDOW wrfsi.nl DOMAIN_ORIGIN_URJ = ${stage2_ydim}, ${stage1_origin_urj[2]}, \n";
  }
  ### modify MOAD_DELTA_X line
  if( $lines[$iline] =~ m|^ *MOAD_DELTA_X *=|i )
  {
    $lines[$iline] = sprintf " MOAD_DELTA_X = %.3f, \n", ${stage2_delta_x};
    printf "set WINDOW wrfsi.nl MOAD_DELTA_X = %.3f,\n", ${stage2_delta_x};
  }
  ### modify MOAD_DELTA_Y line
  if( $lines[$iline] =~ m|^ *MOAD_DELTA_Y *=|i )
  {
    $lines[$iline] = sprintf " MOAD_DELTA_Y = %.3f, \n", ${stage2_delta_y};
    printf "set WINDOW wrfsi.nl MOAD_DELTA_Y = %.3f,\n", ${stage2_delta_y};
  }
  ### modify RATIO_TO_PARENT line (note that first array element includes original line up to first comma)
  if( $lines[$iline] =~ m|^ *RATIO_TO_PARENT *=|i )
  {
    $lines[$iline] = "${stage1_ratio_to_parent[0]},  ${stage1_ratio_to_parent[2]}, \n";
    print "set WINDOW wrfsi.nl RATIO_TO_PARENT = ${stage1_ratio_to_parent[2]}, \n";
  }

}
### save stage2 wrfsi.nl
open( OUTPUTFILE, ">$STAGE2_DIR/static/wrfsi.nl" );
print OUTPUTFILE @lines ;
close ( OUTPUTFILE );
