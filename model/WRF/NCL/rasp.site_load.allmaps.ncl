;;; TO ALTER ALL MAPS SECTION
;;; (cannot contain procedures or functions)
;wks = True;
;example - to eliminate all terrain contour lines:
;example   opts_ter@cnLinesOn = False
;example - to change terrain contour interval to 1000 feet/meters:
;example   
;opts_ter@ContourParameters = (/ 0., 0., 150. /) ;

;tj
if(isvar("REGION").and.isvar("plot_param")) then
;;test 
print("sequence ------------------  rasp.site_load.allmaps.ncl "+REGION  + "   "+plot_param+"-----------------------")
else 
if(isvar("REGION"))then
print("sequence ------------------  rasp.site_load.allmaps.ncl "+REGION  + "  -----------------------")
end if
end if

opts_sounding = True;
opts_w = True;
opts_ter = True;
opts_mp = True;
opts_mp@cnLineColor = "black"
opts_ter@cnLineColor = "black"
opts_soundingloc = True;

opts_soundingloc@txFontHeightF = 0.008 ;
opts_soundingloc@txFuncCode = "~";
opts_soundingloc@txJust = "CenterLeft"

;opts_mpDataBaseVersion = "NCARG4_1" ;;tjo 4test go back to rangs if no political boundaries appear
opts_mpDataBaseVersion = "rangs" ;;tjo 4test go back to rangs if no political boundaries appear
opts_mp@mpDataSetName = "Earth..4"   ;; tjo 4test
opts_mpOutlineBoundarySets ="AllBoundaries" ;; tjo 4test

;opts_mp@mpDataBaseVersion = "RANGS";
opts_w@pmLabelBarWidthF  = 0.6 ;   ;fit under map image
;opts_w@UnitLabel = "Vertical Velocity [cm/s]"

; ix  = str_index_of_substr(str, substr, 0)

; this only zooms the parameter map, not the background terrain plot. 
if(.not. isvar("zoom"))then
zoom=0
end if

if( zoom .ne. 0) then
opts_mp = True;
opts_mp@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
opts_mp@mpMinLatF      = 48.8
opts_mp@mpMaxLatF      = 49.
opts_mp@mpMinLonF      = -122.00
opts_mp@mpMaxLonF      = -122.3
opts_ter = True;
opts_ter@cnLinesOn = False;   ;  
;opts_ter@mpLimitMode    = "LatLon"          ; use lat/lon coordinates to limit area
;opts_ter@mpMinLatF      = 48.6
;opts_ter@mpMaxLatF      = 49.
;opts_ter@mpMinLonF      = -122.00
;opts_ter@mpMaxLonF      = -122.3
opts_ter@cnFillOn = True
opts_ter@cnFillMode = "AreaFill"  ;really need a gradient pallet for this.
end if


; IWINDOW did not seem to be getting set properly in rasp.ncl or not passed to here properly so use a local substitute
;if (str_index_of_substr(ENV_NCL_FILENAME, "-WINDOW", 0) .lt. 0)then
;L_IWINDOW=0

;else
;L_IWINDOW=1
;end if

;        lbtxtres = True
;	lbtxtres@txFuncCode    = "~"
        ;;; ADD UNITS TEXT
;        lbtxtres@txFontHeightF = 0.015                  
;        lbtxtres@txFont = "helvetica"
        ;;; add left side units text
;        lbtxtres@txJust = "CenterRight"         		
;gsn_text_ndc ( wks, "wxtofly~C~Pacific~C~Northwet~C~RASP~C~~C~Click~C~a region~C~or a~C~time~C~ above~C~to change~C~the ~C~forecast~C~map ~C~~C~ Click a~C~parameter~C~to the~C~left to~C~change to~C~the desired~C~forecast.~C~~C~Allow~C~time~C~for the~C~image~C~to load~C~~C~Not all~C~forecasts~C~are run~C~for every~C~time and~C~region.",0.01,0.59,lbtxtres )  ;tj add help to left margin
;0.59is ypostext   0.90949 is xNDC   0.03 is yNDC



;res@stMinArrowSpacingF = 0.006          ; arrow spacing.
;res@stArrowLengthF     = 0.02           ; changes the size of the arrows.
;res@stLineThicknessF   = 1.5            ; changes the line thickness
;res@stLineColor        = "DarkOrange"       ; changes color
;opts_st@stLineColor = "white" ;
;http://www.ncl.ucar.edu/Document/Graphics/color_table_gallery.shtml

;wks = gsn_open_wks("png", bparam)
;gsn_define_colormap(wks,"GrYeOrRe");
;  setvalues wks
;   "wkColorMap": "GrYeOrRe"
;   "wkForegroundColor" : (/.2,.2,1./)
;   "wkBackgroundColor" : (/.87,.98,1./)
;  end setvalues
	     

		    
;tj_blGR=		    
		    
;gsn_define_colormap(wks,"tj_blGR");		    
; gsn_define_colormap(wks,"Cat12");	

;title fonts
;res@LabelFontHeight

; IWINDOW is 1 for windowed domains and 0 otherwise

if ( IWINDOW .eq. 0 ) then
   opts_ter@ContourParameters = (/ 0., 0., 300. /) ;
   ;; put parameters for stage1 (non-windowed) plot here
  else
   opts_ter@ContourParameters = (/ 0., 0., 100. /) ;
   ;;; put parameters for stage2 (windowed) plot here
end if

if( REGION .eq. "PNW" ) then
 if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 300. /) ;
;push @{$PARAMETER_DOLIST{'PNW'}},('xbl_-122.43_48.61_45.0','xbl_-122.07_48.71_90.0','xbl_-121.94_47.48_90.0');
   ;;; put parameters for stage1 (non-windowed) plot here  
else
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
   ;;; put pasrameters for stage2 (windowed) plot here
 end if
end if

if( REGION .eq. "PNWRAT2" .or.  REGION .eq. "PNWRAT2-WINDOW" ) then
;if ( IWINDOW .eq. 0 ) then
;opts_ter@ContourParameters = (/ 0., 0., 300. /) ;
 ;push @{$PARAMETER_DOLIST{'PNW'}},('xbl_-122.43_48.61_45.0','xbl_-122.07_48.71_90.0','xbl_-121.94_47.48_90.0');
    ;;; put parameters for stage1 (non-windowed) plot here
;  else
 opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
       ;;; put pasrameters for stage2 (windowed) plot here
;end if
end if
	



if( REGION .eq. "NOOKSACK" .or. REGION .eq. "NOOKSACK_001" ) then
if ( IWINDOW .eq. 1 ) then
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
else
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
end if
end if

print(" IWINDOW = "+IWINDOW )
;print ("  substring value = "+testidx+"  so IWINDOW is = "+IWINDOW )

if( REGION .eq. "FRASER" ) then
;if ( IWINDOW .eq. 0 ) then
;opts_ter@ContourParameters = (/ 0., 0., 250. /) ;
;else
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
;end if
end if

if( REGION .eq. "FT_EBEY" ) then
;if ( IWINDOW .eq. 0 ) then
;opts_ter@ContourParameters = (/ 0., 0., 250. /) ;
;else
opts_ter@ContourParameters = (/ 0., 0., 50. /) ;
;end if
end if

if( REGION .eq. "PNW" .and. IWINDOW .eq. 0) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 225. /) ;
;;; put parameters for stage1 (non-windowed) plot here 
; this is a circle with a plus sign in it  needs to be in rasp.ncl.region.data for the labels too.


;do i=0,65
;ids(i)="~F34E~"
;opts_soundingloc@txString = 
;end do

;opts_soundingloc@txFontColor = "white"   ;the map is so dense that white might show

else
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
;;; put parameters for stage2 (windowed) plot here
;;push@{$PARAMETER_DOLIST{'Blanchard'}},('xbl_-122.43_48.61_45.0');
end if
end if


if( REGION .eq. "PNW" .and. IWINDOW .eq. 1 ) then
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
end if




;if(LOUT.eq.0) then
;opts_ter@ContourParameters = (/ 0., 0., 100. /) ;
;end if


if( REGION .eq. "WOOD" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
;;push@{$PARAMETER_DOLIST{'WOOD'}},('xbl_-122.43_48.61_45.0','xbl_-122.07_48.71__90.0');
;;; put parameters for stage1 (non-windowed) plot here
else
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
;;; put parameters for stage2 (windowed) plot here
;;push@{$PARAMETER_DOLIST{'WOOD'}},('xbl_-122.43_48.61_45.0');
end if
end if

if( REGION .eq. "EBEY" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
;;; put parameters for stage1 (non-windowed) plot here
else
opts_ter@ContourParameters = (/ 0., 0., 50. /) ;
;;; put parameters for stage2 (windowed) plot here
end if
end if


;if( REGION .eq. "EBEY_LARGE" ) then
;if ( IWINDOW .eq. 0 ) then
;opts_ter@ContourParameters = (/ 0., 0., 300. /) ;
;;; put parameters for stage1 (non-windowed) plot here
;else
;opts_ter@ContourParameters = (/ 0., 0., 200. /) ;
;;; put parameters for stage2 (windowed) plot here
;end if
;end if

if( REGION .eq. "PNW_002"  ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 300. /) ;
;;; put parameters for stage1 (non-windowed) plot here
else
opts_ter@ContourParameters = (/ 0., 0., 225. /) ;
;;; put parameters for stage2 (windowed) plot here
end if
end if

if( REGION .eq. "PNW_002-WINDOW"  ) then
;if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 250. /) ;
end if


if( REGION .eq. "PNWB4" .or. REGION .eq. "tj2"  ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 350. /) ;
;;; put parameters for stage1 (non-windowed) plot here
else
opts_ter@ContourParameters = (/ 0., 0., 225. /) ;
;;; put parameters for stage2 (windowed) plot here
end if
end if

if( REGION .eq. "PNWB4-WINDOW" .or. REGION .eq. "tj2-WINDOW"  ) then
;if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 225. /) ;
end if


;if( REGION .eq. "NWNESTS" ) then



if( REGION .eq. "NOOKSACK" ) then
if ( IWINDOW .eq. 0 ) then
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
;;; put parameters for stage1 (non-windowed) plot here
else
opts_ter@ContourParameters = (/ 0., 0., 150. /) ;
;;; put parameters for stage2 (windowed) plot here
end if
end if


if ( REGION .eq. "TIGER" .or. REGION .eq. "TIGER-WINDOW")  then
;if ( IWINDOW .eq. 0 ) then
;opts_ter@ContourParameters = (/ 0., 0., 175. /) ;
;else
opts_ter@ContourParameters = (/ 0., 0., 100. /) ;
;end if
end if



;;; colors for soundings  create and load rasp.site_load.soundings.ncl
;;; load that from skewt



;***********************************************
; CSM_Graphics: color_6.ncl
;***********************************************
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl" 

;begin
;************************************************
; Read the file
;************************************************
;  in    = addfile("80.nc","r")
;  TS    = in->TS
    ;************************************************
    ; create plot
    ;************************************************
;   wks = gsn_open_wks("ps","color")              ; open a ps file
;   gsn_define_colormap(wks,"gui_default")
;	res                      = True               ; plot mods desired
;	res@tiMainString         = "Explict Contour Levels"
;	res@cnFillOn             = True               ; turn on color fill
;	res@cnLinesOn            = False              ; turn off contour lines
;	res@gsnSpreadColors      = True               ; use full colormap
;   	res@lbOrientation        = "vertical"         ; vertical label bars
;    
;      res@cnLevelSelectionMode = "ExplicitLevels"   ; set explicit contour levels 
;  res@cnLevels   = (/232.7,234.2,238,240,244,248.4,252,258.3,276,286.5,292.1,300,306/)
;  res@mpFillOn             = False              ; turn off gray continents
;  res@mpCenterLonF         = 180                ; Centers the plot at 180 
;    
;      plot = gsn_csm_contour_map_ce(wks,TS(0,:,:), res)   ; create plot
        
;	end
	
;; the following works as a separate file loaded just before the final frame(wks)  load "timestamp.ncl"	
;  operator="TJ Olney"
;        lbtxtres = True;
;	lbtxtres@gsnFrame = False
;	lbtxtres@gsnDraw = False
;	lbtxtres@txFuncCode    = "~"
;	lbtxtres@txFontHeightF = 0.015
;	lbtxtres@txFontHeightF = 0.015
;	lbtxtres@txJust = "CenterLeft"
;	; position lower left corner of whole plot
;	lbtxtres@draworder = 
;	timestamp=systemfunc("date +%H:%M_%Z")
;       timestamp="~F14~~Z60Q~plotted~C~"+get_script_name()+"~C~ "+timestamp+"~C~~F14~"+operator+"~C~"
;      timestampyNDC = 5*lbtxtres@txFontHeightF  ;was 4*
;      timestampxNDC = .005      ;lower left hand corner   

;draw the timestamp  This may have to move to the end of a script if you need it to overwrite something 
;gsn_text_ndc ( wks, timestamp,timestampxNDC,timestampyNDC,lbtxtres )
	



