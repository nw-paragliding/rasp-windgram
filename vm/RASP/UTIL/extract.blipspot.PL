#! /usr/bin/perl -w

if ( $#ARGV < 4 || $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Extract+print BlipSpot info for \$1=region site  \$2=grid# \$3=day(-1/0/1/2)|yyyymmdd(archive) \$4,5=i,j(integer)_or_lat,lon(decimal) \$6=LINFO <\$*=time/param>\n";
print "  eg for latest previous day data:   extract.blipspot.PL PANOCHE d2 0 10 10 1\n";
print "  eg for archive file: extract.minispot.pl PANOCHE w2 20070901 10 10 1\n";
print "  eg for selected time & param:   extract.blipspot.PL PANOCHE d2 0 10 10 0 1300lst wstar\n";
print "  optional trailing arguments set time (must include number) or parameter - else are internally set \n";
print "  input grid# can be 1,2,3 or d1,d2,w2\n";
print "  input LINFO =0 to return numerical results only, sans text\n";
print "  (reads blipmap datafiles, not wrf output file)\n";
print "  (requires region params in file extract.blipspot.site_params.PL)\n";
exit 0; }
#########################################################################
### FOR DEBUG MODE: run with -d flag  (but not for neptune)
### In debug mode, set package name + local variables so X,V don't show "main" variables, ie:
# package Main; local ($a,$b,...);
### To enable verbose diagnostics (but not for CRAY):
#   use diagnostics;
### To restrict unsafe constructs (vars,refs,subs)
###    vars requires variables to be declared with "my" or fully qualified or imported
###    refs generates error if symbolic references uses instead of hard refs
###    subs requires subroutines to be predeclared
#    use strict;
### To provide aliases for buit-in punctuation variables (p403)
    use English;
#########################################################################

### NOTE: SCRIPTS ij2latlon.PL & latlon2ij.PL MUST BE IN SAME DIRECTORY

### MODIFIED FROM BLIP extract.minispot.PL
### change model->region region->grid

  my $programname = 'extract.blipspot';

  ### DETERMINE SCRIPT DIRECTORY - this should be automatic but can over-ride here if necessary
  ###  require latlon<->ij conversion scripts to be in current directory
  if( $0 =~ m|^/| ) { ( $SCRIPTDIR = "${0}" ) =~ s|/[^/]*$|| ; }
  else              { ( $SCRIPTDIR = "$ENV{'PWD'}/${0}" ) =~ s|[\./]*/[^/]*$|| ; }

  ### PARSE INPUT ARGUMENT
  $REGION = $ARGV[0];
  shift;
# add a place for the name of the place to be printed out in the title.  tj
  $SITE = $ARGV[0]; 
  shift;
  
  #this arg was added by tj but appears unused
  #the line below should prevent a warning
  $SITE = $SITE;
  
  $GRID = $ARGV[0];
  shift;
  $DAY = $ARGV[0];
  shift;

  ### PARSE GRID LOCATION - can be lat,lon (decimal) or i,j (integer)
  ### allow location to be either grid pt (integer) or lat,lon
  if( $ARGV[0] !~ m|\.| && $ARGV[0] !~ m|\.| )
  {
    $IGRID = $ARGV[0]; 
    $JGRID = $ARGV[1];
    $result = `$SCRIPTDIR/ij2latlon.PL $REGION $GRID $IGRID $JGRID` ;
    my $tail ;
    ( $alat,$alon, $tail ) = split /\s+/, $result ;
  }
  else
  {
    $alat = $ARGV[0] ; 
    $alon = $ARGV[1] ;
    ### assume latlon2ij utility to be in same directory as this script
    $result = `$SCRIPTDIR/latlon2ij.PL $REGION $GRID $alat $alon` ;
    my $tail ;
    ( $aigrid,$ajgrid, $tail ) = split /\s+/, $result ;
    $IGRID = nint( $aigrid );
    $JGRID = nint( $ajgrid );
  }
  shift; shift;

  ### PARSE INFORMATION FLAG  
  $LINFO = $ARGV[0];
  shift;

  ### PARSE OPTIONAL TIME/PARAM ARGUMENTS   
  while ( $#ARGV > -1 )
  {
    if( $ARGV[0] =~ m|[0-9]| )
    { push @timedolist, $ARGV[0]; }
    else
    { push @paramdolist, $ARGV[0]; }
    shift;
  }

  ### DETERMINE IF FOR ACTIVE OR ARCHIVED DATA
  if ( $DAY < 3 ) 
  {  $LARCHIVE=0; }
  else
  {  $LARCHIVE=1; }

  ### ensure region is upper-case
  $REGION =~ tr/a-z/A-Z/;

  #4test (ruc-canv@2,2): $REGION='PANOCHE' ; $GRID = 'd2' ; $DAY=0 ; $IGRID = 10 ; $JGRID = 12 ;

  ### SET SITE DEPENDENT VARIABLES (use separate file to avoid tar update overwrite)
  
   require "$SCRIPTDIR/extract.blipspot.site_params.PL" ;

########################################################################################3

  ###### INITIALIZATION
  $mapinfo = '';
  if ( $REGION =~ m|\+[0-9]| )
  {
	my $tail ;
	($tail, $currN) = split /\+/, $REGION;
	${CURRDAY} = "curr+${currN}." ;
  }
  else
  {
	${CURRDAY} = 'curr.' ;
  }
  $blankdata = '     ' ;

  ### SET PARAMETER INFO  # these can be changed outside this script as well
  $info{hbl}        = '   BL_Top_TI=0'; 
  $info{dbl}        = '      BL_Depth';
  $info{hwcrit}     = ' MaxSoar1.1m/s'; 
#  $info{dwcrit}    = '  Hlift_Depth' ;
  $info{'dwcrit'}   = '   MaxSoar_AGL'; 
  $info{hglider}    = '  MaxSoar_clds'; 
  $info{wstar}      = 'W*        ';
  $info{sfcshf}     = '   Sfc_Heating'; 
  $info{bltopvariab}= '   Hgt_Variab_'; 
  $info{bsratio}    = 'Bouy/Shr_Ratio'; 
  $info{blwindspd}  = ' Avg_BLWindSpd'; 
  $info{blwinddir}  = ' Avg_BlWindDir'; 
  $info{blwindshear}= '    Wind_Shear'; 
  $info{wblmaxmin}  = 'cm/s Converge '; 
  $info{cape}       = '  CAPE_TSpoten'; 
  $info{zsfclcldif} = '      CUpoten '; 
  $info{zsfclcl}    = '    CUbase_LCL'; 
  $info{zblcldif}   = '   ODpot_if_cu'; 
  $info{zblcl}      = 'ODbase_allclds'; 
  $info{blcloudpct} = '     BL_Cloud%'; 
  $info{sfctemp}    = '       Temp@2m'; 
  $info{sfcdewpt}   = '      DewPt@2m'; 
  $info{sfcsun}     = '       Sfc_Sun' ;
  $info{sfcsunpct}  = '     Sfc_Sun_%' ;
  $info{sfcwind0spd} = 'Sfc_Wind_Sp_Kt' ;
  $info{sfcwindspd} = 'Treetop_WSp_Kt' ;
  $info{sfcwind2spd} = 'Lev_Abv_WSp_Kt' ;
  $info{tenmwindspd}= '10M_Wind_Sp_Kt' ;
  $info{tenmwinddir}= ' 10M_Wind_Dir ' ;
  $info{sfcwind0dir} = '     Sfc_W_Dir' ;
  $info{blcloudpct} = '    BL_Cloud_%' ;
  $info{blcwbase}   = '    BL_CW_Base' ;
$info{bltopwindspd} = '    BLTop_WdSp' ;
$info{bltopwinddir} = '     BLTopWDir' ;
  $info{mslpress}   = '  msl_pressure' ;
  $info{rain1}      = '  1hr_rain_acc' ;
 
$blankdata = '-' ;

  #notneeded ### SET ANY PARAMS WHICH NEED DE-NORMALIZATION
  #notneeded ### (undefined means value used as stored, =1 removes multiplier used)
  #notneeded $denorm{sfctempf} = 1;

  ###### READ NECESSARY PARAMETER DATA
  ### LOOP OVER POSSIBLE REGION TIMES
  foreach $time (@timedolist)
  {
    ### LOOP OVER PARAMETERS
    $nparams = 0;
    foreach $param (@paramdolist)
    {
      ### initialize print output
      $prtspot{$param}{$time}  = $blankdata ;
      ### initialize denormalization if not already set
      if( ! defined $denorm{$param} ) { $denorm{$param} = 0; }
      ### OPEN FILE if available
      if ( $LARCHIVE == 0 )
      {
        if ( $DAY >= 0 )
        {
          $datafilename = "$DATADIR/${param}.${CURRDAY}${time}.${GRID}.data";
          #old $filename = "";
        }
        else
        {
          $datafilename = "$DATADIR/previous.${param}.${CURRDAY}${time}.${GRID}.data";
          #old $filename = "";
        }
      }
      else
      {
        ### need archive year subdirectory yyyy
        $yyyy = substr( $DAY, 0, 4 ) ; 
        ### hardwire to choose 6hr forecast result
        $datafilename = "$DATADIR/$yyyy/$DAY/${param}.${CURRDAY}${time}.${GRID}.data";
        #old $datafilename = "$DATADIR/$yyyy/$DAY/${param}.${CURRDAY}${time}.${GRID}.data.zip";
        #old $filename = '' ;
      }
      ### read data pt
      $value = &read_datafile_pt ( $datafilename, $IGRID,$JGRID, $denorm{$param} );
      #old $value = &read_datafile_pt ( $datafilename,$filename, $IGRID,$JGRID, $denorm{$param} );
      ### extracted forecast period is global variable 
      $forecastpd{$time} = $fcstpd ;
      ### skip if no value
      if( ! defined $value ) { next; }
      #4testprint: print "READ_DATAFILE_PT: $datafilename, $IGRID,$JGRID => $value \n";     
      $prtspot{$param}{$time}  = $value;
      $nparams++;
    ### END OF LOOP OVER PARAMETERS
    }
  ### END OF LOOP OVER POSSIBLE REGION TIMES
  }

  ###### DO PRINTING
  if( $LINFO != 0 )
  {
    ### STANDARD PRINT - with additional info
    ### print header
    print " BLIPSPOT:  ${mapinfo}\n";
    print "$REGION $GRID gridpt= ${IGRID},${JGRID}\n";
    printf "Lat,Lon= %.3f,%.3f\n",  $alat,$alon ;
    #old print "BLIPSPOT: $REGION $GRID gridpt= ${IGRID},${JGRID}\n";
    #old print " ${mapinfo}\n";
    ### this is the first header line - if has initial white space likely the mapinfo extraction is bad
    $headerborder = "------------";
    foreach $time (@timedolist)
    {
      $headerborder  .= '--------';
      #old $headerborder  .= '-------';
    }
    #add trailing parameter id column
    if( $#timedolist > 0 ) { $headerborder = $headerborder . "-------------"; }
    print "${headerborder}\n";
    ### print validation times
    $printline = sprintf "%11s  ", 'VALID.TIME';
    #unused $printline2 = sprintf "%11s  ", '----------';
    foreach $time (@timedolist)
    {
      $printline  .= sprintf "%6s ",  $time;
      #old $printline  .= sprintf "%s ",  $time;
      #unused $printline2 .= sprintf "%6s ",  ' -----';
    }
    #add trailing parameter id column
    if( $#timedolist > 0 ) { $printline .= sprintf " %-11s",'VALID.TIME'; }
    print "$printline\n"; 
    ### print forecast period
    $printline = sprintf "%11s  ", 'ForecastPd';
    #unused $printline2 = sprintf "%11s  ", '----------';
    foreach $time (@timedolist)
    {
      $printline  .= sprintf "%6sh ",  $forecastpd{$time};
      #old $printline  .= sprintf "%5sh ",  $forecastpd{$time};
      #unused $printline2 .= sprintf "%6s ",  ' -----';
    }
    #add trailing parameter id column
    if( $#timedolist > 0 ) { $printline .= sprintf " %-11s",'ForecastPd'; }
    print "$printline\n"; 
    ### this is the final header line
    print "${headerborder}\n";
    #old print "------------------------------------------------------------\n";
    #unused print "$printline2\n"; 
    ### LOOP OVER PARAMETERS
    foreach $param (@paramdolist)
    {
      ### create header for each parameter line
      $printline = sprintf "%11s  ", $info{$param};
      ### LOOP OVER POSSIBLE REGION TIMES
      foreach $time (@timedolist)
      {
        $printline .= sprintf "%7s ",  $prtspot{$param}{$time};
        #old $printline .= sprintf "%6s ",  $prtspot{$param}{$time};
      }
      #add trailing parameter id column
      if( $#timedolist > 0 ) { $printline .= sprintf " %-11s",$info{$param}; }
      print "$printline\n"; 
    }
  }
  else
  {
    ### PRINT ONLY NUMERICAL PARAMETER VALUES (all times on one row for each parameter, ala table)
    foreach $param (@paramdolist)
    {
      foreach $time (@timedolist)
      {
        $printline .= sprintf "%s ",  $prtspot{$param}{$time};
      }
     $printline .= "\n"; 
    }
    print "$printline"; 
  }
         
### eliminated calc+print of "trigger temperature"
## add it back  from 9/6/08 scripts
 ### ADD TRIGGER TIME/TEMP CALC/PRINT to BLIPSPOT
 ### SET DESIRED TRIGGER DEPTH (units=ft/m ala local site)
   #EXAMPLE_TRIGGER_DEPTH=none:  @trigdepthdolist = ( );
   #EXAMPLE_TRIGGER_DEPTH=american(ft):  
  @trigdepthdolist = ( 300,500,1000,1500, 2000, 2500, 3000 );
   #EXAMPLE_TRIGGER_DEPTH=metric(m):    @trigdepthdolist = (  400, 600, 800, 1000 );
   #old @trigdepthdolist = ( 2000, 3000, 4000, 5000 );

# add test for EBEY to avoid wierd errors 
if( $REGION eq 'EBEY' ) {
#EXAMPLE_TRIGGER_DEPTH= 0;
    @trigdepthdolist = ( );
    }
 
 if( $#trigdepthdolist > -1 )
 {
   ### set desired parameters
#   @triggertempparamdolist = ( "dwcrit");     
   @triggertempparamdolist = ( "dwcrit");     
   #  ,"dbl" );
   #4test:   @triggertempparamdolist = ( "dbl" );
   #4test:   @trigdepthdolist = ( 3000, 4000 );
   ### create header for trigger temp printout  tj modify title string for trigger temp section
   print "\n${headerborder}\n";
   print "Trigger_Time\<\/td\>\<td class=\"bl\"\>&&nbsp;2m&nbsp;Sfc\<\/td\>\<td class=\"bl\"\>Temp&nbsp;\<\/td\>\<td class=\"bl\"\>For times:\<\/td\>\<td class=\"bl\"\>+++=earlier<td class=\"bl\"\> --- =not found)\<\/td\> \n";
#   print " Trigger Time & 2m Surface Temperature &nbsp;&nbsp; For time +++=before first time,  --- = not found) \n";
   #old=blip print " TRIGGER TIME (z) & SURFACE (2m) TEMPERATURE [degF] \n (+++ if before first time, --- if not within forecast span) \n";
 #old  $delimiter = '--------------------' ; 
 #old  print $delimiter ; 
   print "${headerborder}\n";
   foreach $param (@triggertempparamdolist)
   {
     ### dwcrit is not output to a datafile so must create it here if needed
     if( $param eq 'dwcrit' )
     {
       $info{'dwcrit'} = 'MaxSoarAGL'; 
#       $info{'dwcrit'} = 'Hcrit Depth'; 
       foreach $time (@timedolist)
       {
 ### error_log occasionally says 'Argument "     " isn't numeric in subtraction (-)'  here ???
 ### so added if test
	   #### still does so when it can't find the data files and want to put a -
		   
        if( $prtspot{'hbl'}{$time} !~ m|^- *$| && $prtspot{'hbl'}{$time} !~ m|^- *$| )
         {
           $prtspot{dwcrit}{$time} = $prtspot{'hwcrit'}{$time} - ( $prtspot{'hbl'}{$time} - $prtspot{'dbl'}{$time} );     
         }
         else 
         {
           $prtspot{dwcrit}{$time} = $blankdata ;
         }
       }
     }
     ### create header for each parameter line
     $printheaderline = sprintf "%11s =", $info{$param};
     $printline1 = sprintf "%11s =", "     Hour";
     $printline2 = sprintf "%11s =", " Sfc.Temp";
     #old=blip $printheaderline = sprintf "%11s =", $info{$param};
     #old=blip $printline = sprintf "%10s", "";
     foreach $trigdepth (@trigdepthdolist)
     {
       ### LOOP OVER POSSIBLE MODEL TIMES TO DO CALC
       $itime = 0 ;    
       $triggerhr = -1. ;
       $triggertemp = -1. ;
       foreach $time (@timedolist)
       {
         ### ignore times after soln found
         if( $prtspot{$param}{$time} !~ m|^ *$| && $prtspot{$param}{$time} > $trigdepth )
         {
           ### treat first time specially
           if( $itime > 0 )
           {
             ### adjust time to allow for day switchover
             ### remove non-numbers from time
             ( $calctime = $time ) =~ s|[a-zA-Z]||g ; 
             ( $testtime = $timedolist[0] ) =~ s|[a-zA-Z]||g ; 
             if( $calctime < $testtime ) { $calctime += 2400. ; }
             ### convert to hour
             $calchr = (substr($calctime,0,length($calctime)-2)) + (substr($calctime,length($calctime)-2,2))/60.;
             #old=blip $calctime = $time ; 
             #old=blip if( $time < $timedolist[0] ) { $calctime += 24. ; }
             $triggerhr = $lastcalchr + ( ( $trigdepth - $lastdepth )*( $calchr - $lastcalchr )/( $prtspot{$param}{$time} - $lastdepth ) ) ;
             $triggertemp = $lastsfctemp + ( ( $trigdepth - $lastdepth )*( $prtspot{"sfctemp"}{$time} - $lastsfctemp )/( $prtspot{$param}{$time} - $lastdepth ) ) ;
           }
           else
           {
             $triggerhr = -2. ;
             $triggertemp = -2. ;
           }
           last; 
         }
         $lastdepth = $prtspot{$param}{$time} ;
         $lastsfctemp = $prtspot{"sfctemp"}{$time} ;
         ( $lastcalctime = $time ) =~ s|[a-zA-Z]||g ; 
         ( $testtime = $timedolist[0] ) =~ s|[a-zA-Z]||g ; 
         if( $lastcalctime < $testtime ) { $lastcalctime += 2400. ; }
         $lastcalchr = (substr($lastcalctime,0,length($lastcalctime)-2)) + (substr($lastcalctime,length($lastcalctime)-2,2))/60.;
         #old=blip $lastcalctime = $time ;
         #old=blip if( $time < $timedolist[0] ) { $lastcalctime += 24. ; }
         $itime++ ;    
       }
       ### convert results to printable strings
       if( $triggerhr > 0 )
       {
          ### adjust time to allow for day switchover
          if( $triggerhr > 24. ) { $triggerhr -= 24. ; } 
          ### convert triggerhr to hhmm (Zulu)
          $hrint = int( $triggerhr ) ;
          $minint = int( 60* ($triggerhr - $hrint ) );
          $triggerhrprt = sprintf "%02i:%02i",$hrint,$minint ;
          #old $hrdecimal = $triggerhr - $hrint ;
          #old triggerhrprt = int( 100*$hrint + 60*$hrdecimal ) ;
          #old $triggerhrprt = sprintf "%4iz",$triggerhrprt ;
          $triggertempprt = sprintf "%5.1f", $triggertemp ;
       }
       elsif ( $triggerhr == -2. )
       {
          ### for result prior to first time
          $triggerhrprt = '  +++' ;
          $triggertempprt = '  +++' ;
       }
       elsif ( $triggerhr == -1. )
       {
          ### for result not within time span
          $triggerhrprt = '  ---' ;
          $triggertempprt = '  ---' ;
       }
       $printheaderline .= sprintf " %5.0f ",  $trigdepth ;
       $printline1 .= sprintf " %5s ",  $triggerhrprt ;
       $printline2 .= sprintf " %5s ",  $triggertempprt ;
       #old=blip $printheaderline .= sprintf " %5.0f       ",  $trigdepth ;
       #old=blip $printline .= sprintf "%5s %5s  ",  $triggerhrprt, $triggertempprt ;
       #older=blip $printheaderline .= sprintf "%5.0f ft     ",  $trigdepth ;
       #4test: $printline .= sprintf " %6.2f %6.1f",  $triggerhr, $triggertemp ;
     }
     print "$printheaderline\n"; 
     print "$printline1\n"; 
     print "$printline2\n"; 
     #old=blip print "$printline\n"; 
     print "${headerborder}\n";
   }
 }

  ### SET DESIRED TRIGGER DEPTH (units=ft/m ala local site)
  #EXAMPLE_TRIGGER_DEPTH=none:  @trigdepthdolist = ( );
  #EXAMPLE_TRIGGER_DEPTH=american(ft):  
  @trigdepthdolist = ( 1500, 2000, 2500, 3000 );
  #EXAMPLE_TRIGGER_DEPTH=metric(m):    @trigdepthdolist = (  400, 600, 800, 1000 );
  #old @trigdepthdolist = ( 2000, 3000, 4000, 5000 );

  if( $#trigdepthdolist > -1 )
  {
    ### set desired parameters
    @triggertempparamdolist = ( "dwcrit","dbl" );
    #4test:   @triggertempparamdolist = ( "dbl" );
    #4test:   @trigdepthdolist = ( 3000, 4000 );
    ### create header for trigger temp printout
    print "\n${headerborder}\n";
    print " TRIGGER TIME & SURFACE (2m) TEMPERATURE \n (+++ = before first time, --- = not found) \n";
    #old=blip print " TRIGGER TIME (z) & SURFACE (2m) TEMPERATURE [degF] \n (+++ if before first time, --- if not within forecast span) \n";
  #old  $delimiter = '--------------------' ; 
  #old  print $delimiter ; 
    print "${headerborder}\n";
    foreach $param (@triggertempparamdolist)
    {
      ### dwcrit is not output to a datafile so must create it here if needed
      if( $param eq 'dwcrit' )
      {
        $info{'dwcrit'} = 'Hcrit Depth'; 
        foreach $time (@timedolist)
        {
  ### error_log occasionally says 'Argument "     " isn't numeric in subtraction (-)'  here ???
  ### so added if test
         if( $prtspot{'hbl'}{$time} !~ m|^ *$| && $prtspot{'hbl'}{$time} !~ m|^ *$| )
          {
            $prtspot{dwcrit}{$time} = $prtspot{'hwcrit'}{$time} - ( $prtspot{'hbl'}{$time} - $prtspot{'dbl'}{$time} );     
          }
          else 
          {
            $prtspot{dwcrit}{$time} = $blankdata ;
          }
        }
      }
      ### create header for each parameter line
      $printheaderline = sprintf "%11s =", $info{$param};
      $printline1 = sprintf "%11s =", "     Hour";
      $printline2 = sprintf "%11s =", " Sfc.Temp";
      #old=blip $printheaderline = sprintf "%11s =", $info{$param};
      #old=blip $printline = sprintf "%10s", "";
      foreach $trigdepth (@trigdepthdolist)
      {
        ### LOOP OVER POSSIBLE MODEL TIMES TO DO CALC
        $itime = 0 ;    
        $triggerhr = -1. ;
        $triggertemp = -1. ;
        foreach $time (@timedolist)
        {
          ### ignore times after soln found
          if( $prtspot{$param}{$time} !~ m|^ *$| && $prtspot{$param}{$time} > $trigdepth )
          {
            ### treat first time specially
            if( $itime > 0 )
            {
              ### adjust time to allow for day switchover
              ### remove non-numbers from time
              ( $calctime = $time ) =~ s|[a-zA-Z]||g ; 
              ( $testtime = $timedolist[0] ) =~ s|[a-zA-Z]||g ; 
              if( $calctime < $testtime ) { $calctime += 2400. ; }
              ### convert to hour
              $calchr = (substr($calctime,0,length($calctime)-2)) + (substr($calctime,length($calctime)-2,2))/60.;
              #old=blip $calctime = $time ; 
              #old=blip if( $time < $timedolist[0] ) { $calctime += 24. ; }
              $triggerhr = $lastcalchr + ( ( $trigdepth - $lastdepth )*( $calchr - $lastcalchr )/( $prtspot{$param}{$time} - $lastdepth ) ) ;
              $triggertemp = $lastsfctemp + ( ( $trigdepth - $lastdepth )*( $prtspot{"sfctemp"}{$time} - $lastsfctemp )/( $prtspot{$param}{$time} - $lastdepth ) ) ;
            }
            else
            {
              $triggerhr = -2. ;
              $triggertemp = -2. ;
            }
            last; 
          }
          $lastdepth = $prtspot{$param}{$time} ;
          $lastsfctemp = $prtspot{"sfctemp"}{$time} ;
          ( $lastcalctime = $time ) =~ s|[a-zA-Z]||g ; 
          ( $testtime = $timedolist[0] ) =~ s|[a-zA-Z]||g ; 
          if( $lastcalctime < $testtime ) { $lastcalctime += 2400. ; }
          $lastcalchr = (substr($lastcalctime,0,length($lastcalctime)-2)) + (substr($lastcalctime,length($lastcalctime)-2,2))/60.;
          #old=blip $lastcalctime = $time ;
          #old=blip if( $time < $timedolist[0] ) { $lastcalctime += 24. ; }
          $itime++ ;    
        }
        ### convert results to printable strings
        if( $triggerhr > 0 )
        {
           ### adjust time to allow for day switchover
           if( $triggerhr > 24. ) { $triggerhr -= 24. ; } 
           ### convert triggerhr to hhmm (Zulu)
           $hrint = int( $triggerhr ) ;
           $minint = int( 60* ($triggerhr - $hrint ) );
           $triggerhrprt = sprintf "%02i:%02i",$hrint,$minint ;
           #old $hrdecimal = $triggerhr - $hrint ;
           #old triggerhrprt = int( 100*$hrint + 60*$hrdecimal ) ;
           #old $triggerhrprt = sprintf "%4iz",$triggerhrprt ;
           $triggertempprt = sprintf "%5.1f", $triggertemp ;
        }
        elsif ( $triggerhr == -2. )
        {
           ### for result prior to first time
           $triggerhrprt = '  +++' ;
           $triggertempprt = '  +++' ;
        }
        elsif ( $triggerhr == -1. )
        {
           ### for result not within time span
           $triggerhrprt = '  ---' ;
           $triggertempprt = '  ---' ;
        }
        $printheaderline .= sprintf " %5.0f ",  $trigdepth ;
        $printline1 .= sprintf " %5s ",  $triggerhrprt ;
        $printline2 .= sprintf " %5s ",  $triggertempprt ;
        #old=blip $printheaderline .= sprintf " %5.0f       ",  $trigdepth ;
        #old=blip $printline .= sprintf "%5s %5s  ",  $triggerhrprt, $triggertempprt ;
        #older=blip $printheaderline .= sprintf "%5.0f ft     ",  $trigdepth ;
        #4test: $printline .= sprintf " %6.2f %6.1f",  $triggerhr, $triggertemp ;
      }
      print "$printheaderline\n"; 
      print "$printline1\n"; 
      print "$printline2\n"; 
      #old=blip print "$printline\n"; 
      print "${headerborder}\n";
    }
  } 

#########################################################################
  
sub read_datafile_pt ()
{
  ### READ+RETURN BLIPMAP DATA IN $datafilename FOR PT $igrid,$jgrid $info=1=>after multiplier correction
  ### RETURN UNDEFINED VALUE IF NO FILE OR ERROR
  my ($datafilename,$igrid,$jgrid,$linfo) = @_;
  #old my ($datafilename,$filename,$igrid,$jgrid,$linfo) = @_;
  my $value ;
  my  @monthname = ( 'Dummy', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec' );
  ### $fcstpd is global variable used in main routine
  $fcstpd = '--';
  #unused ### $TMPFILE used to unzip data to
  #unused my $tmpfile = '/tmp/extract.spot.tmp';
  ### extract from file
  ### allow for zip/nonzip file
  my @FILE;
  if(    -s ${datafilename} )
  { @FILE = `cat $datafilename`; }
  elsif( -s "${datafilename}.zip" )
  #old if( $datafilename =~ m|\.zip| )
  { @FILE = `unzip -p ${datafilename}.zip`; }
  #old { @FILE = `unzip -p ${datafilename}.zip $filename`; }
  else
  ### fixup for missing file - return "-"
  { 
    print STDERR "$programname read_datafile_pt ERROR - missing datafile $datafilename \n";
    return '-' ; 
  }
  #old { die "*** $programname ERROR EXIT - unknown file $datafilename"; }
  ### RETURN IF NO DATA FILE
  if ( $#FILE < 1 ) { return; }
  ### READ INPUT FILE DATA
  ### read header info
  # search for marker line
  my $iline = 0; 
  while ( $FILE[$iline] !~ /^---/ )
  { $iline++; }
  ### READ HEADER LINES
  chomp( my $titleline1 = $FILE[$iline+1] );
  chomp( my $titleline2 = $FILE[$iline+2] );
  chomp( my $titleline3 = $FILE[$iline+3] );
  #4testprint: print "FILE= $inputfile  TITLE= $titleline1 \n";

  ### get date/time info from header line
  # mapinfo = day monthname year
  if ( $titleline3 =~ m|Day= *([0-9]+) +([0-9]+) +([0-9]+) +| )
  {
    $mapinfo = "$3 $monthname[$2] $1";
  }  
  # mapinfo = valid local time
  if ( $titleline3 =~ m|Fcst= *([0-9\.]+) +| )
  {
    $fcstpd = $1 ;
  }  

  #alternate if ( $titleline1 =~ m|.* +([A-Z]+) +([0-9/]+) +([0-9]+)Z.* +([0-9])h.* +([A-Z]+)| ) { $mapinfo = "$1 $2 ${3}Z ${4}hFcst $5";  }  
  #old ### extract date/time info from filename - THIS DEPENDS UPON FORMAT OF "INNER" ZIPPED DATAFILE NAME e.g. zipinfo = blipmap_ruc_canv_wfpm_15z_6h_09z_070822=070822_15z
  #old $zipinfo=`unzip -Z -1 $datafilename $filename`;
  #old ### here $1=region(lc) $2=grid(lc) $3=param  $4=validtime(digits) $5=fcstpd(digits) $6=analtime(digits) $7=rundate(yymmdd) $8=validdate(yymmdd) $9=validZtime(digits)
  #old ### allow for ruc/nam differences
  #old if ( $zipinfo =~ m|blipmap[_:\.]([^_:\.]+)[_:\.]([^_:\.]+)[_:\.]([^_:\.]+)[_:\.][curr\+12\._:]*([0-9]+)z[_:\.]([0-9]+)h[_:\.]([0-9]+)[zi][_:\.]([0-9]+)=([0-9]+)[_:\.]([0-9]+)z| )
  #old # mapinfo = "date - region"  fcstpd = extracted digits
  #old { $mapinfo = sprintf "%s %d - %s", $monthname[substr($8,2,2)],substr($8,4,2),uc($1); $fcstpd = $5 ; }

  ### get grid info from file  
  my ($head,$filegridname,$equal,$imap1in,$imap2in,$jmap1in,$jmap2in,$tail);
  ### allow for old and new grid array index delimiter
  if( $titleline2 =~ m|Indexs=| )
    { ($head,$tail) = split( /  *Indexs=  */, $titleline2 ); }
  else
    { ($head,$tail) = split( /  *=  */, $titleline2 ); }
  ($imap1in,$imap2in,$jmap1in,$jmap2in,$tail) = split( /  */, $tail );
  #old ($head,$filegridname,$equal,$imap1in,$imap2in,$jmap1in,$jmap2in,$tail) = split( /  */, $titleline2 );
  ### validity test
  if ( $igrid < $imap1in || $igrid > $imap2in || $jgrid < $jmap1in || $jgrid > $jmap2in )
  {  
     print STDERR "$titleline2 \n $programname read_datafile_pt ERROR - BAD GRID POINT ${igrid},${jgrid} vs ${imap1in}-${imap2in}+${jmap1in}-${jmap2in} \n";
     return '-' ;
  } 
  #old { print "ERROR: BAD GRID POINT ${igrid},${jgrid} vs ${imap1in}-${imap2in}+${jmap1in}-${jmap2in}"; exit 1; } 
  #older die "read_datafile_pt: BAD GRIDPT= ${igrid},${jgrid} vs ${imap1in}-${imap2in}+${jmap1in}-${jmap2in}";
  #unneeded ### ensure no leading blank on needed data line !
  #unneeded $FILE[$iline+$JGRID-$jmap1in+4] =~ s|^\s+||;
  ### get needed data line
  my @data = split ( / +/, $FILE[$iline+$JGRID-$jmap1in+4] );
  ### DO MULTIPLIER CORRECTION IF REQUESTED
  if( defined $linfo && $linfo > 0 )
  { 
    ### get multiplier info from file  
    if ( $titleline3 =~ m| Mult= *([0-9\.]+) | )
      { $cmult = $1; }
    else
      { $cmult = 1.0 }
    $value = $data[$IGRID-$imap1in] / $cmult ;
  }
  else
  {
    chomp( $value = $data[$IGRID-$imap1in] );
  }
  return $value;
}
#########################################################################
### FIND NEAREST INTEGER
sub nint { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }
#########################################################################


