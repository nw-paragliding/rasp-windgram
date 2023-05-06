#!/usr/bin/perl
#Script developed for use when installing the WRFSI GUI software.  
#           John Smart        Dec 2000 Original install_wrfsi.pl
#           Paula McCaslin 12 Dec 2002 Original install_gui.pl
#
require 5.00503;
umask 002;
use strict;
use English;
use Getopt::Long;
use Cwd;

my($INSTALLROOT,$SOURCE_ROOT,$UI_TEMPDIR,$helpme);

#---------------
# Set up some default roots before the help option, so that we
# capture the use of SOURCE_ROOT, INSTALLROOT, etc
# environment variables if set
my ($defsrcroot, $definstallroot, $defuitempdir);

# If srcroot was not specfied, then try and determine source root
# based on the knowledge that the install_wrfsi.pl script is usually
# found in the SRCROOT.

print " source_root is $ENV{SOURCE_ROOT} \n";

if ($ENV{SOURCE_ROOT}) {
  $defsrcroot=$ENV{SOURCE_ROOT};
}else{

  if (($0 eq "install_gui.pl") or ($0 eq "./install_gui.pl")) {
    chdir "..";
    $defsrcroot = cwd;
  }else{
    if ($0 =~ /S*\/install_gui.pl/){
      $defsrcroot = $`;
      chdir "$defsrcroot";
      chdir "..";
      $defsrcroot = cwd;
    }else{
      die "Problem determining srcroot.  Either specify --source_root or
           run from within the source directory!\n";
    }
  }
}
  $SOURCE_ROOT=$defsrcroot;

if ($ENV{INSTALLROOT}){
  $definstallroot=$ENV{INSTALLROOT};
}else{
  $definstallroot=$defsrcroot;
}
  $INSTALLROOT=$definstallroot;

if ($ENV{UI_TEMPDIR}){
  $defuitempdir=$ENV{UI_TEMPDIR};
}else{
  $defuitempdir="/tmp";
}
  $UI_TEMPDIR=$defuitempdir;

#---------------

my $result = GetOptions("installroot=s" => \$INSTALLROOT,
                       "source_root=s"  => \$SOURCE_ROOT,
                       "ui_tempdir=s" => \$UI_TEMPDIR,
                       "help" => \$helpme);
#---------------

if ($helpme) {
  print "
WRFSI GUI Installation Script Usage:

perl install_gui.pl [options]

  Valid Options:

    --installroot=INSTALLROOT
      Top level directory to install code executable scripts/programs
      DEFAULT: $definstallroot
      (Supercedes INSTALLROOT environment variable)

    --source_root=SOURCE_ROOT   
      Source root (contains src subdirectory)
      DEFAULT: $defsrcroot
      (Supercedes SOURCE_ROOT environment variable)

    --ui_tempdir=UI_TEMPDIR
      Scratch directory for files created by the user interface. 
      DEFAULT: $defuitempdir
      (Supercedes UI_TEMPDIR environment variable)

Typical Installation:

 perl install_gui.pl --source_root=/usr/nfs/wrfsi --installroot=/usr/nfs/wrfsi

This will install the gui code in the gui subdirectory of the
source directory created when you untarred the file.\n"; 

exit;
}

# Main
# ----
print "\n\nInstalling WRFSI GUI\n\n";
$|=1; # Set autoflush on to disable buffering.


open (LOG, ">> $SOURCE_ROOT/gui/gui_install.log");
print LOG "Starting install_gui.pl\n\n";
require "$SOURCE_ROOT/etc/wrfsi_utils.pm";

my $PATH_TO_PERL='/usr/bin/perl';

# Make directories and copy files to installroot, if necessary.
#--------------------------------------------
chdir "$INSTALLROOT";
foreach my $gui_dir ("gui", "gui/bin") {
   if(!-e "$INSTALLROOT/$gui_dir" ){ mkdir "$INSTALLROOT/$gui_dir", 0777 or 
           die "Won't mkdir $INSTALLROOT/$gui_dir $!\n";
   }
}

# Copy files to installroot, if necessary.
#--------------------------------------------
foreach my $gui_file ("gui/guiTk") {
   if(!-e "$INSTALLROOT/$gui_file" ){
       system("cp -Rf $SOURCE_ROOT/$gui_file $INSTALLROOT/$gui_file");
   }
}

# Link files with installroot, if necessary.
#--------------------------------------------
foreach my $gui_file ("gui/data") {
   if(!-e "$INSTALLROOT/$gui_file" ){
       system("ln -s $SOURCE_ROOT/$gui_file $INSTALLROOT/$gui_file");
   }
}

# Modify gui script (as indicated) in gui/guiTk
# ------------------------------------------------------
my $type='wrfsi';

chdir "$SOURCE_ROOT/gui/guiTk";
my (@perl_scripts) = qw(ui_system_tools.pl);
 
foreach my $script (@perl_scripts) {
   &wrfsi_utils::make_script($SOURCE_ROOT, $INSTALLROOT, $script, $type);
   chmod 0775, "$SOURCE_ROOT/gui/guiTk/$script";
  if($SOURCE_ROOT ne $INSTALLROOT){
    system("cp $SOURCE_ROOT/gui/guiTk/$script $INSTALLROOT/gui/guiTk/.");
  }
}

chdir "$SOURCE_ROOT/gui";
my $script="install_perlTk.sh";
&wrfsi_utils::make_script($SOURCE_ROOT, $INSTALLROOT, $script, $type);
chmod 0775, "$script";


# Check for installation of code by listing files.
# ------------------------------------------------------
print LOG "\nCheck configure in $INSTALLROOT/gui/guiTk\n";
system("ls -rtal $INSTALLROOT/gui/guiTk/*.pl 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1");
print LOG "\nCheck installation in $INSTALLROOT/gui\n";
system("ls -rtal $INSTALLROOT/gui 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1");

# Create the gui/src/makefile.inc by inserting
# a BYTE_SWAP compile switch in gui/src/Makefile as necessary.
# ------------------------------------------------------
&wrfsi_utils::mk_makefile($SOURCE_ROOT);


# Make the binaries.
# ------------------------------------------------------
chdir "$SOURCE_ROOT";
print LOG "\nMakefile output.\n";
system("make cgui 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1");
system("make cguiinstall 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1");
if( -e "$INSTALLROOT/gui/bin/pwrap_ll_xy_convert.exe" &&
    -e "$INSTALLROOT/gui/bin/gen_map_bkgnd.exe" ){
   print "\nBinaries used in GUI successfully installed\n";
   system("ls -rtal $INSTALLROOT/gui/bin");
} else {
   print "\nBinaries used in GUI not installed\n";
   open(MIO,"$SOURCE_ROOT/gui/gui_install.log");
   my @mio=<MIO>;
   close(MIO);
   foreach(@mio){next if !/error/i && !/ignored/i;
                print "$_\n";}
   print "\n";
} 

# Check for installation of Perl/Tk by running perl with 'use Tk'.
# ------------------------------------------------------
chdir "$SOURCE_ROOT/gui";
print "\nWRF SI gui build complete.  Next step(s):\n";
print "\to Determine if Perl/Tk is installed.\n";
print LOG "\n\nWRF SI gui build complete.  Next step(s):\n";
print LOG "\to Determine if Perl/Tk is installed.\n";

my $sys_call_arg="$PATH_TO_PERL -e 'use Tk'";
my $ans=system("$sys_call_arg 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1");
print "\to Perl/Tk is available on system if status=0. Status=$ans for '$sys_call_arg'\n\n";
print LOG "\to Perl/Tk is available on system, if status=0. Status=$ans for '$sys_call_arg'\n\n";


my $opt_perl="-Mblib=$SOURCE_ROOT/gui/perlTk/blib";
if ($ans != 0) {
# Perl/Tk is not included with the standard system perl libraries, i.e. @INC. 
# You want Version 800.023 or higher.
 
    # Make directory, if necessary.
    my $gui_dir="$SOURCE_ROOT/gui/perlTk";
    if(!-e "$gui_dir"){ mkdir "$gui_dir", 0777 or die "Won't mkdir $gui_dir $!\n";}

    # Check $SOURCE_ROOT for a user installed perlTk/blib directory. 
    my @perltk_found="";
    @perltk_found=`find perlTk/blib -name Tk.pm`;

    if (@perltk_found) {
       # Perl/Tk is installed.
    } else {
       # Install Perl/Tk.
       print "\to Perl/Tk not found; \n";
       print "\t  Installing Perl/Tk now, in addition to the WRFSI GUI; \n";
       print "\t  This could take 10 mins; \n";
       print "\t  Successful test of Perl/Tk installation will cause windows to \n";
       print "\t  flash (i.e. display and quickly disappear) on your screen.\n";
 
       print LOG "\to Perl/Tk not found; installing now (this takes 10 mins...)\n";
       $ENV{SOURCE_ROOT}=$SOURCE_ROOT; 
       system("$SOURCE_ROOT/gui/install_perlTk.sh 1> perlTk_install.log 2>&1");
    }

    # Test installation of Perl/Tk.
    $ENV{PERL5OPT}=$opt_perl; 
    my $ans2=system("$sys_call_arg 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1");
    print "\nPerl/Tk has been built in the SOURCE_ROOT directory. \n";
    print LOG "\nPerl/Tk has been built in the SOURCE_ROOT directory. \n";
   
    if ($ans2 == 0) {
       # Success.
       if (-d "$SOURCE_ROOT/gui/Tk800.023") { 
          system("rm -rf $SOURCE_ROOT/gui/Tk800.023"); };
       print "\to To use this version set env variable PERL5OPT to the following value\n";
       print "\t 'setenv PERL5OPT $opt_perl'.\n";
       print LOG "\to To use this version set env variable PERL5OPT to the following value\n";
       print LOG "\t 'setenv PERL5OPT $opt_perl'.\n";

    } else {

       # Fail.
       print "\to Perl/Tk FAILURE, installation failed or could be corrupt:\n";
       print "\t\t $SOURCE_ROOT/gui/perlTk\n";
       print "\to Exiting install_gui.pl with error status.\n";
       print LOG "\to Perl/Tk FAILURE, installation failed or could be corrupt:\n";
       print LOG "\t\t $SOURCE_ROOT/gui/perlTk\n";
       print LOG "\to Exiting install_gui.pl with error status.\n";
       # Exit on error.
       exit;
    };

}
$sys_call_arg="$PATH_TO_PERL -v | grep version";
system("$sys_call_arg 2> /dev/null");                              # for output to screen.
system("$sys_call_arg 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1"); # for output to LOG file.
$sys_call_arg="$PATH_TO_PERL -e 'use Tk; print \"\to This is perl/Tk, version \$Tk::VERSION installed in library \$Tk::library\"' ";
system("$sys_call_arg 2> /dev/null");                              # for output to screen.
system("$sys_call_arg 1>> $SOURCE_ROOT/gui/gui_install.log 2>&1"); # for output to LOG file.

my $ifile="$INSTALLROOT/wrf_tools";
my $ofile="$UI_TEMPDIR/wrf_tools.log";
print "\n\nThe Perl/Tk installation is successful.  Next step:\n";
print "\to Run $ifile to set up wrfsi.\n\n";
print LOG "\n\nThe Perl/Tk installation is successful.  Next step:\n";
print LOG "\to Run '$ifile' to set up wrfsi.\n";
 
# Create INSTALLROOT/wrf_tools script to launch the WRFSI GUI. 
# ------------------------------------------------------
open (SRT, ">$ifile");
print SRT "#!$PATH_TO_PERL\n";
print SRT "# Script to launch the WRFSI GUI.\n#\n";
print SRT "umask 000;\n";
if ($ans) { 
  print SRT "\$ENV{PERL5OPT}='$opt_perl';\n"; 
} else {
  print SRT "# \$ENV{PERL5OPT}='$opt_perl';\n\n";
}
print SRT "my \$ans=system(\"$INSTALLROOT/gui/guiTk/ui_system_tools.pl 1> $ofile 2>&1\");\n";
print SRT "if (\$ans) { print \"Look at file $ofile\\n\"; };\n";
print SRT "exit;";
close (SRT);
chmod 0775, "$ifile";

 
# Create gui/guiTk/demo script to test the WRFSI GUI. 
# ------------------------------------------------------
#my $ifile="$INSTALLROOT/gui/guiTk/demo";
#open (SRT, ">$ifile");
#print SRT "#!$PATH_TO_PERL\n";
#print SRT "# Script to test the WRFSI GUI.\n#\n";
#print SRT "umask 000;\n";
#if ($ans) { 
#  print SRT "\$ENV{PERL5OPT}='$opt_perl';\n"; 
#} else {
#  print SRT "# \$ENV{PERL5OPT}='$opt_perl';\n\n";
#}
#print SRT "my \$ans=system(\"$INSTALLROOT/gui/guiTk/srt_demo.pl 1> $ofile 2>&1\");\n";
#print SRT "if (\$ans) { print \"Look at file $ofile\\n\"; };\n";
#print SRT "exit;";
#close (SRT);
#chmod 0775, "$ifile";

# Run test demo.
# ------------------------------------------------------
#if( -e "$INSTALLROOT/gui/guiTk/demo") { 
#     print "\to Running test demo $INSTALLROOT/gui/guiTk/demo\n";
#     print LOG "\to Running test demo $INSTALLROOT/gui/guiTk/demo\n\n";
#     $ans=system ("$INSTALLROOT/gui/guiTk/demo &"); 
#     if ($ans != 0) {
#        print "\n\to Is status non-zero? Status=$ans for '$sys_call_arg'\n";
#        print LOG "\to Is status non-zero? Status=$ans for '$sys_call_arg'\n";
#     }
#}
close (LOG);


# Fini.
# ----
exit;

__END__
