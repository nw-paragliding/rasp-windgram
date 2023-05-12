#! /usr/bin/perl -w

### CHANGE HARD_WIRED BASE DIRECTORY NAMES IN WRFSI FILES FROM BUILD NAME TO LOCAL NAME
 
### SET BASE DIRECTORY for local "DRJACK" directory setup, based on location of this program
  ( $SCRIPTDIR = "$ENV{'PWD'}/${0}" ) =~ s|[\./]*/[^/]*$|| ; 
  ( $BASEDIR = $SCRIPTDIR ) =~ s|/[^/]*/[^/]*/[^/]*$|| ;
  $WRFSIDIR = "$BASEDIR/WRF/wrfsi" ;
  #4testprint: print "SCRIPTDIR= $SCRIPTDIR \n" ;
  print "Your diagnosed BASEDIR = $BASEDIR \n" ;

### DO REPLACEMENTS
  $ADMIN_BASEDIR = "/home/admin/DRJACK" ;
  ### SET FILENAME LIST (relative to $ADMIN_BASEDIR)
  ### NOTE THAT "src/include/makefile.inc" NOT INCLUDED HERE
  @filelist= ( "config_paths", "wrf_tools", "gui/guiTk/ui_system_tools.pl", "etc/localize_domain.pl", "etc/generate_images.pl", "graphics/ncl/generate_images.pl", "data/static/wrfsi.nl", "templates/default/dataroot.txt", "templates/default/wrfsi.nl" ); 
  #4test-1file: @filelist= ( "config_paths" );
  ### FOR ADMIN USE, INCLUDE OMITTED MAKEFILE TO BE SAFE
  if( -s "${WRFSIDIR}/src/include/makefile.inc" )
  {
    print "!!! Makefile src/include/makefile.inc added to file list \n";
    push @filelist,  ( 'src/include/makefile.inc' ); 
  }
  ### loop through filenames
  foreach $filename (@filelist)
  {
    $fullfilename = "${WRFSIDIR}/${filename}" ;
    #4test-revert: $fullfilename = "${ADMIN_BASEDIR}/WRF/wrfsi/${filename}" ;
    #4test-revert:  $ADMIN_BASEDIR = "/home/glendeni/DRJACK" ;
    #4test-revert:  $BASEDIR = "/home/admin/DRJACK" ;
    $originalfilename = "${WRFSIDIR}/${filename}.DOWNLOAD" ;
    if( -w $fullfilename )
    {
      if( ! -s $originalfilename )
      {
        `cp $fullfilename $originalfilename`; 
      }
      print "Altering \"${ADMIN_BASEDIR}\" to \"${BASEDIR}\" in file: $fullfilename \n";
      #4real: 
     `sed "s|$ADMIN_BASEDIR|$BASEDIR|g" $originalfilename >| $fullfilename` ;
      #4testprint: `echo "sed s|$ADMIN_BASEDIR|$BASEDIR|g $originalfilename >| $fullfilename"`; 
    }
    else
    {
      print "***ERROR: problem opening expected $fullfilename - file either does not exist OR has zero size OR does not have write permission \n";
    }
  }
