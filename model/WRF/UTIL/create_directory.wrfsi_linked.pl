#! /usr/bin/perl  -w
#expect2arguments:
if ( $#ARGV != 1 ) {
#ifnot1argument: if ( $#ARGV != 0 || $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Create new WRFSI directory \$2 containing LINKS to files in existing directory \$1 subdirectories static & cdl\n";
print "   and add empty subdirectories siprd & log & wrfprd  (NOTE ORDERING ALA COPY!)\n";
print "e.g. create_directory.wrfsi_linked.pl \$HOME/DRJACK/WRF/WRFSI/domains/CANV \$HOME/DRJACK/WRF/WRFSI/domains/CANV_ALT \n";
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

### DETERMINE THE RUN DIRECTORYS 
$ARG1_DIR = $ARGV[0] ;
$ARG2_DIR = $ARGV[1] ;

### CREATE THE ARG-2 DIRECTORY
`mkdir -p $ARG2_DIR` ;
print "Create directory $ARG2_DIR containing LINKS to files in directory $ARG1_DIR (NOTE ORDERING ALA COPY!) \n";
print "EXCEPT static/wrfsi.nl NOW COPIED to allow constency check overwrite of GRIBFILE_MODEL  \n";
print "***NB*** for any variations must replace link with local file (else will actually edit linked file!!!) \n";

### CREATE EMPTY ARG-2 SUBDIRECTORIES
`cd $ARG2_DIR ; mkdir -p log ; mkdir -p siprd ; mkdir -p wrfprd ; mkdir -p cdl ; mkdir -p static` ;

### CREATE ARG-2 LINKS TO ARG-1 DIRECTORY FILES
### *** DO *NOT* ALLOW OVER-WRITE - SO INCORRECT USAGE WON'T DESTROY ANYTHING !!! ***

### SET MAX GRIDS
#old $maxgrid = 3 ;
@gridcount=`ls $ARG1_DIR/cdl/wrfsi.d0*.cdl` ;
$maxgrid = $#{gridcount} +1 ;
print "FOUND $maxgrid GRIDS TO BE LINKED \n";

### do subdirectory cdl
`ln -s $ARG1_DIR/cdl/wrfsi.cdl $ARG2_DIR/cdl/wrfsi.cdl` ;
for ( $igrid=1;  $igrid<=$maxgrid; $igrid++ )
{ 
  `ln -s $ARG1_DIR/cdl/wrfsi.d0${igrid}.cdl $ARG2_DIR/cdl/wrfsi.d0${igrid}.cdl` ;
}
### do subdirectory static
`ln -s $ARG1_DIR/static/created_wrf_static.dat $ARG2_DIR/static/created_wrf_static.dat` ;
for ( $igrid=1;  $igrid<=$maxgrid; $igrid++ )
{ 
  `ln -s $ARG1_DIR/static/latlon2d.d0${igrid}.dat $ARG2_DIR/static/latlon2d.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/latlon2d-mass.d0${igrid}.dat $ARG2_DIR/static/latlon2d-mass.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/latlon.d0${igrid}.dat $ARG2_DIR/static/latlon.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/latlon-mass.d0${igrid}.dat $ARG2_DIR/static/latlon-mass.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/static.wrfsi.d0${igrid} $ARG2_DIR/static/static.wrfsi.d0${igrid}` ;
  `ln -s $ARG1_DIR/static/topo.d0${igrid}.dat $ARG2_DIR/static/topo.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/topography.d0${igrid}.dat $ARG2_DIR/static/topography.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/topography-mass.d0${igrid}.dat $ARG2_DIR/static/topography-mass.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/topo-mass.d0${igrid}.dat $ARG2_DIR/static/topo-mass.d0${igrid}.dat` ;
  `ln -s $ARG1_DIR/static/wrfstatic_d0${igrid} $ARG2_DIR/static/wrfstatic_d0${igrid}` ;
}

### now COPY instead of creating a link so that automatic consistency overwrite of GRIBFILE_MODEL will not alter originalfile !
print "COPIED .../static/wrfsi.nl instead of creating link so automatic consistency overwrite of GRIBFILE_MODEL will not alter originalfile ! \n";
`cp -p $ARG1_DIR/static/wrfsi.nl $ARG2_DIR/static` ;
#old `ln -s $ARG1_DIR/static/wrfsi.nl $ARG2_DIR/static` ;

