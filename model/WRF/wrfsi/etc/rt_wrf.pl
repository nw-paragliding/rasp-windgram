#!/usr/bin/perl
#dis
#dis    Open Source License/Disclaimer, Forecast Systems Laboratory
#dis    NOAA/OAR/FSL, 325 Broadway Boulder, CO 80305
#dis
#dis    This software is distributed under the Open Source Definition,
#dis    which may be found at http://www.opensource.org/osd.html.
#dis
#dis    In particular, redistribution and use in source and binary forms,
#dis    with or without modification, are permitted provided that the
#dis    following conditions are met:
#dis
#dis    - Redistributions of source code must retain this notice, this
#dis    list of conditions and the following disclaimer.
#dis
#dis    - Redistributions in binary form must provide access to this
#dis    notice, this list of conditions and the following disclaimer, and
#dis    the underlying source code.
#dis
#dis    - All modifications to this software must be clearly documented,
#dis    and are solely the responsibility of the agent making the
#dis    modifications.
#dis
#dis    - If significant modifications or enhancements are made to this
#dis    software, the FSL Software Policy Manager
#dis    (softwaremgr@fsl.noaa.gov) should be notified.
#dis
#dis    THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN
#dis    AND ARE FURNISHED "AS IS."  THE AUTHORS, THE UNITED STATES
#dis    GOVERNMENT, ITS INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND
#dis    AGENTS MAKE NO WARRANTY, EXPRESS OR IMPLIED, AS TO THE USEFULNESS
#dis    OF THE SOFTWARE AND DOCUMENTATION FOR ANY PURPOSE.  THEY ASSUME
#dis    NO RESPONSIBILITY (1) FOR THE USE OF THE SOFTWARE AND
#dis    DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL SUPPORT TO USERS.
#dis
#dis

# Script Name:  rt_wrf.pl
#
# Purpose:  This is a driver script to call wrfprep.pl and run_wrf.pl
#           for a real-time run.
#
# Usage:
#   
#   rt_wrf.pl -h to see options
#
#        
umask 000;
require 5;
use strict;
use Time::Local;
use vars qw($opt_c $opt_C $opt_d $opt_e $opt_f $opt_h
            $opt_i $opt_M $opt_m $opt_o $opt_p
            $opt_R $opt_q $opt_s $opt_t $opt_u);
use Getopt::Std;
print "Routine: wrfprep.pl\n";
my $mydir = `pwd`; chomp $mydir;

# Get command line options
getopts('c:C:d:e:f:hi:M:m:o:p:q:R:s:t:u:');

# Did the user ask for help?
if ($opt_h){
  print "Usage:  rt_wrf.pl [options]

          Valid Options:
          ===============================================================
          -c NODETYPE
             Sets the nodetype to use when launching jobs under PBS/SGE

          -C NODETYPE
             Node type to use with the WRF model run if different than 
             the type for the SI portion.  For example, on FSL ijet, one
             could specify es40 using -c to run the serial SI code on the
             es40, and set -C to comp to run the model on comp nodes.  If
             -C is not set, then the model will use the same node type
             specified in -c.

          -d MOAD_DATAROOT
             Sets or overrides the MOAD_DATAROOT environment variable.
             If no environment variable is set, this must be provided.

          -f RUN_LENGTH (in hours}
             If not set, the program assumes a 24-h forecast period

          -h 
             Prints this message

          -i INSTALLROOT 
             Sets/overrides the INSTALLROOT environment variable.

          -M options
             Specify options for running WRF mpirun command.
             Only used if -p is also set.
 
          -m MPICONF
             (Only valid if -p used).  Use this file to specify
             nodes to use.  If not set, script looks for 
             MOAD_DATAROOT/static/gmpi.conf or GMPICONF environment
             variable, in that order.

          -o OFFSET_HOURS
             Set initial time to current time + OFFSET_HOURS.  To
             run for a previous hour, this value should be negative.

          -p NP
             Run parallelized version of WRF using NP processes
 
          -q HH:MM:SS
             Use the PBS queuing system to run the job.  Requires
             max run time in hours:minutes:seconds.  Works on jet
             and ijet at FSL when used with the -u option.
          
          -R n
             Runs parallel real with n processors.  If -p is set,
             but -R is not, parallel real.exe is assumed to
             use NP processors.  If -p is set, but -R is set to 
             1, then serial real is assumed.  n>1 assumes
             parallel real with n processors.

          -s STARTTIME (YYYYMMDDHH UTC format)
             Use this time as the initial time instead of the 
             system clock

          -t LBC_INTERVAL (hours)
             Hours between lateral boundary condition files
             (If not set, 3 hours is the default)
 
          -u PROJECTNAME
             Sets the qsub -A project name ID for accounting purposes
             on jet/ijet at FSL.
           \n"; 
  exit;
}

# Set up run-time environment

my $runtime = time;
my ($installroot, $moad_dataroot);

# Determine the installroot.  Use the -i flag as first option,
# followed by INSTALLROOT environment variable, followed by
# current working directory with ../. appended.

if (! defined $opt_i){
  if (! $ENV{INSTALLROOT}){
    print "No INSTALLROOT environment variable set! \n";
    print "Attempting to use the current diretory to set installroot.\n";
    my $curdir = `pwd`; chomp $curdir;
    my $script = $0;
    if ($script =~ /^(\S{1,})\/rt_wrf.pl/){
      chdir "$1/..";
    }else{
      chdir "..";
    }
    $installroot = `pwd`; chomp $installroot;
    $ENV{INSTALLROOT}=$installroot;
    chdir $curdir;
  }else{
    $installroot = $ENV{INSTALLROOT};
  }
}else{
  $installroot = $opt_i;
  $ENV{INSTALLROOT}=$installroot;
}

# Look for some critical executables.

my $wrfprep = "$installroot/etc/wrfprep.pl";
if (! -e "$wrfprep"){ die "$wrfprep not found.\n";}
my $run_wrf = "$installroot/etc/run_wrf.pl";
if (! -e "$run_wrf"){ die "$run_wrf not found.\n";}

print "INSTALLROOT = $installroot\n";
require "$installroot/etc/wrfsi_utils.pm";

# Process MOAD_DATAROOT.  Use -d argument first, followed by 
# environment variable.

if (! defined $opt_d){
  if (! $ENV{MOAD_DATAROOT}){
    $moad_dataroot = "$installroot/data";
    $ENV{MOAD_DATAROOT} = $moad_dataroot; 
    print "ASSUMED DATAROOT = $moad_dataroot\n";
  }else{
    $moad_dataroot = $ENV{MOAD_DATAROOT};
  }
}else{
  $moad_dataroot = $opt_d;
  $ENV{MOAD_DATAROOT} = $moad_dataroot;
}
# Check for a couple of critical files in moad_dataroot
if (! -e "$moad_dataroot/static/wrfsi.nl"){
  die "No wrfsi.nl file in $moad_dataroot/static\n";
}
if (! -e "$moad_dataroot/static/wrf.nl"){
  die "No wrf.nl file in $moad_dataroot/static\n";
}
print "MOAD_DATAROOT = $moad_dataroot\n";

# Set some other variables 
my $runtime = `date -u +%H%M`; chomp $runtime;
my $logfile = "$moad_dataroot/log/rt_wrf.log.$runtime";
my $lockfile = "$moad_dataroot/wrfprd/rt_wrf.lock";
if (-f $lockfile){
  die "Lockfile set...exiting.\n";
}

# Process the other options.

if ($opt_f) {
  $wrfprep = "$wrfprep -f $opt_f";
}

if ($opt_o){
  $wrfprep = "$wrfprep -o $opt_o";
}

if ($opt_s){
  $wrfprep = "$wrfprep -s $opt_s";
}

if ($opt_p){
  if (! $opt_R) {
    $wrfprep = "$wrfprep -r p -p $opt_p";
  }else{
    if ($opt_R == 1 ){
      $wrfprep = "$wrfprep -r s";
    }
    if ($opt_R > 1) {
      $wrfprep = "$wrfprep -r p -p $opt_R";
    }
  }
  $run_wrf = "$run_wrf -p $opt_p";
  if ($opt_M) { $run_wrf = "$run_wrf -M $opt_M" }
  if ($opt_m) {
    $ENV{GMPICONF} = $opt_m;
    $ENV{MACHINE_FILE} = $opt_m;
    if (! -e "$ENV{GMPICONF}" ) {
       die "Specified GMPICONF file does not exist: $ENV{GMPICONF}\n";
    }
  }else{
    if (! $opt_q){
      if (-f "$moad_dataroot/static/mpi_machines.conf"){
        $ENV{MACHINE_FILE} = "$moad_dataroot/static/mpi_machines.conf";
        $ENV{GMPICONF} =  $ENV{MACHINE_FILE};
      }else{
        if ((! $ENV{MACHINE_FILE})and(! $ENV{GMPICONF})){
           print "You have requested a multi-processor MPI run with -p $opt_p\n";
           print "But...no machines file seems to be present.  I checked:\n";
           print "GMPICONF environment variable, MACHINE_FILE environment variable, \
n";
           print "and $moad_dataroot/static/mpi_machines.conf\n";
           print "So, if things go awry, this may be why!\n";
        }
      }
    }
  }
}else{
  $wrfprep = "$wrfprep -r s";
}

if ($opt_q){
  $wrfprep = "$wrfprep -q $opt_q";
  $run_wrf = "$run_wrf -q $opt_q";
  if ($opt_c){
    $wrfprep = "$wrfprep -c $opt_c";
  }else{
    $wrfprep = "$wrfprep -c comp";
  }
  if ($opt_C){
    $run_wrf = "$run_wrf -c $opt_C";
  }else{
    if ($opt_c){
      $run_wrf = "$run_wrf -c $opt_c";
    }else{
      $run_wrf = "$run_wrf -c comp";
    }
  }
  if ($opt_u){
    $wrfprep = "$wrfprep -u $opt_u";
    $run_wrf = "$run_wrf -u $opt_u";
  }  
}

if ($opt_t){
  $wrfprep = "$wrfprep -t $opt_t";
}

# Set the lockfile
open (LOCK, ">$lockfile");
print LOCK "PID=$$\n";
close (LOCK);
open(LOG,">$logfile");
my $timenow = `date -u`; chomp $timenow;
print LOG "$timenow: Running $wrfprep\n";
print LOG "----------------------------------------------\n";
close (LOG);
my $result = system("$wrfprep >> $logfile 2>&1");
my $timenow = `date -u`; chomp $timenow;
open(LOG,">>$logfile");
print LOG "$timenow: wrfprep completed with status: $result\n";
print LOG "----------------------------------------------\n";
print LOG "$timenow: Running $run_wrf\n";
close (LOG);
my $result = system("$run_wrf >> $logfile 2>&1");
my $timenow = `date -u`; chomp $timenow;
open(LOG,">>$logfile");
print LOG "$timenow: run_wrf completed with status: $result\n";
close(LOG);
unlink "$lockfile";
exit;
