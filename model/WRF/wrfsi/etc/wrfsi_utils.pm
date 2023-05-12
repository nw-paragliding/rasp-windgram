#!/usr/bin/perl

package wrfsi_utils;
require 5;
use strict;
use English;

sub get_namelist_hash {

  my (@orig_lines) = @_;
  my %ans;

  my (@lines, $newline);
  $newline = "";

  foreach (@orig_lines) {
    s/\s+//g;                       #clear out all whitespace
    s/\!.*//;                       #strip off comments
    if (/^&/) {next;}               #section name
    if (/^\/$/) {                   #solitary backslash at end of section
      push(@lines,$newline); 
      next;
      } 
    if (/=/) {                      #a new name; values may follow
      s/\/$//;                      #strip backslash at end of last value
      s/\'//g;                      #strip quotes
      push(@lines,$newline) if ($newline ne ""); 
      $newline = $_;
      }
    else {
      s/\'//g;
      $newline=$newline.$_;}
    }

  push(@lines,$newline);

  my ($name, $valstring, @values, %table);
  foreach (@lines) {
    ($name,$valstring) = split /=/, $_;
    $name = uc $name;
    @values = split /,/, $valstring;
    $table{$name} = [@values];
    }

  %ans = %table;
  return(%ans);

  }

#------------------------------------------------------

sub compute_time {
use Time::Local;

my ($date_in, $offset) = @_;

# Parse out year, month, day, and hour

my ($yyyy, $mm, $dd, $hh);
if ($date_in =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/) {
  $yyyy = $1;
  $mm   = $2;
  $dd   = $3;
  $hh   = $4; }
else {
  print "Unrecognized date/time in wrfsi_utils::compute_time.\n";
  exit; }

# Convert to time coordinate in seconds

my (@time);
$time[2] = $hh;
$time[3] = $dd;
$time[4] = $mm - 1;
$time[5] = $yyyy - 1900;
my $i4time = timegm(@time);

# Add offset and convert back to needed format

$i4time = $i4time + 3600*$offset;
@time = gmtime($i4time);
$yyyy = $time[5] + 1900;
$mm   = $time[4] + 1; $mm="0".$mm while (length($mm)<2);
$dd   = $time[3];     $dd="0".$dd while (length($dd)<2);
$hh   = $time[2];     $hh="0".$hh while (length($hh)<2);

my $ans = "$yyyy$mm$dd$hh";

return ($ans);

}

#------------------------------------------------------

sub compute_interval {
use Time::Local;

my ($date_beg, $date_end) = @_;

# Parse out year, month, day, and hour

my ($byyyy, $bmm, $bdd, $bhh);
if ($date_beg =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/) {
  $byyyy = $1;
  $bmm   = $2;
  $bdd   = $3;
  $bhh   = $4; }
else {
  print "Unrecognized Begdate in wrfsi_utils::compute_interval.\n";
  exit; }
my ($eyyyy, $emm, $edd, $ehh);
if ($date_end =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/) {
  $eyyyy = $1;
  $emm   = $2;
  $edd   = $3;
  $ehh   = $4; }
else {
  print "Unrecognized Enddate in wrfsi_utils::compute_interval.\n";
  exit; }

# Convert to time coordinate in seconds and compute the interval

my (@btime);
$btime[2] = $bhh;
$btime[3] = $bdd;
$btime[4] = $bmm - 1;
$btime[5] = $byyyy - 1900;
my (@etime);
$etime[2] = $ehh;
$etime[3] = $edd;
$etime[4] = $emm - 1;
$etime[5] = $eyyyy - 1900;

my $ans = timegm(@etime) - timegm(@btime);

return ($ans);

}

#------------------------------------------------------

sub convert_time {
use Time::Local;

my $date_in = shift;

my ($yyyy, $mm, $dd, $hh);
if ($date_in =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/) {
  $yyyy = $1;
  $mm   = $2;
  $dd   = $3;
  $hh   = $4; }
else {
  print "Unrecognized date/time in wrfsi_utils::convert_time.\n";
  exit; }

# Convert to time coordinate in seconds

my (@time);
$time[2] = $hh;
$time[3] = $dd;
$time[4] = $mm - 1;
$time[5] = $yyyy - 1900;
my $i4time = timegm(@time);

# Convert back to yy, dd, etc.

my @ans = gmtime $i4time;
return (@ans);

}
#------------------------------------------------------------
# convert a ".pl.in" perl script to a ".pl"
# in other words, replace @---@ with the appropriate item.
# J. Smart 6-01
#
sub make_script

{
my ($SRC_ROOT, $INSTALLROOT, $script_name, $type)=@_; 
if($type eq "laps"){
   $SRC_ROOT    = $ENV{LAPS_SRC_ROOT}   if($ENV{LAPS_SRC_ROOT}   && !defined $SRC_ROOT);
   $INSTALLROOT = $ENV{LAPSINSTALLROOT} if($ENV{LAPSINSTALLROOT} && !defined $INSTALLROOT);
}elsif($type eq "wrfsi"){
   $SRC_ROOT    = $ENV{SRCROOT}       if($ENV{SRCROOT}        && !defined $SRC_ROOT);
   $INSTALLROOT = $ENV{INSTALLROOT}   if($ENV{INSTALLROOT}    && !defined $INSTALLROOT);
}else{
   die "\nYou must use -t to specify which type:
          Use either laps or wrfsi\n\n";
}


if(!defined $SRC_ROOT || !defined $INSTALLROOT){
   print "One of the two roots is not defined. Terminating\n";
   exit;
}


my $path_to_perl=$EXECUTABLE_NAME;
if(length($path_to_perl) <=4 ){
   $path_to_perl = `which 'perl'`;
   if (length($path_to_perl) <=4){
     print "You must use the complete path to perl to run this script
            or ensure the perl executable is in your path.\n";
     exit;
   }
}
chomp $path_to_perl;
print "source root  = $SRC_ROOT \n";
print "install root = $INSTALLROOT \n";
print "script name  = $script_name \n";
print "path to perl = $path_to_perl \n";

my @lines;
if(-e "$script_name.in"){
    open(SRC,"$script_name.in");
    @lines = <SRC>;
    close SRC;
    foreach (@lines) {

       if( /\@PERL\@/ ){
           s/\@PERL\@/$path_to_perl/;
       }

       if( /\@prefix\@/ ){
           s/\@prefix\@/$INSTALLROOT/;
       }

       if (/\/NETCDF\//) {
           s/\/NETCDF\//$ENV{NETCDF}/;
       }
       if (/\@NETCDF\@/) {
           s/\@NETCDF\@/$ENV{NETCDF}/;
       }

       if( /\@configure_input\@/ ){
           s/\@configure_input\@/Generated automatically by make_script.pl/;
       }

       if( /\@top_srcdir\@/ ) {
           s/\@top_srcdir\@/$SRC_ROOT/;
       }
       if( /\@CSH\@/ ) {
           s/\@CSH\@/\/bin\/csh/;
       } 
       if (/\/PBSHOME\//) { 
           s/\/PBSHOME\//$ENV{PBS}/; 
       }
       if (/\/MPICH\//) {     
           s/\/MPICH\//$ENV{MPICH}/;
       }
    }
  open(OUT,">$script_name");
  foreach (@lines) {print OUT "$_";}
  close OUT;
}else{
  print "The script name you entered does not exist\n";
  print "Try entering the script name without .in\n";
}
return;
}
sub qsub_hms2sec {
  my $expind = 0;
  my $remainder = shift;
  my $sec = 0;
  while (length($remainder)>0){
    if ($remainder =~ /(\d*)$/) {
      $sec = int($sec + ($1 * (60 ** $expind)));
      $remainder = $`;
      if ($remainder =~ /(:)$/) {$remainder = $`}
      $expind++;
    }
  }
  return ($sec);
  }
sub mk_makefile {

  my ($SRCROOT) = @_;
# my $ARCHITECTURE=$ENV{MACHTYPE};
  my $uname =  `uname -a`;
  my @components = split(' ',$uname);
  my $MACHTYPE = lc @components[0];
  open (MFI, ">$SRCROOT/gui/src/makefile.inc");
  print MFI "# Used by the gui/src/Makefile\n";
  print MFI "# If MACHTYPE does not contain Intel i386, i686 or Alpha use -DBYTE_SWAP\n#\n";
#  if($MACHTYPE eq 'linux')
#  {
            if($uname =~ /86|alpha/i ){
                print MFI "# BYTEFLAG = -DBYTE_SWAP\n";
                print MFI "BYTEFLAG =\n";
            } else {                              # Architecture is Big Endian
                print MFI "BYTEFLAG = -DBYTE_SWAP\n";
            }
#  }
  close (MFI);
  return;
}
