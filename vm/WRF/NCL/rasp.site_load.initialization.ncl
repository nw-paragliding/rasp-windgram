;;; TO ALTER INITIALIZATION SECTION
;;; (cannot contain procedures or functions)
;;; plot to screen with ncl rasp.ncl lout=0
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"    ; wrf_user_set_xy is different in this than in wrf_user_mass.ncl
;load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"

;load "wrf_user_mass.ncl"
;begin
;set_default_fillvalue("all","ncl_v5")
;tjtest 
print("sequence ------------------  rasp.site_load.initialization.ncl  -------------------")

BASEDIR=getenv("BASEDIR")
print("BASEDIR="+BASEDIR)

LFIXEDCOLOR = 1
;set the default color map to whgryeorre13

pref_font_face="times-roman"
pref_bold_face="times-bold"
maxsounding=80
Ptop=500

;start these all the same there seems to be some tj created confusion of which to use where...
if(isvar("DOMAIN")) then
region=DOMAIN
REGION=DOMAIN
end if

if(isvar("REGION")) then
region=REGION
DOMAIN=REGION
end if

if(isvar("region")) then
DOMAIN=region
REGION=region
end if



; remember that all tests must the .eq. form in ncl
if(isvar("LOUT")) then
print("LOUT = "+LOUT)
 if( ( LOUT .eq. "zero" ) .or. ( LOUT .eq. 0) ) then
      delete( LOUT )
           LOUT = 0
   else
        if( LOUT .eq. "two" ) then
      delete( LOUT )
             LOUT = 2
         else
      delete( LOUT )
             LOUT = 3
         end if
    end if
 lout=LOUT
end if    


if (.not.isvar("lout"))then
lout=2
LOUT=2
end if

daylocal=systemfunc("date  +%d")   ;local  day
utcday=systemfunc("date -u +%d")   ;utc day
utchour=systemfunc("date -u +%k")
utchour=stringtoint(utchour)
daylocal=stringtoint(daylocal)
utcday=stringtoint(utcday)
utchouri=stringtoint(utchour)

if((LOUT.eq.0).or.(lout.eq.0)) then
;for evening testing before new stuff
;day=daylocal

if(.not. isvar("maphour")) then
;maphour=19
;maphour=23
maphour=22
end if

;maptime=maphour+":30:00"
maptime=maphour+":00:00"

if ( (utcday .ne. daylocal) .and. (utchour .lt. 3))
day=daylocal
print("utchour is "+utchour+" and rasp day is daylocal  "+day)
else 
day=utcday
print("utchour is "+utchour+" and rasp day is utcday "+day)
end if
 
day=systemfunc("date -u  +%d")     ; calendar day       
month=systemfunc("date -u +%m")
year=systemfunc("date -u +%Y")



if(.not. isvar("region")) then
print("region was not defined")
 if(utchouri .lt. 4) 
  region="PNW"
 else
 region="PNW-WINDOW"
; region="PNW"
 ;region="NOOKSACK-WINDOW"
 ;region="NOOKSACK_001-WINDOW"
 ; region="TIGER-WINDOW"
 ;region="FRASER-WINDOW"
 ;region="FT_EBEY-WINDOW"
 end if
else
print("region was already defined as "+region)

end if




;region="NWN_BASE_BL-WINDOW"
;region="BLANCHARD-WINDOW"

;opts_ws =True
;opts_ws@MainTitle = "What does this do?" ;WindTitle

if((LOUT.eq.0).or.(lout.eq.0)) then
FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/"+region+"/wrfout_d02_"+year+"-"+month+"-"+day+"_"+maptime /);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/"+region+"/wrfout_d01_"+year+"-"+month+"-"+day+"_"+maptime /);  for 12km plots.
print ("FILENAMES="+FILENAMES)
DOMAIN=region
REGION=region
opts=True
end if  ;end of lout=0 stuff

end if


;; this does something, but it doesn't work as intended...  made harmless by the if statement.
if(.not. isvar("zoom")) then 
zoom=0
end if

if( zoom .ne. 0) then
mpres1 = True;
;opts_mp = True;
opts_mp@tfDoNDCOverlay = False
opts_mp@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
opts_mp@mpMinLatF      = 48.8
opts_mp@mpMaxLatF      = 48.9
opts_mp@mpMinLonF      = -122.00
opts_mp@mpMaxLonF      = -122.1
thisfile=FILENAMES+".nc"
a = addfile(""+BASEDIR+"/WRF/WRFV2/RASP/"+region+"/wrfout_d02_"+year+"-"+month+"-"+day+"_"+maptime+".nc","r")
;a = addfile(""+BASEDIR+"/WRF/WRFV2/RASP/PNW-WINDOW/wrfout_d02_2011-05-07_21:00:00.nc","r")
; So get the XY points of these points
  lats = (/  48.8,  48.9 /)
  lons = (/ -122.1, -122.00 /)
  zoomloc = wrf_user_ll_to_ij(a, lons, lats, True)
; loc(0,;) is west-east (x) ; loc(1,:) is south-north (y) 
; subtract one since we want to use it as an index in NCL
  x_start = zoomloc(0,0) - 1
  x_end   = zoomloc(0,1) - 1
  y_start = zoomloc(1,0) - 1
  y_end   = zoomloc(1,1) - 1

 mpres1@ZoomIn = True        ; set up map info for zoomed area
 mpres1@Xstart = x_start
 mpres1@Ystart = y_start
 mpres1@Xend = x_end
 mpres1@Yend = y_end

end if
;;; --------------------------------------------
;b = addfile(""+BASEDIR+"/WRF/WRFV2/RASP/PNW/wrfout_d02_2011-05-08_20:00:00.nc","r")

;a = addfile(""+BASEDIR+"/WRF/WRFV2/RASP/"+region+"/wrfout_d02_"+year+"-"+month+"-"+day+"_"+maptime+".nc","r")
 
; mymapres   = True                       ; can be any name 
; wrf_mapres_c(a, mymapres, 0)     ; invoke the procedure
; print(mymapres)
     
;exit

if((LOUT.eq.0).or.(lout.eq.0)) then

data=True
leftnote=maptime
;opts@MainTitle = "Test MainTitle"              ;does nothing
opts@TimeTitle = maptime
opts@TimeLabel = "Forecast for "+maptime
data@time = "Forecast for "+maptime

end if

;FILENAMES=(/ ""+BASEDIR+"/WRF/WRFV2/RASP/PNW-WINDOW/wrfout_d02_2010-04-11_21:00:00" /)
;FILENAMES=(/ ""+BASEDIR+"/WRF/WRFV2/RASP/FRASER-WINDOW/wrfout_d02_2010-04-05_21:00:00" /)
;FILENAMES=(/ ""+BASEDIR+"/WRF/WRFV2/RASP/FRASER-WINDOW/wrfout_d02_2010-04-05_21:00:00" /)
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/PNW-WINDOW/wrfout_d02_2009-08-02_01:00:00"/);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/PNW-WINDOW/wrfout_d02_"+year+"-"+month+"-30_21:00:00"/);
;FILENAMES=(/" "+BASEDIR+"/WRF/WRFV2/RASP/TIGER-WINDOW/wrfout_d02_2009-07-27_22:00:00" /);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/PNW-WINDOW/wrfout_d02_"+year+"-"+month+"-"+day+"_21:00:00"/);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/FRASER-WINDOW/wrfout_d02_"+year+"-02-01_04:00:00"/);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/FRASER-WINDOW/wrfout_d02_"+year+"-"+month+"-"+day+"_20:00:00"/);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/FRASER-WINDOW/wrfout_d02_"+year+"-"+month+"-"+day+"_20:00:00"/);
;FILENAMES=(/""+BASEDIR+"/WRF/WRFV2/RASP/PNW/wrfout_d02_"+year+"-"+month+"-"+day+"_20:00:00"/);
; .not.ismissing(ENV_NCL_FILENAME) .and.
;THISFILENAME= ""+BASEDIR+"/WRF/WRFV2/RASP/FRASER-WINDOW/wrfout_d02_2010-04-07_21:00:00"
;printVarSummary(FILENAMES)
;print(FILENAMES)
;testidx=str_index_of_substr(THISFILENAME, "-WINDOW", 0)
;if (testidx .lt. 0)then
;IWINDOW=0
;else
;IWINDOW=1
;end if
;print ("substring value = "+testidx+"so IWINDOW is"+IWINDOW )


opts_st = True
opts_ws = True;

opts_st@stLineThicknessF = 1.8
;opts_ws@gsmMaximize = True;
;opts_mp@gsnMaximize = True;



;;----------------------for zoom map ------------------------------
;; tjo want to be able to create subplots using mpLimitMode and mpLimitMinLat etc 
; need a conditional in RASP to turn this on or off with given parameters.
; without doing more, just fixing the corners gets the parameter plot to a "window" but the whole terrain is overlaid

opts_mp = True
opts_mp@mpDataResolution = "FinestResolution"

;  opts_mp@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
;  opts_mp@mpMinLatF      = 48.5
;  opts_mp@mpMaxLatF      = 49.
;  opts_mp@mpMinLonF      = -122.7
;  opts_mp@mpMaxLonF      = -122.0

;opts_ter = False no effect
;  opts_ter = True 
;  opts_ter@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
;  opts_ter@mpMinLatF      = 48.5
;  opts_ter@mpMaxLatF      = 49.
;  opts_ter@mpMinLonF      = -122.7
;  opts_ter@mpMaxLonF      = -122.0
;    opts_ter@cnLinesOn = False     ; just this makes the contour lines go away and has the appropriate coastline.
;;----------------------end for zoom map ------------------------------



;IWINDOW=1;            needed to pick up proper contour levels in interactive mode.
; ter gets terrain.
; hglider gets a combined hcrit with clouds 
; vhf gets virtual heat flux 
; blicw gets boundary layer integrated cloud water
; above gets above "
;  (/"wrf_CFRACH"/); High level cloud fraction from wrf
; cwbase gets explicit cloud base AGL
; experimental2 is cldfra cloud fraction
; swblmaxmin AGL height of WBL maxmin
; mslpress
; 4 test: for winds 0.88949 is xNDC  xNDCright is0.82449   for most 0.964372 is xNDC   xNDCright is0.899372    

; Calculate potential temperature at each level aat all grid points
;***********************************************************
;a = addfile(FILENAMES+".nc","r")
;T=a->T
;theta           = T                                      ; create/transfer meta data
;theta           = T*(100000/ph)^0.286                    ; poisson equation for potential temp
; calculate potential temperature;***********************************************************
;nsounding=5


LFIXEDCOLOR = 1

  UNITS = "american";


;opts_w=True;
;opts_w@lbLabelBarOn    = False;
;opts_w@pmLabelBarDisplayMode ="NoCreate"
;opts_w@pmLabelBarDisplayMode
; opts_w@cnLabelBar=(/ "a", "b" /)

if(isvar("param"))then
PARAMS =  (/ param /)
else
;if(.not.isvar("PARAMS"))then
;PARAMS = (/ "HGT" /);
;  PARAMS = (/ "xcloud" /);    ;does this work? only if rasp.ncl changed for rh and qcloud
;  PARAMS = (/ "sfcwind0" /);
;   PARAMS = (/"wrf='VVEL:30-0'" /);
;   PARAMS = (/"tenmwind" /);
;  PARAMS = (/ "sfcwind" /);
;  PARAMS = (/ "sfcwind2" /);
;  PARAMS = (/ "bltopwind" /); javascript:shoParam("bltopwind")
;  PARAMS = (/ "blwindshear" /);
;  PARAMS = (/ "zblcldif" /);
;  PARAMS = (/ "blcwbase" /);
;  PARAMS = (/ "zlcwbase" /);
;  PARAMS = (/ "zsfclcl" /);
;  PARAMS = (/ "zsfclcldif" /);
;  PARAMS = (/ "sfcwindkt_sfcwinddeg" /);   doesn't know how... why is it in rasp.ncl???
;  PARAMS = (/ "sfcwindspd_sfcwinddir" /);
;  PARAMS = (/ "ter" /);
;  PARAMS = (/ "hbl" /);
;  PARAMS = (/ "cape" /);
;  PARAMS = (/ "wstar" /);
;  PARAMS = (/ "wstar_bsratio" /);
;  PARAMS = (/ "blicw" /);
;  PARAMS = (/ "hglider" /);
;  PARAMS = (/ "hwcrit" /);
;  PARAMS = (/ "press600" /);
;  PARAMS = (/ "press700" /);
;  PARAMS = (/ "press800" /);
;  PARAMS = (/ "press880" /);
;  PARAMS = (/ "press850" /);
;  PARAMS = (/ "press900" /);
;  PARAMS = (/ "press920" /);
;  PARAMS = (/ "press930" /);

;  PARAMS = (/ "press940" /);
;  PARAMS = (/ "press950" /);
;  PARAMS = (/ "press960" /);
;  PARAMS = (/ "press1000" /);
;  PARAMS = (/ "press1010" /);
;  PARAMS = (/ "wblmaxmin" /);
;  PARAMS = (/ "press1000=W" /);
;  PARAMS = (/ "rainTot" /);
;  PARAMS = (/ "rain1" /);
;  PARAMS = (/ "mslpress" /);
;  PARAMS = (/ "sfcsun" /);

  PARAMS = (/ "sfcsunpct" /);

;  PARAMS = (/ "sfctemp" /);
;  PARAMS = (/ "sfcdewpt" /);
;  PARAMS = (/ "wblmaxmin" /);
;  PARAMS = (/ "zwblmaxmin" /);
;  PARAMS = (/ "swblmaxmin" /);
;  PARAMS = (/ "pwblmaxmin" /);
;  PARAMS = (/ "sounding37" /);  Blanchard may 9 2010
;  PARAMS = (/ "wrf=W=3" /);   three dimensional variable. must = level

; PARAMS = (/ "wrf=CLDFRA=30" /);   three dimensional variable. 
; PARAMS = (/ "wrf=CFRACH" /); high cloud fraction
; PARAMS = (/ "wrf=CFRACM" /); mid
; PARAMS = (/ "wrf=CFRACL" /); low
; PARAMS = (/ "wrf=ALBEDO" /);
; PARAMS = (/ "wrf=SNOWCOVR" /);  used at UW and another 
; PARAMS = (/ "wrf=SNOWC" /); snow cover 01
; PARAMS = (/ "wrf=QCLOUD=20" /);
; PARAMS = (/ "wrf=RH" /);  not found
; PARAMS = (/ "wrf=SH20" /); soil water 
; PARAMS = (/ "wrf=SMOIS" /); SOIL MOISTURE
; PARAMS = (/ "wrf=SNOW" /); snow water equiv
; PARAMS = (/ "wrf=SNOW" /); snow water equiv
; PARAMS = (/ "wrf=SNOWH" /); snow depth
; PARAMS = (/ "wrf=SNOWNC" /);  accumulated snow
; PARAMS = (/ "wrf=RAINC" /);
; PARAMS = (/ "wrf=RAINNC" /);              RAINNC:description = "ACCUMULATED TOTAL GRID SCALE PRECIPITATION" ;
;PARAMS = (/ "xbl_-122.1_48.86_0" /);
;PARAMS = (/ "xbl_-122.1_48.86_55" /);

;  PARAMS = (/ "xbl_-122.43_48.61_45" /);
;  PARAMS = (/ "xbl_-122.00_49.00_45" /);
;  PARAMS = (/ "wrf=T2" /);
;  PARAMS = (/ "blcloudpct" /);
;  PARAMS = (/ "rhblmax" /);
;  PARAMS = (/ "boxwmax" /);
;  PARAMS = (/ "theta" /);
;  PARAMS = (/ "xbl_-122.21_48.81_42.0" /);  bj 
;  PARAMS = (/ "xbl_-122.43_48.61_90" /);
;  PARAMS = (/ "xbl_-122.125440_48.799825_1.0" /);  East of van zant dike
;  PARAMS = (/ "xbl_-122.20788_48.812544_42.0" /);  West of van zant dike se of rt9 rt542
;  PARAMS = (/ "wstar_-122.20788_48.812544_42.0" /);  West of van zant dike se of rt9 rt542
;  PARAMS = (/ "xbl_-122.2256_48.768353_32.0" /);  west of van zant dike west Sygitowicz Creek mouth
; PARAMS = (/ "xbl_-122.2256_48.768353_windk_2" /);  west of van zant dike west Sygitowicz Creek mouth
; PARAMS = (/ "xbl_-122.2256_48.768353_49.0" /);  west of van zant dike west Sygitowicz Creek mouth
;  PARAMS = (/ "xbl_-122.2256_48.768353_90.0" /);  west of van zant dike west Sygitowicz Creek mouth due east
;print("param = "+PARAMS(0))

end if


;s_we           =   1,  1,  1,
;e_we           =  24,  37,  46,
;s_sn           =   1,  1,  1,
;e_sn           =  24,  34,  49,
;s_vert         =   1,  1,  1,
;e_vert         =  52,  52,  52,
;dx             = 12000.000,  4000.000,  1333.333,
;dy             = 12000.000,  4000.000,  1333.333,
;grid_id        = 1,  2,  3,
;parent_id      = 1,  1,  2,
;i_parent_start = 0,  7,  12,
;j_parent_start = 0,  7,  12,
;	   
;load "gsn_code.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
;load WRFUserArw.ncl
;if (isvar("FILENAMES")) then
; if (.not.ismissing("FILENAMES")) then
; print("FILENAMES ="+FILENAMES )
; thisfile=FILENAMES+".nc"
; a = addfile(thisfile,"r")
;
; wlat=a->XLAT(0,:,:)
; wlon=a->XLONG(0,:,:)
; print( "The region extends from") ;
; print(min(wlat)+" N  to "+max(wlat)+" N")    ; 
; print("Between "+min(wlon)+" W and "+max(wlon)+" W ")  ; 
; end if
;end if
;
;

opts_ter = True;
;; does nothing here, must be in rasp.site_load.allmaps.ncl
if( REGION .eq. "PNW" .and. IWINDOW .eq. 1) then
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
end if


;mp = True
; getvalues mp              
; "mpAreaNames" : area_names 
; end getvalues 
;  print(area_names)


;mp@mpOceanFillColor="skyblue"
print ("end of rasp.site_load.initialization.ncl")  
