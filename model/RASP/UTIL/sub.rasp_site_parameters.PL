############################################
##########  SET SITE DIRECTORIES  ##########
############################################
sub site_directories ()
{
### SET SITE-DEPENDENT BASEDIR FOR APACHE SERVER RUN
###  (USED AS GLOBAL VARIABLES)
  if ( ! defined $ENV{'HOME'} )
  { $ENV{'HOME'} = '/home/tj' ;  }
  else
  {
    ### UNTAINT ENVIRON VARIABLE
    if ( $ENV{'HOME'} =~ m|^([A-Za-z0-9/][A-Za-z0-9_.:/-]*)$| ) { $ENV{'HOME'} = $1 ; }  # filename chars only
  }
  $HOME = $ENV{'HOME'}; 
  $BASEDIR = "$ENV{'HOME'}/drjack"; 
}

#############################################
##########  SET REGION PARAMETERS  ##########
#############################################
sub region_params ()
{
  my ($REGION) = @_;
  my $routinename = 'region_params' ;
  my ( $localtime_id, $localtime_adj ); 

  if( $REGION eq 'PANOCHE' )  
  {
    $localtime_id = 'PST' ;
    $localtime_adj = -8 ;
  }
  elsif( $REGION eq 'WILLIAMS' )  
  {
    $localtime_id = 'PST' ;
    $localtime_adj = -8 ;
  }
  elsif( $REGION eq 'GREATBRITAIN' )  
  {
    $localtime_id = 'GMT' ;
    $localtime_adj = 0 ;
  }

  else
  {   $localtime_id = 'PDT' ;
      $localtime_adj = -7 ;
  }    
  
##  die "*** $routinename ERROR EXIT:  unknown region = $REGION"; }

  return ( $localtime_id, $localtime_adj ); 
}

###########################################
##########  SET GRID PARAMETERS  ##########
###########################################
sub grid_params ()
{

  my ($REGION,$GRID) = @_;
  my $routinename = 'grid_params' ;
  my ( $grid_imin,$grid_imax, $grid_jmin,$grid_jmax ) ;

  $grid_imin = 1 ;
  $grid_jmin = 1 ; 

  ### "$grid_imax" VALUES OBTAINED BY SUBTRACTING 1 FROM "e_we" VALUES IN $BASEDIR/WRF/WRFV2/RASP/REGIONXYZ/namelist.template
  
  ### "$grid_jmax" VALUES OBTAINED BY SUBTRACTING 1 FROM "e_sn" VALUES IN $BASEDIR/WRF/WRFV2/RASP/REGIONXYZ/namelist.template
# Blanchard e_we           = 24,  37,  46,
# Blanchard e_sn           = 24,  34,  49,
   
  ### *** N*B *** DATAFILE GRID INDEX MAX IS ONE LESS THAN THAT OF WRF INIT FILE !!!

# if( $REGION eq 'Blanchard' )  
#  {
    if( $GRID eq 'd1' || $GRID eq '1' )
    {
      ### SET GRID SIZE
      $grid_imax = 23 ;
      $grid_jmax = 23 ;
    }
    elsif( $GRID eq 'd2' || $GRID eq 'w1' || $GRID eq '2' )
    {
      ### SET GRID SIZE
      $grid_imax = 36 ;
      $grid_jmax = 33 ;
     }
    elsif( $GRID eq 'w2' || $GRID eq '3' )
    {
      ### SET GRID SIZE
      $grid_imax = 45 ;
      $grid_jmax = 48 ;
#    }
#   else
#   { die "*** $routinename ERROR EXIT:  $REGION unknown grid = $GRID"; }
 }
 }


############################################
##########  SET IMAGE PARAMETERS  ##########
############################################
sub image_params ()
{

  my ($REGION,$GRID) = @_;
  my $routinename = 'image_params' ;
  my ( $image_mapwidth,$image_mapheight, $image_maporiginx, $image_maporiginy );

  ### GRID 2 VALUES OBTAINED BY FINDING LINES ala "VIEWPORT: 0.602933x0.82@0.198534,0.89" in $BASEDIR/WRF/NCL/rasp.ncl.out.REGIONXYZ.02
  ### GRID 3 VALUES OBTAINED BY FINDING LINES ala "VIEWPORT: 0.602933x0.82@0.198534,0.89" in $BASEDIR/WRF/NCL/rasp.ncl.out.REGIONXYZ-WINDOW.02
  ###    where the VIEWPORT values represent:  $image_mapwidth x $image_mapheight @ $image_maporiginx , $image_maporiginy

#home/tj/drjack/WRF/NCL/rasp.ncl.out.Blanchard.02:(0)        wrf_plot.nclwrf_new_map VIEWPORT: 0.82x0.749704@0.09,0.854852
#home/tj/drjack/WRF/NCL/rasp.ncl.out.Blanchard-WINDOW.02:(0) wrf_plot.ncl wrf_new_map VIEWPORT: 0.767543x0.82@0.116229,0.89



  if( $REGION eq 'Blanchard' )
  {
    if( $GRID eq 'd1' || $GRID eq '1' )
    {
      die "$routinename - no data for $REGION  $GRID ";
    }
    elsif( $GRID eq 'd2' || $GRID eq 'w1' || $GRID eq '2' )
    {
      ### SET IMAGE VIEWPORT SIZE, ORIGIN
      ### here "map" is same as "viewport", with values between 0.0 and 1.0
      $image_mapwidth = 0.82 ;
      $image_mapheight = 0.740784 ;
      $image_maporiginx = 0.09 ;
      $image_maporiginy = 0.854852 ;
     }
    elsif( $GRID eq 'w2' || $GRID eq '3' )
    {
      ### SET IMAGE VIEWPORT SIZE, ORIGIN
      ### here "map" is same as "viewport", with values between 0.0 and 1.0
      $image_mapwidth = 0.787543 ;
      $image_mapheight = 0.82 ;
      $image_maporiginx = 0.116229 ;
      $image_maporiginy = 0.80 ;
    }
    else
    { die "*** $routinename ERROR EXIT:  $REGION unknown grid = $GRID"; }
  }
 }   


### FILE MUST END WITH FOLLOWING LINE:
1;
