#! /usr/bin/perl  -w
#expect2arguments:
if ( $#ARGV != 1 ) {
#ifnot1argument: if ( $#ARGV != 0 || $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Create new WRF directory \$2 containing LINKS to files in existing directory \$1  (NOTE ORDERING ALA COPY!) \n";
print "e.g. create_directory.wrf_linked.pl \$HOME/DRJACK/WRF/WRFV2/RASP/CANV \$HOME/DRJACK/WRF/WRFV2/RASP/CANV_ALT \n";
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
print "***NB*** for any variations must replace link with local file (else will actually edit linked file!!!) notably namelist.template \n";

### CREATE NEEDED LINKS 
### *** DO *NOT* ALLOW OVER-WRITE - SO INCORRECT USAGE WON'T DESTROY ANYTHING !!! ***
`ln -s ../../main/real.exe $ARG2_DIR/real.exe` ;
`ln -s ../../main/ndown.exe $ARG2_DIR/ndown.exe` ;
`ln -s ../../main/wrf.exe $ARG2_DIR/wrf.exe` ;
`ln -s ../../run/gribmap.txt $ARG2_DIR/gribmap.txt` ;
`ln -s ../../run/ETAMPNEW_DATA $ARG2_DIR/ETAMPNEW_DATA` ;
`ln -s ../../run/GENPARM.TBL $ARG2_DIR/GENPARM.TBL` ;
`ln -s ../../run/LANDUSE.TBL $ARG2_DIR/LANDUSE.TBL` ;
`ln -s ../../run/RRTM_DATA $ARG2_DIR/RRTM_DATA` ;
`ln -s ../../run/SOILPARM.TBL $ARG2_DIR/SOILPARM.TBL` ;
`ln -s ../../run/VEGPARM.TBL $ARG2_DIR/VEGPARM.TBL` ;
`ln -s ../../run/tr49t67 $ARG2_DIR/tr49t67` ;
`ln -s ../../run/tr49t85 $ARG2_DIR/tr49t85` ;
`ln -s ../../run/tr67t85 $ARG2_DIR/tr67t85` ;
`ln -s ../../run/README.namelist $ARG2_DIR/README.namelist` ;
`ln -s $ARG1_DIR/namelist.template $ARG2_DIR/namelist.template` ;

