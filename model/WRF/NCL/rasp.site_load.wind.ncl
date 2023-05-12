
;;; TO ALTER WIND PLOT SECTION
;;; (cannot contain procedures or functions)
;;;  for additional information, see "Set Fixed Contour Levels" at
;;;  http://www.drjack.info/twiki/bin/view/RASPop/PlotFormatParameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;weather.css background is  223, 247, 255
;wks = True;
print("sequence ------------------  rasp.site_load.wind.ncl "+REGION  + "   "+plot_param+"-----------------------")
LFIXEDCOLOR = 1


opts_st = True

;;; WIND SPEEDS
opts_st@stLineColor = "red";
opts_st@stArrowStride = 2          ;hange from 4 2016-05-17 default=2
opts_st@stLineStartStride = 4      ; change from 6 2016-05-17  default=2  largernumber tends to give lines in bunches
opts_st@stLineThicknessF = 1.3;	1.7; 2.0 ;1.3   ;was 1
opts_st@stArrowLengthF = 0.013
opts_st@stMinLineSpacingF = 0.009
;opts_bparam@gsnSpreadColors = False;
;opts_bparam@cnSpanFillPalette = False;
;opts_bparam@vcSpanLevelPalette = False;
opts_st@stSpanLevelPalette = False;

if(REGION.eq."PNWRAT")
opts_st@stArrowStride = 2          ; default=2
opts_st@stLineStartStride = 3
opts_st@stLineThicknessF = 1.8     ; 2016-05-17 
opts_st@stMinLineSpacingF = 0.005  ;2016-05-17
end if


;if(.not.isdefined("plottype"))
;plottype="x11"
;end if

if(.not.isdefined("wks"))
 wks = gsn_open_wks(plottype, outplotfile)
end if

if( (plot_param .eq. "sfcwind") .or.  \
    (plot_param .eq. "blwind") .or. \
    (plot_param .eq. "tenmwind") .or. \
    (plot_param .eq. "sfcwind0") .or. \
    (plot_param .eq. "sfcwind2")) then  
;   .or. (plot_param .eq. "blwindshear" ) ) then

gsn_define_colormap(wks,"updraft_pgwind");
 setvalues wks
  "wkColorMap": "updraft_pgwind"  
  "wkForegroundColor" : (/.2,.2,1./)   ;dark blue
;  "wkForegroundColor" : (/0.,0.,0./)  ;black
  "wkBackgroundColor" : (/.87, .96, 1./)  ;light bluegreen
 end setvalues
newindex = NhlNewColor(wks,0.6,0.6,0.6) ;20 grey
newindex = NhlNewColor(wks,1.0,0.0,1.0) ;21 magenta
newindex = NhlNewColor(wks,1.0,0.0,0.0) ;22 red
newindex = NhlNewColor(wks,0.0,0.0,0.0) ;23 black   
   opts_soundingloc = True
   opts_soundingloc@txFont = "helvetica"   ;execption april 2010
   opts_soundingloc@txFontColor = 23; "black"  ; was 8  before that  1 tj use foreground color from pallet black would be better white
	 
; this sets the green purple orange range 21 is red
; opts_ws@ContourParameters = (/ 3., 21., 3. /);  wrf way.
  opts_ws@cnSpanFillPalette = False;
  opts_ws@cnLevelSelectionMode = "ExplicitLevels"
  opts_ws@cnLevels         = (/ 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0,  30.0 /)    ; my PG/HG touch points.
  opts_ws@cnMonoFillColor = False
  opts_ws@cnMonoFillPattern = False  ;elements of this array of type NhlTFillIndexGenArray  for a contour fill area. 
  opts_ws@cnFillColors =   (/12, 13, 14, 15,  16,  17,  18,   19,   21,  22 /)  ; from my explicitly set palette.
  opts_ws@cnFillPatterns = (/ 0,  0,  0,  0,   0,   0,   0,    0,    0,  14 /)  ; 16 xhatch 14 xhatch   17 is stipple all solid until second red
  ;;;Note that there is always one more fill area than there are contour levels.  
;  opts_ws@gsFillLineThicknessF=2
  opts_ws@cnFillScaleF = .5
;  opts_ws@dotsize = 0.005
;  opts_ter = True
;  opts_ter@cnLineColor = "black"

;updraft_pgwind.rgb 
;ncolors=18
;2 255     255     255 white
;3 250     240     230
;4 200     255     200
;5 120     255     120
;6 21      255      21
;7 255     187     255     
;8 204     191     255
;9 255     204       0
;10 255    153       0
;11 255     61      61 
;# 2-11 updraft then 12-19 pgwind
;12 255    255     255  white
;13 229    255     229
;14 51     255      51
;15 255    187     255     
;16 204    191     255
;17 255    204       0
;18 255    153       0
;19 255     61      61 
;20 grey    
;21 magenta 
;22 red     
;23 black   

;end of wind parameter section 
;opts_ws@lbAutoManage= True
;opts_ws@lbOrientation = "vertical"
;opts_ws@pmLabelBarSide = "Right"
;opts_ws@pmLabelBarOrthogonalPosF = .94
;opts_ws@pmLabelBarParallelPosF =  .5
end if




if     (plot_param .eq. "bltopwind") then
gsn_define_colormap(wks,"GrYeOrRe");
   setvalues wks
  "wkColorMap": "GrYeOrRe"  
  "wkForegroundColor" : (/.2,.2,1./)   ;dark blue
;  "wkForegroundColor" : (/0.,0.,0./)  ;black
  "wkBackgroundColor" : (/.87, .96, 1./)  ;light bluegreen
 end setvalues
newindex = NhlNewColor(wks,0.0,0.0,0.0) ;23 black
; with this there, contours are black, but last value on legend is also black
; newindex = NhlNewColor(wks,0.0,0.0,0.0) ; black   
; are contours still black without it?

opts_ws@ContourParameters = (/ 3., 75., 3. /)
opts_ter = True;
opts_ter@cnLineColor ="black";
end if






;if( (REGION .eq. "PNW") .or. (REGION .eq. "BOW") .or. (REGION .eq. "BOW-WINDOW")   ) then;
;		opts_st@stLineThicknessF = 1.8   ;was 1
;		opts_st@stArrowLengthF = 0.02 ; was .0125
;                opts_st@stLineStartStride = 2      ; default=2  largernumber tends to give lines in bunches
;end if

;if( (REGION .eq. "VAIL") .or. (REGION .eq. "VAIL-WINDOW")  ) then
;		opts_st@stLineThicknessF = 1.8   ;was 1
;		opts_st@stArrowLengthF = 0.02 ; was .0125
;                opts_st@stLineStartStride = 2      ; default=2  largernumber tends to give lines in bunches
;                opts_st@stArrowStride = 1          ; default=2
;end if



