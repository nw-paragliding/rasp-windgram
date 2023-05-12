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

# Script Name:  sync_wrfnl.pl
#
# Purpose:  This script runs edits the MOAD_DATAROOT/wrf.nl file
#           to have the same dimensions, nests, and grid spacing
#           as specified in the MOAD_DATAROOT/static/wrfsi.nl
#
# Usage:
#   
#   sync_wrfnl.pl -h to see options
#
#        

require 5;
use strict;
use vars qw($opt_h);
use Getopt::Std;
print "Routine: sync_wrfnl.pl\n";
my $mydir = `pwd`; chomp $mydir;

# Get command line options
getopts('h');

# Did the user ask for help?
if ($opt_h){
  print "Usage:  sync_wrfnl.pl [options] MOAD_DATAROOT

         MOAD_DATAROOT is the directory containing the static subdirectory
         that has already been successfully localized for your domain.

          Valid Options:
          ===============================================================

          -h 
             Prints this message\n";
  exit;
}

# Need installroot so we can find the wrfsi_utils module.
my $installroot;
if (! $ENV{INSTALLROOT}){
  print "No INSTALLROOT environment variable set! \n";
  print "Attempting to use the current directory to set installroot.\n";
  my $curdir = `pwd`; chomp $curdir;
  my $script = $0;
  if ($script =~ /^(\S{1,})\/wrfprep.pl$/){
    chdir "$1/..";
  }else{
    chdir "..";
  }
  $installroot = `pwd`; chomp $installroot;
  chdir "$curdir";
  if (! -e "$installroot/bin/hinterp.exe") {
    die "Cannot determine installroot\n";
  }else{
    $ENV{INSTALLROOT} = $installroot;
  }
}else{
 $installroot = $ENV{INSTALLROOT};
}
require "$installroot/etc/wrfsi_utils.pm";

my ($moad_dataroot) = @ARGV;

# Process MOAD_DATAROOT.  Use -d argument first, followed by 
# environment variable.

# Check for a couple of critical files in moad_dataroot
my $wrfsinl = "$moad_dataroot/static/wrfsi.nl";
if (! -e "$wrfsinl"){
  die "$wrfsinl not found!  Is your MOAD_DATAROOT correct and have you 
successfully localized it with window_domain_rt.pl?\n";
}

my $wrfnl = "$moad_dataroot/static/wrf.nl";
if (! -e "$wrfnl"){
  die "$wrfnl not found! Is your MOAD_DATAROOT correct and have you
successfully localized it with window_domain_rt.pl?  If so, you may
need to copy wrf.nl from SOURCE_ROOT/data/static to $moad_dataroot/static\n";
}

print "MOAD_DATAROOT = $moad_dataroot\n";

# Read the wrfsi namelist
open (WRFSI, "$wrfsinl");
my @silines = <WRFSI>;
close(WRFSI);
my %wrfsihash = &wrfsi_utils::get_namelist_hash(@silines);
my @wrflevels = @{${wrfsihash{LEVELS}}};
my $nwrflevels = @wrflevels;
my $dx_moad = ${${wrfsihash{MOAD_DELTA_Y}}}[0];
my $dy_moad = ${${wrfsihash{MOAD_DELTA_Y}}}[0];
my $nx_moad = ${${wrfsihash{XDIM}}}[0];
my $ny_moad = ${${wrfsihash{YDIM}}}[0];
my $num_domains = ${${wrfsihash{NUM_DOMAINS}}}[0];
my @parent_ids = @{${wrfsihash{PARENT_ID}}};
my @ratio_to_parent = @{${wrfsihash{RATIO_TO_PARENT}}};
my @origin_lli = @{${wrfsihash{DOMAIN_ORIGIN_LLI}}};
my @origin_llj = @{${wrfsihash{DOMAIN_ORIGIN_LLJ}}};
my @origin_uri = @{${wrfsihash{DOMAIN_ORIGIN_URI}}};
my @origin_urj = @{${wrfsihash{DOMAIN_ORIGIN_URJ}}};
my $map_proj  = ${${wrfsihash{MAP_PROJ_NAME}}}[0];

# Create the lines for the WRF namelist edits

my ($s_we, $e_we, $s_sn, $e_sn, $s_vert, $e_vert, $dx, $dy,
    $grid_id, $level, $parent_id, $i_parent_start, $j_parent_start,
    $parent_grid_ratio, $parent_time_step_ratio);

my $dom_index = 0;
my (@dx_all, @dy_all, @nestlev);
while ($dom_index < $num_domains) {
  my $dom_num = $dom_index + 1;

  # Handle the MOAD first..
  if ($dom_index == 0){
    $s_we            = " s_we           =   1, ";
    $e_we            = " e_we           = $nx_moad, ";
    $s_sn            = " s_sn           =   1, ";
    $e_sn            = " e_sn           = $ny_moad, ";
    $s_vert          = " s_vert         =   1, ";
    $e_vert          = " e_vert         = $nwrflevels, ";
    $dx              = " dx             = $dx_moad, ";
    $dy              = " dy             = $dy_moad, ";
    $grid_id         = " grid_id        = 1, ";
    $level           = " level          = 1, ";
    $parent_id       = " parent_id      = 1, ";
    $i_parent_start  = " i_parent_start = 0, ";
    $j_parent_start  = " j_parent_start = 0, ";
    $parent_grid_ratio = " parent_grid_ratio = 1, ";
    $parent_time_step_ratio = " parent_time_step_ratio = 1, ";
    push @dx_all, $dx_moad; 
    push @dy_all, $dy_moad;
    push @nestlev, 1;
  }else{
    my $is = ${origin_lli}[$dom_index];
    my $ie = ${origin_uri}[$dom_index];
    my $js = ${origin_llj}[$dom_index];
    my $je = ${origin_urj}[$dom_index];
    my $span_x = $ie - $is;
    my $span_y = $je - $js;
    my $ratio = ${ratio_to_parent}[$dom_index];
    my $parent = ${parent_ids}[$dom_index];
    my $parent_ind = $parent - 1;
    my $xdim_dom = $span_x * $ratio + 1;
    my $ydim_dom = $span_y * $ratio + 1;
    my $dx_dom = ${dx_all}[$parent_ind]/$ratio;
    $dx_dom = int(($dx_dom * 10.)+.5)/10.;
    my $dy_dom = ${dy_all}[$parent_ind]/$ratio;
    $dy_dom = int(($dy_dom * 10.)+.5)/10.;
    my $lev_dom = ${nestlev}[$parent_ind] + 1;

    $s_we = "$s_we 1, ";
    $e_we = "$e_we $xdim_dom, ";
    $s_sn = "$s_sn 1, ";
    $e_sn = "$e_sn $ydim_dom, ";
    $s_vert = "$s_vert 1, ";
    $e_vert = "$e_vert $nwrflevels, ";
    $dx = "$dx $dx_dom, ";
    $dy = "$dy $dy_dom, ";
    $grid_id = "$grid_id $dom_num, ";
    $level = "$level $lev_dom, ";
    $parent_id = "$parent_id $parent, ";
    $i_parent_start = "$i_parent_start $is, ";
    $j_parent_start = "$j_parent_start $js, ";
    $parent_grid_ratio = "$parent_grid_ratio $ratio, ";
    $parent_time_step_ratio = "$parent_time_step_ratio $ratio, ";
    push @dx_all, $dx_dom;
    push @dy_all, $dy_dom;
    push @nestlev, $lev_dom;
  }  
  $dom_index = $dom_index + 1 ;
}

# Edit the WRF namelist

# safeguard the original
my $result = system("cp $wrfnl $wrfnl".".bak");
if ($result) { die "Could not create backup wrf.nl file!\n"; }

open (WNL, "<$wrfnl");
my @lines = <WNL>;
close(WNL);
open(WNL, ">$wrfnl");
my $wrfline;
foreach $wrfline(@lines){
  if ($wrfline =~ /^\s*?max_dom\s*?=/i){ $wrfline = " max_dom = $num_domains\n" }
  if ($wrfline =~ /^\s*?s_we\s*?=/i){ $wrfline = "$s_we\n" }
  if ($wrfline =~ /^\s*?e_we\s*?=/i){ $wrfline = "$e_we\n" }
  if ($wrfline =~ /^\s*?s_sn\s*?=/i){ $wrfline = "$s_sn\n" }
  if ($wrfline =~ /^\s*?e_sn\s*?=/i){ $wrfline = "$e_sn\n" }
  if ($wrfline =~ /^\s*?s_vert\s*?=/i) { $wrfline = "$s_vert\n" }
  if ($wrfline =~ /^\s*?e_vert\s*?=/i) { $wrfline = "$e_vert\n" }
  if ($wrfline =~ /^\s*?dx\s*?=/i ) { $wrfline = "$dx\n" }
  if ($wrfline =~ /^\s*?dy\s*?=/i ) { $wrfline = "$dy\n" }
  if ($wrfline =~ /^\s*?grid_id\s*?=/i) { $wrfline = "$grid_id\n" }
  if ($wrfline =~ /^\s*?level\s*?=/i) { $wrfline = "$level\n" }
  if ($wrfline =~ /^\s*?parent_id\s*?=/i ) { $wrfline = "$parent_id\n" }
  if ($wrfline =~ /^\s*?i_parent_start\s*?=/i ) { $wrfline = "$i_parent_start\n" }
  if ($wrfline =~ /^\s*?j_parent_start\s*?=/i ) { $wrfline = "$j_parent_start\n" }
  if ($wrfline =~ /^\s*?parent_grid_ratio\s*?=/i ) { $wrfline = "$parent_grid_ratio\n" }
  if ($wrfline =~ /^\s*?parent_time_step_ratio\s*?=/i ) { 
    $wrfline = "$parent_time_step_ratio\n"; 
  }
  print WNL "$wrfline";
}
close(WNL);
exit;
