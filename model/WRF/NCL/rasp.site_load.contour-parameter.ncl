;;; TO ALTER CONTOUR PARAMETER PLOT SECTION
;;; (cannot contain procedures or functions)
;tjtest 
print("sequence ------------------  rasp.site_load.contour-parameter.ncl "+REGION+"  "+plot_param+" IWINDOW="+IWINDOW+" -----------------------")
;load "./WRFUserARW.ncl"
LFIXEDCOLOR = 1
;The special resource @ContourParameters
;  is peculiar to wrf data, which RASP is, but know that it is shorthand for 4 resources together
;    cnLevelSelectionMode  ;  which defaults to automatic, but which can be explicit or manual 
;  AutomaticLevels  ManualLevels ExplicitLevels or EqualSpacedLevels
; see: http://www.ncl.ucar.edu/Document/Graphics/Resources/cn.shtml
;    cnLevelSelectionMode    
;    cnMinLevelValF
;    cnMaxLevelValF
;    cnLevelSpacingF
	
;If it is a scalar, then it's used for cnLevelSpacingF.
;if res@ContourParameters is an array, of three values they mean Start, End, and Interval
;	
; see: http://www.mmm.ucar.edu/wrf/OnLineTutorial/Graphics/NCL/NCL_functions.htm	



;;; example of altering wstar parameter contour interval/coloring
;;; (for more details see "Change plot formatting" section at http://www.drjack.info/twiki/bin/view/RASPop/ProgramUserChanges
;example:  if( plot_param .eq. "wstar" ) then
  ;example=fixed_colors:      opts_bparam@ContourParameters = (/ 100., 800., 100. /)
  ;example=fixed_interval:    opts_bparam@ContourParameters = (/ 0.,0., 100. /)
  ;example=automatic_colors:  opts_bparam@ContourParameters = (/ 0., 0., 0. /)
;example:  end if
;dwcrit is agl
opts_bparam = True
opts_ter = True
opts_ter@cnLineColor = "black"

; this only zooms the parameter map, not the background terrain plot. 
if(.not. isvar("zoom"))then
zoom=0
end if

if( zoom .ne. 0) then
opts_mp = True;
opts_mp@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
opts_mp@mpMinLatF      = 48.6
opts_mp@mpMaxLatF      = 49.
opts_mp@mpMinLonF      = -122.00
opts_mp@mpMaxLonF      = -122.3
opts_ter@cnLinesOn = False 
;opts_ter = False   ;True;
;opts_ter@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
;opts_ter@mpMinLatF      = 48.6
;opts_ter@mpMaxLatF      = 49.
;opts_ter@mpMinLonF      = -122.00
;opts_ter@mpMaxLonF      = -122.3
; We are interested in a zoomed area with the SW corner at 20N;90W,  
; and the NE corner at 30N;80W
; So get the XY points of these points
lons = (/  -122.20,  -121.98 /)
lats = (/ 48.6, 49.0 /)
loc = wrf_user_ll_to_ij(a, lons, lats, True)
       
; loc(0,;) is west-east (x) ; loc(1,:) is south-north (y) 
; subtract one since we want to use it as an index in NCL
x_start = loc(0,0) - 1
x_end   = loc(0,1) - 1
y_start = loc(1,0) - 1
y_end   = loc(1,1) - 1
	       
ops_mp@ZoomIn = True        ; set up map info for zoomed area
ops_mp@Xstart = x_start
ops_mp@Ystart = y_start
ops_mp@Xend = x_end
ops_mp@Yend = y_end


ter = wrf_user_getvar(a,"HGT",-1)              ; get olr
ter_zoom = ter(:,y_start:y_end,x_start:x_end)  ; create a zoomed area


end if

if(( plot_param.eq."wstar") .or. (plot_param .eq. "wstar_bsratio")) then

opts_bparam@MainTitle = "Thermal Updraft Velocity ( W* ) 1m/s = 200fpm" ;
  setvalues wks
        "wkColorMap": "updraft"
        "wkForegroundColor" : (/.2,.2,1./)
	"wkBackgroundColor" : (/.87, .96, 1./)
;invalid	"wkBackgroundColor" : (/-1, -1, -1/)
  end setvalues
        newindex = NhlNewColor(wks,0.0,0.0,0.0)  ;add black for contour lines
	       opts_bparam@ContourParameters = (/ 200., 1000.,100. /)
	       opts_cparam  = True;
	       ; opts_cparam@cnLevelSelectionMode = "ExplicitLevels"           ;this is overridden by wrf_plot.ncl  tjo  it expects the ContourParameters.
	       ; opts_cparam@cnLevels = (/ 200., 300.,400.,500.,600.,700.,800.,900., 1000. /)  ;
	       opts_cparam@cnFillColor = "(/.2,.2,1./)"           ;set stipples color to foreground color
	       ; opts_cparam@cnFillColors = (/0,1,2,3,5,6,7,8,8,9 /)
	       opts_cparam@cnFillPattern = 17  ; 17=stipple
	       opts_cparam@cnFillDotSizeF = 0.000005 ; used only for stipple pattern
	       opts_cparam@cnLinesOn = True
	       opts_cparam@cnLineLabelsOn = True
	       opts_cparam@cnLineColor = "black"
mp = True
mp@mpDefaultFillPattern=-1


;opts_bparam@lbOrientation = "vertical"

end if






;CAPE tstorm potential strength  0=none, 300-1000=weak, 1000-2500=moderate, 2500-5300=strong  
;pgwind goes from white to ltgreen to green to pink to purple to orange to dkorange to red   
if( plot_param.eq."cape") then
   setvalues wks
    "wkColorMap": "pgwind"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
     newindex = NhlNewColor(wks,0.0,0.0,0.0)  ;add black for contour lines
 opts_bparam@ContourParameters = (/ 300., 2700.,400. /)
 opts_bparam@MainTitle = "CAPE TS poten. 300-1000=weak, 1000-2500=moderate, 2500-5300=strong"
opts_bparam@cnFillOn  =  True                                         ;use the next 3 to print grid outlines
opts_bparam@cnFillMode          = "CellFill"
opts_bparam@cnCellFillEdgeColor           = 1
opts_bparam@cnLineColor = "black"
end if

; wrf variables are lower case for wrf part.
if( plot_param.eq."wrf=ALBEDO" .or. plot_param.eq."wrf=SNOWNC"  )
opts_bparam@cnFillOn  =  True  ;use the next 3 to print grid outlines             
opts_bparam@cnLinesOn = True   ;
opts_bparam@cnFillMode          = "CellFill"                                                                             
opts_bparam@cnCellFillEdgeColor = "gray"
opts_bparam@UnitLabel =  "index"
end if

if( plot_param.eq."wrf=SNOWC" ) then
opts_bparam@cnFillOn  =  True                                         ;use the next 3 to print grid outlines
opts_bparam@cnFillMode          = "CellFill"
opts_bparam@cnLinesOn = True   ;
opts_bparam@cnCellFillEdgeColor = "black"
opts_bparam@cnLevelSelectionMode = "ExplicitLevels" 
opts_bparam@cnLevels  = (/ 0 /)
opts_bparam@cnFillColors = (/3,60/)
;opts_bparam@cnGridBoundPerimOn = True
;opts_bparam@cnGridBoundPerimThicknessF = .7
end if

if( plot_param.eq."wrf=SNOW" ) then
opts_bparam@MainTitle ="Snow Water Equivalent from the WRF model in kg m-2"
opts_bparam@cnFillOn  =  True                                         ;use the next 3 to print grid outlines
opts_bparam@cnFillMode          = "CellFill"
opts_bparam@cnLinesOn = True   ;
opts_bparam@cnCellFillEdgeColor = "black"
opts_bparam@cnLevelSelectionMode = "ExplicitLevels" 
opts_bparam@cnLevels  = (/-1,0,1,2,3,4,5,6,7 /)
opts_bparam@cnFillColors = (/-1,3,15,20,30,40,50,60,60,60/)
;opts_bparam@cnGridBoundPerimOn = True
;opts_bparam@cnGridBoundPerimThicknessF = .7
end if


if( plot_param.eq."wrf=SNOWC" ) then
opts_bparam@ContourParameters = (/ 0, 1, 1 /)
end if


;  cnLevelSelectionMode
;  cnMinLevelValF
;  cnMaxLevelValF
;  cnLevelSpacingF
      



;; see fixedcolors.ncl for source of this.  qdatime isn't know by this script.  
if( plot_param .eq. "sfctemp" ) then 
   opts_bparam=True;
   setvalues wks
;;;;   "wkColorMap": "redblue"                ;
;;   "wkColorMap": "coldhottj"                ;coldhottj has only 18 colors.
;;;    "wkColorMap": "WhViBlGrYeOrRe"                ;coldhottj has only 18 colors.
    "wkColorMap": "bluewhitegreenyellowred"                ;Starts at white 254 colors throws errors if temps below 31

;newindex = NhlNewColor(wks,0.2,0.2,1.)
;newindex = NhlNewColor(wks,0.87,0.96,1.)

;    "wkForegroundColor" : (/.2,.2,1./)
;    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues

;;; opts_bparam@
opts_bparam@cnMonoFillColor = False
opts_bparam@cnLevelSelectionMode = "ExplicitLevels"

;opts_bparam@cnMinLevelValF = -30
;opts_bparam@cnMaxLevelValF =  120
;opts_bparam@cnLevelSpacingF = 5
;;winter    opts_bparam@cnLevels = (/ -22.0,-13.0,-4.0,5.0,14.0,23.0,31.0,32.0,33.0,41.0,50.0,59.0,68.0,77.0,86.0,95.0,104.0,113.0 /)
;summer    

    opts_bparam@cnLevels = (/0.,3., 6., 10.,13.,15.,18.,21.,24.,27.,30.,31.,32.,33.,36.,39.,42.,45.,48.,51.,54.,57., 60., 63., 66., 69., 72., 75., 78., 81., 84., 87., 90., 95., 100., 105.,110.,115. /)
opts_bparam@cnFillColors = (/5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 61, 65, 70, 75, 80, 85, 90, 95, 100,105, 110, 115, 120, 125, 130, 135, 145, 150, 165, 175, 185, 195, 205,  210, 215, 229 /)
opts_bparam@lbLabelStride = 3 

;;opts_bparam@ContourParameters = (/ -31., 113., 9. /) 
;;(/ -31,-22,-13,-4,5,14,23,32,41,50,59,68,77,86,95,104. /)
;opts_bparam@cnLevels =    (/ 31.0,33.0,36.0,39.0,42.0,45.0,48.0,50.0,54.0,57.0,60.0,63.0,66.0,68.0,72.0,75.0,81.0,86.0,90.0,95.0,100.0 /)
;opts_bparam@cnFillColors =(/ 2, 4,  12,  13,  14,  15,  16,  17,  18,  19,  19, 20 ,  21,  22,  23,  24,  25,  26, 27 ,29  ,30  , 50, 55  /)  ; from my explicitly set palette.
;  opts_bparam@cnFillColors =          (/ 9, 10,  11,  12,  13,   14,   15,  16 ,17 ,17, 17, 0, 1 /)  ; from my explicitly set palette.
;; Above here uncomment and end if below

;  if(    string_pattern_grep(qdatime,"Mar").gt.0 \ 
;  .or. string_pattern_grep(qdatime,"Apr").gt.0 \ 
;  .or. string_pattern_grep(qdatime,"May").gt.0 ) then 
    ;;; SPRING VALUE 
;    opts_bparam@ContourParameters = (/ 40., 80., 2. /) 
;  else 
;  if(    string_pattern_grep(qdatime,"Jun").gt.0 \ 
;  .or. string_pattern_grep(qdatime,"Jul").gt.0 \ 
;  .or. string_pattern_grep(qdatime,"Aug").gt.0 ) then 
;    ;;; SUMMER VALUE 
;    opts_bparam@ContourParameters = (/ 60., 100., 2. /) 
;  else 
;  if(    string_pattern_grep(qdatime,"Sep").gt.0 \ 
;  .or. string_pattern_grep(qdatime,"Oct").gt.0 \ 
;  .or. string_pattern_grep(qdatime,"Nov").gt.0 ) then 
;    ;;; FALL VALUE 
;    opts_bparam@ContourParameters = (/ 40., 80., 2. /) 
;  else 
    ;;; WINTER VALUE 
;    opts_bparam@ContourParameters = (/ 20., 60., 2. /) 
;  end if 
;  end if 
;  end if 

end if 



if( plot_param .eq. "mslpress") then
opts_bparam  = True;
opts_bparam@UnitLabel="mm/hr"
;opts_bparam@cnFillOn  = False;
  setvalues wks
;       "wkColorMap": "hotcoldtj"
       "wkColorMap": "StepSeq25"
;       "wkColorMap": "rainbow"
;       "wkColorMap": "BkBlAqGrYeOrReViWh200"
;       "wkColorMap": "BlWhRe"
        "wkForegroundColor" : (/.2,.2,1./)
        "wkBackgroundColor" : (/.87, .96, 1./)
	
   end setvalues
opts_ter = False
opts_ter@cnLineColor = -1  ;transparent
; opts_bparam@ContourParameters = (/ 0., 0.,0. /)
; opts_bparam@gsnSpreadColors = True                    ; use full colormap
; opts_bparam@gcnContourLineThickness = 1.8	
;opts_bparam@cnFillColors = True;
;opts_bparam@cnMonoFillColor = True;

opts_bparam@cnLinesOn = True
;opts_bparam@vpWidthF = 0.90

opts_bparam@cnLineLabelsOn = True
opts_bparam@cnLineLabelBackgroundColor = -1;
opts_bparam@cnMonoLevelFlag = False;
opts_bparam@cnLineLabelInterval = 1 ;  
opts_bparam@cnMonoLineLabelFontColor = True;
;opts_bparam@cnConstFLabelFont = "times";
opts_bparam@cnExplicitLabelBarLabelsOn = False;
;opts_bparam@
;opts_bparam@cnExplicitLineLabelsOn = False;
opts_bparam@cnLineLabelPlacementMode = "Computed";
;LineAndLabel = True;
opts_bparam@cnMonoLineColor = True;
opts_bparam@cnMonoLineThickness= True;
opts_bparam@cnLineThicknessF = 1.8;
;opts_bparam@cnConstFLabelOn = True;

;opts_bparam@cnLevelFlags = "LineAndLabel";

;opts_bparam@cnLineColor = "violet";
opts_bparam@cnLineColor = "yellow";
;opts_bparam@ContourParameters= (/0.,1.,0. /)
   opts_bparam@cnLevelSelectionMode = "ManualLevels"
   opts_bparam@cnMinLevelValF = 990.0
   opts_bparam@cnMaxLevelValF =1020.0
   opts_bparam@cnLevelSpacingF = 2.0
   


end if 

;reset these after they were changed above for mslpress doesn't work...still switches for other maps.
opts_ter = True
opts_ter@cnLineColor = "black"



;pgwind has only 8 colors if want something with more need a different colormap
; this makes anything less than 200fpm a very light green above 900fpm is red


;; vertical velocity params  adjusted to include 200 so efficient wings arent discriminated against tj


if( plot_param .eq. "bsratio" ) then
opts_bparam@MainTitle = "Buoyancy/Shear Ratio: Thermal Drift or Shred  Want Values >10 " ;
setvalues wks
    "wkColorMap": "whgryeorre13"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
  opts_bparam@ContourParameters = (/ 5., 12.,1. /)
opts_ter = True
opts_ter@cnLineColor = "black"
  
end if 

;;none of this does anything for the slice.  wrf_plot.ncl seems to control most everything, especially the number of levels..
;move it to  rasp.site_load.bl-xsection.ncl
;if ( plot_param .eq. "xbl_-122.43_48.61_45.0" ) then
;if( name_max .ge. 4 .and. name_chars(0:3) .eq. "xbl_" ) then

;; Extract the accumulation time from the parameter name
;if ( plot_param .eq. "xbl_" ) then
;   setvalues wks
;    "lbTitleOn" : True
;    "wkColorMap": "pgwind"
;    "wkForegroundColor" : (/.2,.2,1./)
;    "wkBackgroundColor" : (/.87, .96, 1./)
;   end setvalues
;opts_cparam = True;
;opts_bparam = True;
;opts_ws =True;
;opts_ws@lbTitleOn = True;
;opts_cparam@cnLabelBar = 
;opts_bparam@title3
;SUBTITLE = "Slice goes through Blanchard Launch past Black Mt." ;
;opts_w@SubTitle = "Slice goes through Blanchard Launch past Black Mt." ;
;end if








;old opts_cparam@cnFillPattern = 14  ; 14=triple-hash
;;; use minimum stipple size - seems to work best after raster conversion
;old  opts_cparam@cnFillDotSizeF = 0.0005 ; used only for stipple pattern
;older (gives "interference pattern" due to raster conversion)  opts_cparam@cnFillDotSizeF = 0.002 ; used only for stipple pa$
;;; set pattern color
											    

;;lift altitude params   without specifying these will use the overall default colormap 
if( ( plot_param .eq. "hwcrit" ) .or. ( plot_param .eq. "hglider" ) .or. ( plot_param .eq. "hbl" )  .or. ( plot_param .eq. "dbl" ) )   then
   setvalues wks
    "wkColorMap": "whgryeorre13"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
    opts_bparam@ContourParameters = (/ 500., 11000., 1000. /)
    opts_ter = True
    opts_ter@cnLineColor = "black"
    opts_mp = True
    opts_mp@cnLineColor = "black"
    
 end if

if ( plot_param .eq. "dwcrit" )
setvalues wks
    "wkColorMap": "whgryeorre13"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
end setvalues
  opts_bparam@ContourParameters = (/ 200., 1850.,150. /)
  opts_ter = True 
 opts_ter@cnLineColor = "black"

end if

;;cloud altitude params  without specifying these will use the overall default colormap 
if( ( plot_param .eq. "zsfclcl" ) .or. ( plot_param .eq. "blcwbase" ) .or. ( plot_param .eq. "zblclmask" )  .or. ( plot_param .eq. "zblcl" ) .or. ( plot_param .eq. "zsfclclmask" )  .or. ( plot_param .eq. "zwblmaxmin" ) )   then
   setvalues wks
    "wkColorMap": "whgryeorre13"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
    opts_bparam@ContourParameters = (/ 500., 11000., 1000. /)
    opts_ter = True
    opts_ter@cnLineColor = "black"
end if


;;wind shear doesn't get called from wind, so put it here.
;if(plot_param .eq. "blwindshear"  ) then
; gsn_define_colormap(wks,"pgwind");
; setvalues wks
;  "wkColorMap": "pgwind"
;  "wkForegroundColor" : (/.2,.2,1./)
;  "wkBackgroundColor" : (/.87, .96, 1./)
;  end setvalues
; this sets the green purple orange range 21 is red
;opts_bparam@ContourParameters = (/ 3., 21., 3. /);
;end if	  


if( plot_param .eq. "wblmaxmin" )
opts_bparam@MainTitle = "BL Max. Up/Down Motion -- Convergence";
;opts_bparam@cnFillOn  =  True                                         ;use the next 3 to print grid outlines
;opts_bparam@cnFillMode          = "CellFill"
;opts_bparam@cnCellFillEdgeColor           = 1
;opts_ter = True
;opts_ter@cnLineColor = "black"

;end if

;; see also rasp.site_load.pressure-level.ncl
;; This unbalanced scale has white on either side of zero.
;;if ( plot_param .eq. "wblmaxmin" ) then
;was  opts_bparam@ContourParameters = (/ -120., 300., 60. /);  
   opts_bparam@ContourParameters = (/ -100., 300., 25. /);  

;    opts_bparam@ContourParameters = (/ -300., 300., 50. /)
;    gsn_define_colormap(wks,"blue2orange");     ViBlGrWhYeOrRe");

  gsn_define_colormap(wks,"converge2");     BlWhGrPiPuOrRe"); was converge 10 colors now converge2 20 color
   setvalues wks
      "wkColorMap": "converge2"            ;"BlWhGrPiPuOrRe"  
      "wkForegroundColor" : (/.2,.2,1./)		;dark blue
      "wkBackgroundColor" : (/.87, .96, 1./)		;pale aquaish 222 245 255
   end setvalues
opts_ter = True
opts_ter@cnLineColor = "black"
   
print("***************Plotting wblmaxmin ************************.")

end if


;; This has no effect here must be in rasp.site_load.pressure-level.ncl
if( (plot_param .eq. "press990") .or. (plot_param .eq. "press980") .or. (plot_param .eq. "press970") .or. (plot_param .eq. "press960") .or. (plot_param .eq. "press950") .or. (plot_param .eq. "press900") .or. (plot_param .eq. "press860") .or. (plot_param .eq. "press870") .or. (plot_param .eq. "press880") .or. (plot_param .eq. "press890") .or. (plot_param .eq. "press850") .or. (plot_param .eq. "press700") .or. (plot_param .eq. "press500") .or. (plot_param .eq. "press1000") ) then
;   opts_bparam@ContourParameters = (/ -120., 300., 60. /);  
   opts_bparam@ContourParameters = (/ -100., 300., 25. /);  
  gsn_define_colormap(wks,"converge2");     BlWhGrPiPuOrRe"); was converge 10 colors now converge2 20 colors
   setvalues wks
      "wkColorMap": "converge2"            ;"BlWhGrPiPuOrRe"  
      "wkForegroundColor" : (/.2,.2,1./)		;dark blue
      "wkBackgroundColor" : (/.87, .96, 1./)		;pale aquaish 
   end setvalues
   opts_w = True
   opts_w@MainTitle = "Vertical Velocity [cm/s] (convergence) & Wind [kt] at "+pressure+"mb"
   print(" variable pressure ="+pressure)
   print("*********************** Plotting a pressure level variable, "+plot_param+"  ******************************" )
end if

;; cloudcolors has progressive from white through light blue to gray to black 
if(( plot_param .eq. "blcloudpct" ) .or. ( plot_param .eq. "experimental2" ))
   gsn_define_colormap(wks,"cloudcolors");
opts_bparam@ContourParameters = (/ 12.5, 87.5, 12.5 /)
opts_ter = True
opts_ter@cnLineColor = "black"

  end if

if (( plot_param .eq. "wrf=CLDFRA" ) .or. ( plot_param .eq. "wrf=CFRACL" )  .or. ( plot_param .eq. "wrf=CFRACM" ) .or. ( plot_param .eq. "wrf=CFRACH" ) ) then
   gsn_define_colormap(wks,"cloudcolors");
opts_bparam@ContourParameters = (/ 0.125, 0.875, 0.125 /)

end if



if( plot_param .eq. "sfcsunpct" ) then
     setvalues wks
      "wkColorMap": "sunshine_diff_12lev"
      "wkForegroundColor" : (/.2,.2,1./)
      "wkBackgroundColor" : (/.87, .96, 1./)
     end setvalues
;; changed May 19 2016 ends in red.
    opts_bparam@ContourParameters = (/ 0., 99., 9. /)
end if

;if( plot_param .eq. "sfcsun" ) then
;     setvalues wks 
;     "wkColorMap": "BlueYellowRed"
;      "wkForegroundColor" : (/.2,.2,1./)
;      "wkBackgroundColor" : (/.87, .96, 1./)
;     end setvalues
;    opts_bparam@ContourParameters = (/ 0.0, 1280., 5. /)
;end if





;;;; PAULS ;;;;
if( plot_param .eq. "wrf=RAINNC" ) then
   setvalues wks
   "wkColorMap": "whgryeorre13"
;    "wkColorMap": "cloudcolors"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
  opts_bparam@ContourParameters = (/ 0., 11., 1. /)
opts_ter = True
opts_ter@cnLineColor = "black"

end if

if((plot_param .eq. "wrf=TSLB=0" ) .or. (plot_param .eq. "wrf=TSLB=1" ) .or. (plot_param .eq. "wrf=TSLB=2" ) .or. (plot_param .eq. "wrf=TSLB=0" ) .or. (plot_param .eq. "wrf=TSLB=3") )

     setvalues wks
  "wkColorMap": "coldhottj"
     end setvalues
; the levels were getting overridden by some drjack script  -- until ading the explicit cnLabelStrings
print ("Inside rasp.site_load.contour-parameters.ncl ")
          opts_bparam = True
	  opts_bparam@cnLevelSelectionMode = "ExplicitLevels"
	  opts_bparam@cnLevels =     (/40.,48.0,49.0,50.0,51.0,52.0,53.0,54.0,55.0,56.0,57.0,58.0,59.0,60.0,61.0,62.0,63.0,64.0,66.0,69.0 /)
	  opts_bparam@lbLabelStrings = (/"40","48","49","50","51","52","53","54","55","56","57","58","59","60","61","62","63","64","66","69","70","71" /)
	  opts_bparam@cnFillColors = (/1,  2,    3,   5,   9,  10,   11,  12,  13,  13,  14,  14,  14,  14,  14, 15,  16,  17,  18,  19 ,19 /)
	  opts_bparam@cnExplicitLabelBarLabelsOn = True;
	  opts_bparam@cnExplicitLegendLabelsOn = True;
	  opts_bparam@cnLinesOn = True
          opts_bparam@cnFillOn = True
          opts_bparam@cnLineLabelsOn = True 
;	  opts_bparam@cnMinLevelValF = 41.
;	  opts_bparam@cnMaxLevelValF = 68.
print(opts_bparam)

;wrf=TSLB = (wrf=TSLB-273)*1.8
bparam = ((bparam-273)*1.8)  + 32
printVarSummary(bparam)
;if(plot_param .eq. "wrf=TSLB=0" ) 
;end if
;if(plot_param .eq. "wrf\=TSLB\=1" ) 
;wrf=TSLB=1 = (wrf=TSLB=1-273)*1.8
;end if
;if(plot_param .eq. "wrf\=TSLB\=2" ) 
;wrf=TSLB=2 = (wrf=TSLB=2-273)*1.8
;end if
;if(plot_param .eq. "wrf\=TSLB\=3" ) 
;wrf=TSLB=3 = (wrf=TSLB=3-273)*1.8
;end if

end if

if( plot_param .eq. "rain1" ) then
   setvalues wks
    "wkColorMap": "whgryeorre13"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
   
;  opts_bparam@cnLevels=(/ 0.,1.,2.,3.,4.,5.,6.,7.,9.,10.,11.,12.,13.,14.,15.,16.,17.,18.,19.,20.,21.,22.,23.,24.,25.,26.,27.,29.,30. /)
;    opts_bparam@cnMaxLevelCount=12
;    opts_bparam@cnLevelSelectionMode="ManualLevels"
opts_bparam@cnLevelSelectionMode = "ExplicitLevels" 
opts_bparam@cnLevels=(/ 0.,0.1,1.,2.,3.,4.,5.,6.,7.,9.,10. /)
opts_bparam@cnFillColors = (/ -1,2,3, 4, 5, 6, 7, 8, 9, 10,11,12 /) 

;  -1 is transparent  but indexnumber for white is 2... where do they start?
; "ManualLevels"    
    ; "EqualSpacedLevels" 
    ; "ExplicitLevels"
;    opts_bparam@cnMinLevelValF=0. 
;    opts_bparam@cnMaxLevelValF=36.
;    opts_bparam@cnLevelSpacingF=3.

; the setting below seems to work.  needs further verification as of may 28 2012 AM.

;opts_bparam@ContourParameters = (/ 3., 36., 3. /)  ; works but no finness.  so if over 3 cm it is going to be red.
;opts_bparam@ContourParameters = (/ 1., 12., 1. /)  ; works but no finness.  so if over a cm it is going to be red.
opts_bparam@ContourParameters = (/ 1., 25., 2. /) 
;  opts_bparam@ContourParameters = (/ 1., 11., 1. /)
; used to be this: leaves zero getting color...  opts_bparam@ContourParameters = (/ 0., 11., 1. /)
opts_ter = True
opts_ter@cnLineColor = "black"

end if

 
;;;        RAIN PLOT --- Courtesy Hendrik :-) --- Added 3/1/2009
									 
   if( name_max .ge. 4 .and. name_chars(0:3) .eq. "rain" ) then
     ;; Extract the accumulation time from the parameter name
     acctime = stringtointeger( chartostring( name_chars(4:name_max) ) )

     ;; Get filename for the previous forecast. Needed to subtract earlier rain.
     filename_chars = stringtochar( ENV_NCL_FILENAME )
     len_filename = dimsizes(filename_chars)-2
     ; date of current file
     sdate = string_target_replace(chartostring( filename_chars(len_filename-18:len_filename-6)), "_", "-" )
     sdate = string_target_replace(chartostring( filename_chars(len_filename-18:len_filename-6)), "_", "-" )
     stime = filename_chars(len_filename-4:len_filename)
     date  = stringtointeger(split_string_into_array( sdate,"-" ))
     ; date of previous file
     prevdate  = jul2greg( greg2jul(date(0),date(1),date(2),date(3)) - acctime/24. + 0.00001 )
     sprevdate = sprinti("%d-",prevdate(0)) + sprinti("%02d-",prevdate(1)) + sprinti("%02d_",prevdate(2)) + sprinti("%02d:",prevdate(3)) + stime
     prevfilename = chartostring( filename_chars(0:len_filename-19)) + sprevdate
     print ( "prevfilename = "+prevfilename )

     delete(filename_chars)
     delete(len_filename)
     delete(date)
     delete(stime)
     delete(sdate)
     delete(prevdate)
     delete(sprevdate)
       print ("Trying to get a rain plot. Why does it take so long?")

     ;; If the previous file exists -> load it, subtract earlier rain, plot it.
     if (isfilepresent(prevfilename)) then
       prevfile = addfile( prevfilename+".nc", "r" )

       bparam = new( (/jsize,isize/), float )
       bparam_filename = string_target_replace( ENV_NCL_FILENAME, "dummy","rain" )

       rainc  = a->RAINC
       rainnc = a->RAINNC
       prevrainc  = prevfile->RAINC
       prevrainnc = prevfile->RAINNC

       ; Use NCL operator > to make sure all values >=0.0
       rainc  = rainc > 0.0
       rainnc = rainnc > 0.0
       prevrainc  = prevrainc > 0.0
       prevrainnc = prevrainnc > 0.0

       rainTot = (/ rainc + rainnc - prevrainc - prevrainnc /)
       bparam = rainTot
       opts_bparam = True
       ;opts_bparam@UnitLabel = "[mm]"
       opts_bparam@MainTitle = acctime+" hr Accumulated Rain"
       qparaminfo = ""

       delete(prevfile)
       delete(rainc)
       delete(rainnc)
       delete(prevrainc)
       delete(prevrainnc)
     else
       print ("Can't open "+prevfilename+" needed for rain plot.")
     end if
     delete(acctime)
     delete(prevfilename)
opts_ter = True
opts_ter@cnLineColor = "black"

   end if        ; end of rain plot section

opts_ter = True
opts_ter@cnLineColor = "black"
if( REGION .eq. "PNW" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 225. /) ;
else
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
end if
end if


if( REGION .eq. "TIGER" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
else
opts_ter@ContourParameters = (/ 0., 0., 125. /) ;
end if
end if


if( REGION .eq. "PNWRAT" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 300. /) ;
else
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
end if
end if


if( REGION .eq. "PNWRAT2" .or. REGION .eq. "PNWRAT2-WINDOW" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
else
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
end if
end if

print("IWINDOW="+IWINDOW)

;                                                  zsfclclmask
if(( plot_param.eq."zsfclcl").or.( plot_param.eq."zsfclclmask").or.( plot_param.eq."zblcl") ) then
print("Doing a cloudbase map. ")
;opts_bparam@cnLinesOn = True
opts_bparam@cnLineLabelsOn = True
opts_ter = True
opts_ter@cnLineColor = "black"

end if

; tjo added March 22, 2011 to make more visual reference with zero as white using the blue2orange palette 
; zsfclcldif - "Cu Potential" = hbltop - zsfclcl
; this is cumulus potential   A difference;  hbltop - zsfclcl

if( plot_param.eq."zsfclcldif")then
opts_bparam@ContourParameters = (/ -4800., 4800., 800. /)
setvalues wks
          "wkColorMap": "blue2orange"
          "wkForegroundColor" : (/.2,.2,1./)
      "wkBackgroundColor" : (/.87, .96, 1./)
         end setvalues
opts_ter = True
opts_ter@cnLineColor = "black"

end if



if(( plot_param.eq."zblcldif").or.( plot_param.eq."zlcwbase") ) then
opts_bparam@ContourParameters = (/ -4800., 4800., 1600. /)
;is (/ -5000., 5000., 1000. /) in  rasp.bparam_resources.ncl

   setvalues wks
          "wkColorMap": "cloudcolors"
          "wkForegroundColor" : (/.2,.2,1./)
	  "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
opts_ter = True
opts_ter@cnLineColor = "black"
		 
end if

if(( plot_param.eq."ter") .or. (plot_param .eq. "ter_zoom")) then
opts_bparam@MainTitle = "Lay of the Land" ;
setvalues wks
;    "wkColorMap": "topo_15lev"
    "wkColorMap": "updraft"
    "wkForegroundColor" : (/.2,.2,1./)
    "wkBackgroundColor" : (/.87, .96, 1./)
   end setvalues
   opts_ter = True
   opts_ter@cnLineColor = "black"
   opts_bparam@cnLevelSelectionMode=  "AutomaticLevels"
;    opts_bparam@cnLevelSelectionMode= "ManualLevels" ; "AutomaticLevels"
    opts_bparam@cnMinLevelValF =-1
    opts_bparam@cnMaxLevelValF= 3000
   opts_bparam@cnLevelSpacingF= 12
opts_ter=True    
opts_ter@ContourParameters = (/ 0., 0., 12. /) ;
opts_ter@cnLinesOn = False
;   opts_bparam@cnFillColor
; opts_bparam@ContourParameters = (/ 200., 1000.,100. /)
end if 





print(" ") 
print(" Doing a map of "+plot_param )
print(" ") 
 
