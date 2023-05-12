;;; TO ALTER BL CROSS-SECTION PLOT SECTION
;;; (cannot contain procedures or functions)
;tjtest print("sequence ------------------  rasp.site_load.bl-xsection.ncl "+REGION+"-----------------------")
if(isvar("REGION").and.isvar("plot_param")) then
;;test 
print("sequence ------------------  rasp.site_load.bl-xsection.ncl         "+REGION  + "   "+plot_param+"-----------------------")
end if

LFIXEDCOLOR = 1
opts_w=True
opts_w@UnitLabel = "Vertical Velocity [cm/s]"
opts_w@lbTitleString =  "Wind Vertical Velocity [cm/s] (not thermal)"

;if( name_max .ge. 4 .and. name_chars(0:3) .eq. "xbl_" ) then
;if ( plot_param .eq. "xbl_" ) then
;   setvalues wks
;    "wkColorMap": "GrYeOrRe"
;    "wkForegroundColor" : (/.2,.2,1./)
;    "wkBackgroundColor" : (/.87, .96, 1./)
;   end setvalues
;  opts_bparam = True ;
;   opts_bparam@cnLevelSelectionMode = "ExplicitLevels"
;   opts_bparam@ContourParameters = (/ -10., 0., 20., 30., 50., 80., 100. /)
;-20,80,5  opts_bparam@cnLevelSelectionMode = "ExplicitLevels"
;opts_cparam = True;
;opts_bparam = True;
;opts_w =True;
;opts_ws@lbTitleOn = True;
;opts_cparam@cnLabelBar = " Vertical Cross section parallel to Wind at ~C~ point of greatest convergence lift." 
;opts_bparam@title3
;SUBTITLE = "Slice goes through Blanchard Launch past Black Mt." ;
;opts_w@SubTitle = "Slice goes through Blanchard Launch past Black Mt." ;
;end if


