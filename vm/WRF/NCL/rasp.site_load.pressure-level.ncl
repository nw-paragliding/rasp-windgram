;;; TO ALTER PRESSURE LEVEL PLOT SECTION
;;; (cannot contain procedures or functions)
;
; set to the same as wblmaxmin only get excited if more than 200cms either way
; zero is white.
; blue2orange has 15 colors  may be a problem in wrf_plot.ncl see drjack tjo
; change around 406
;tjtest 
print("sequence ------------------  rasp.site_load.pressure-level.ncl  for  "+REGION+"       "+plot_param+"-----------------------")
;The special resource @ContourParameters
;is peculiar to wrf data, which RASP is, but know that it is shorthand for 4 resources together
;    cnLevelSelectionMode  ;  which defaults to automatic, but which can be explicit or manual 
;  AutomaticLevels  ManualLevels ExplicitLevels or EqualSpacedLevels
; see: http://www.ncl.ucar.edu/Document/Graphics/Resources/cn.shtml
;    cnLevelSelectionMode = ExplicitLevels
;    cnMinLevelValF
;    cnMaxLevelValF
;    cnLevelSpacingF


opts_w = True;
;opts_w@ContourParameters = (/ -60., 180., 30. /);   see below by 25 now sailplane pilots wanted finer distinctions...

if(.not.isvar("region"))
region=REGION
end if

opts_vct = True;
;opts_vct                         = True             ; plot mods desired

if ( .not. isvar("rhcut")) then
  rhcut = 94
end if

;rhmsg="~F14~~Z60Q~rhcut~C~"+rhcut+"%"
;gsn_text_ndc ( wks, rhmsg, .93, .05,lbtxtres )
;;;rel_humd=gsn_contour(wks,rhgrid,hum_res)

;gsn_define_colormap(wks,"updraft")     ; choose color map


;opts_w@gsnSpreadColorEnd              = 12         ; don't use added gray

;opts_w@ContourParameters = (/ -300., 300., 50. /) ;was 200 200 25
;opts_w@ContourParameters = (/ -200., 250., 50. /) ;was 200 200 25
;opts_w@ContourParameters = (/ -30., 150., 30. /);   that works
;opts_w@ContourLevelColors =(/ 2,3,4,5,6,7,8,9,10,11 /)
;opts_w@ContourParameters = (/ -120., 300., 60. /);  

;opts_vcres@vcLevelColors =  (/ 3., 21., 3. /);  pgwind speeds
;opts_bparam@ContourParameters = (/ -300., 300., 50. /) ;vert updown motion cm/s
;gsn_define_colormap(wks,"updraft_pgwind")     ; choose color map
;gsn_define_colormap(wks,"updraft");     
;gsn_define_colormap(wks,"blue2orange");     
;gsn_define_colormap(wks,"converge_black")     ; choose color map


;setvalues wks
;	"wkColorMap":    "converge_black"            ;
;	"wkForegroundColor" : (/.2,.2,1./)
;	"wkBackgroundColor" : (/.87, .96, 1./)
;end setvalues
;opts_vct@vcWindBarbColor = "black"
opts_w@cnFillOn = True 
   opts_w@ContourParameters = (/ -100., 300., 25. /);
   ;opts_w@ContourParameters = (/ -60., 180., 30. /);  
   gsn_define_colormap(wks,"converge2");     
           setvalues wks
        "wkColorMap": "converge2"            ;"BlWhGrPiPuOrRe"
        "wkForegroundColor" : (/.2,.2,.2/)                ;dark blue  .1 .1 1.0
;        "wkForegroundColor" : (/ .54, .5,.4 /)                ;dark brown
;        "wkBackgroundColor" : (/.87, .96, 1./)            ;pale aquaish
        end setvalues
opts_w@cnMonoFillPattern = False
;opts_w@cnMonoFillColor = False
;opts_w@cnLevelSelectionMode = "ExplicitLevels"
  opts_w@cnMonoFillScale = True
  opts_w@cnFillScaleF = .2   ;.2 is a good compromise visible without getting rid of too much base color.

opts_w@cnFillPatterns = (/ 0, 6,6,6,0, 0,  0,  0,  0,    0,  0,    0,  0,    0,   0,   0,    0 , 0 /)  ; 16 xhatch 14 xhatch 13 lighter xhatch  17 is stipple all solid until second red
;opts_w@cnLevels=(/ -100., -75., -50., -25., 0., 25., 50., 75., 100., 125., 150., 175., 200., 225., 250., 275., 300., 325. /)
;opts_w@cnFillColors = (/ 2, 3,4,5,6, 7,  8,  9,  10,    11,  12,    13,  14,   15,  16,   17,   18 /)  ; 16 xhatch 14 xhatch 13 lighter xhatch  17 is stipple all solid until second red


;           opts_w@MainTitle = "Vertical Velocity [m/s] & Wind [kt] at "+pressure+"mb "+zft+"ft"

;initialize  these arbitrary places  when running as lout=0 there is no IWINDOW or REGION
xtmp=16
ytmp=50

;just pick a spot in each grid that is low so the pressure at the ground is likely to be over 1000mb.

;print("pick spot for end of heights --- REGION = "+REGION+"    IWINDOW = "+IWINDOW+" ") 

if ((REGION .eq. "PNW") .and. (IWINDOW.eq.0) .or.  region .eq. "PNW"  .or.  region .eq. "PNWB4" )then
;y=46 grid  x =15 ter=10.2755at pressalt of 17.9921  47.9102N  -122.511W  33xxft
;swap them
xtmp=46
ytmp=15
end if
;5 10 work

if (region .eq. "NOOKSACK" .or. REGION .eq. "NOOKSACK" .or. region .eq. "NOOKSACK-WINDOW"  .or. REGION .eq. "NOOKSACK-WINDOW" )then
;y=40 grid  x =0 ter=39.8072 at pressalt of 47.5522  48.8678N  -122.446W
;y=36 grid  x =16 ter=53.2207 at pressalt of 61.0112  48.8405N  -122.27W
;Elevation Height at that point xtmp ytmp is 78.0198ft
ytmp=10   
xtmp=50 
end if

if ((REGION .eq. "PNW") .and. (IWINDOW.eq.1) .or.  region .eq. "PNW-WINDOW" .or.  REGION .eq. "PNW-WINDOW"  .or.  region .eq. "PNWB4-WINDOW" )then
; y=15 grid  x =23 ter=13.2338at pressalt of 21.0262  48.5118N  -122.289W
;swap them
xtmp=23
ytmp=15
end if

;y=28 grid  x =35
; Elevation Height at that point xtmp ytmp is 630.993
if (REGION .eq. "FRASER" .or. region .eq. "FRASER-WINDOW"  .or. REGION .eq. "FRASER-WINDOW")then
;swap them then
;Elevation Height at that point xtmp ytmp is 169.03
xtmp=28
ytmp=35
end if

if (REGION .eq. "TIGER" .or. region .eq. "TIGER-WINDOW" .or. REGION .eq. "TIGER-WINDOW")then
;y=27 grid  x =22
;Elevation Height at that point xtmp ytmp is 439.748
;swap them Elevation Height at that point xtmp ytmp is 102.42 
xtmp=27
ytmp=22
end if  


print("Pressure levels calculated at xtmp ytmp "+xtmp+" "+ytmp+" over a spot elevation of "+terft(xtmp,ytmp)+"ft  REGION = "+REGION+"  IWINDOW = "+IWINDOW)
; needs to know where to get Z.  Is a  defined  ???
;sourcefile = FILENAMES(0)+".nc"$
;b = addfile( sourcefile, "r" ) 
;ztmp = wrf_user_getvar(b,"Z",0)
;dimsregion = dimsizes(ztmp)    
if(isfile(a))then
;  print("the file handle a has been defined and passed here to rasp.site_load.pressure-level.ncl and could generate zft")

  ztmp = wrf_user_getvar(a, "Z",time) ; 
  z_plane = wrf_user_intrp3d(ztmp,pmb,ter,"h",pressure,0.)
  zft= 100.          ; create var zft and make it a float by using the . 
  zpdims=dimsizes(z_plane)
;  printVarSummary(zpdims)
;  print(zpdims)
; printVarSummary(terft)
if(.not.ismissing(z_plane(xtmp,ytmp)))
 zft=round(3.281*z_plane(xtmp,ytmp),0)   ;20 18 works for fraser just pick a spot near blanchard mt but over flat land.
 zm=round(z_plane(xtmp,ytmp),0)
 ;change to this if working         
 opts_w@MainTitle = "Vertical Velocity [cm/s] (convergence) & Wind [kt] at "+pressure+"mb ~F34~!~F21~ "+zft+"ft  "+zm+"m"
  print("Map Title:  Vertical Velocity [cm/s] (convergence) & Wind [kt] at "+pressure+"mb "+zft+"ft  "+zm+"m")
;print(" Elevation Height at that point xtmp ytmp is "+terft(xtmp,ytmp))

else
print("No value for zft found at pressure level "+pressure+"mb  at point xtmp ="+xtmp+" ytmp="+ytmp )
print(" Elevation Height at that point xtmp ytmp is "+terft(xtmp,ytmp))
;  opts_w@MainTitle = "Vertical Velocity [cm/s] (convergence) & Wind [kt] at "+pressure+"mb"
end if
;
else
  print("there is no   a   filehandle defined in  rasp.site_load.pressure-level.ncl")
  opts_w@MainTitle = "Vertical Velocity [cm/s] (convergence) & Wind [kt] at "+pressure+"mb"
end if
;4test  print("for pressure height "+pressure+"mb  zft taken at "+xtmp+","+ytmp+" = "+zft+"  region dimensions are  "+zpdims(0)+" by "+zpdims(1) )        ; must fiddle as above to work in all regions.  may need a conditional

if(isvar("zpdims"))
delete(zpdims)
end if
if(isvar("ztmp"))
   delete(ztmp)
end if
if(isvar("zft"))
  delete(zft) 
end if
if(isvar("z_plane"))
delete(z_plane)
end if
delete(ytmp)
delete(xtmp)

           opts_vct@vcWindBarbColor = "black"

;print("Plotting a pressure level variable, "+plot_param )
;opts_vct@vcMonoWindBarbColor     = False ;True            ;does nothing here must be in rasp.pl  color barbs by scalar 
;opts_vct@vcGlyphStyle           = "WindBarbs"
;opts_vct@WindBarbLineThicknessF  = 4 ;  does nothing
;opts_vct@vcLevelSelectionMode    = "ExplicitLevels"
;opts_vct@vcLevels                = (/ 3.,6.,9.,12.,15.,18.,21. /);     ; set the data levels
;opts_vct@vcLevelColors          = "(/12,13,14,15,16,17,18,19 /)"     ;  Are these the indexes of the colors???yes
;opts_vct@ContourParameters = (/ 3., 21., 3. /) ;    ????  does this do anything


;;if (isvar("rhcut"))then
;; test rh on pressure plots with rhcut
if ( .not. isvar("rh") ) then
 rh = wrf_user_getvar(a, "rh",time) ; pressure is our vertical coordinate in mb
end if

; from rasp.ncl

     ; from windgrams set cutoff for relative humidity.  Draw cross hatches if it is greater than 95
print ("Setting up rh for pressnnn plots from rasp.site_load.pressure-level.ncl  rhcut = "+rhcut+"%")

opts_rh =True
      opts_rh@cnLevelSelectionMode = "ExplicitLevels"
      opts_rh@cnLevels             = (/ 0,rhcut /)    ; set at top of script or command line  eg. rhcut=94
      ; having only one value, rhcut threw an error and caused ncl to not use explicit levels.
      opts_rh@cnFillOn             = True
      opts_rh@cnFillColors         = (/-1,-1,1/)       ; crosshatching
      opts_rh@cnFillScaleF         = .3
      opts_rh@cnFillPattern        = 6              ;6 crosshatch  17 is stipple
;      opts_rh@cnFillDotSizeF       = 0.04           ;default is 0.0
      opts_rh@tmXBOn               = False          ; turn off things that we don't want
      opts_rh@tmYROn               = False
      opts_rh@cnLinesOn            = False
      opts_rh@cnLineLabelsOn       = False
      opts_rh@tmXTLabelsOn         = False
      opts_rh@tmXBLabelsOn         = False
      opts_rh@cnInfoLabelOn        = False
;      opts_rh@tiMainString         = ""  ;
;      opts_rh@tiXAxisString        = "";the null string caused it to move label bar down.
;      opts_rh@tiYAxisString        = ""
      opts_rh@lbLabelFontHeightF   = 0.002
      opts_rh@NoTitles             = True
      opts_rh@lbLabelsOn         = False
;      opts_rh@lbMonoFillPattern    = True
;      opts_rh@lbFillPattern    = (/-1,-1/)
;      opts_rh=hum_res

;4rh this is in rasp.ncl move here and comment out there. didn't work doesn't get back to rasp.ncl
;contour_rh     = wrf_new_fill_contour(wks,rh_plane,opts_rh, mainvpx,mainvpy,mainvpwidth,mainvpheight )


  lbtxtres = True                                                                                                        
  ;lbtxtres@txtFontQuality = "High"                                                                                       
  lbtxtres@tiXAxisFont = 21 ;helvetica                                                                                   
  lbtxtres@txFuncCode    = "~"                                                                                           
  lbtxtres@txFontHeightF = 0.015                                                                                         
  lbtxtres@txFontHeightF = 0.015                                                                                         
  lbtxtres@txJust = "CenterLeft"  

;4rh this is in rasp.ncl tried to move here and comment out there but it didn't work in production 
; even though command line plotting worked...  doesn't get back to rasp.ncl
; it might not have all the parameters yet when this file is called...
; if ( .not. isvar("rh_plane") ) then  ; make sure this has been created, if not create it.
;     rh_plane  = wrf_user_intrp3d( rh,pmb,ter,"h",pressure,0.)
; end if

; if ( .not. isvar("contour_rh") ) then  ; make sure this has been created, if not create it.
;   contour_rh     = wrf_new_fill_contour(wks,rh_plane,opts_rh, mainvpx,mainvpy,mainvpwidth,mainvpheight )
; end if


rhmsg="~F14~~Z70Q~rhcut~C~"+rhcut+"%"                                                                                  

yspot=.24         ;default height up from bottom for rhmsg

;if ((REGION .eq. "PNW" ) .or.  (REGION .eq. "PNW-WINDOW"))then
;yspot=.14
;end if

if (REGION .eq. "FRASER")then
yspot=.04
end if

if (REGION .eq. "TIGER")then
yspot=.04
end if

gsn_text_ndc ( wks, rhmsg, .93, yspot,lbtxtres )                                                               



;end if


;opts_blankmap =True
;opts_blankmap@mpMonoFillColor  = False
;opts_blankmap@mpOceanFillColor = 12
;opts_blankmap@mpInlandWaterFillPattern = "HollowFill (-1)"
;opts_blankmap@mpDataBaseVersion = "HighRes"
;opts_blankmap@mpDataResolution = "Finest"
;opts_blankmap@mpGridSpacingF= .2
