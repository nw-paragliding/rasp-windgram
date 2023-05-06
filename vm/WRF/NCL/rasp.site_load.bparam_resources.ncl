; since rasp.bparam_resources.ncl  seems to govern all positioning parameters, to override any they need to be loaded at the end
; of that file in this file.
; 
; should have personal redefinitions of parameters and parameter resources for formatting in this file
; note that @ContourParameters is shorthand for wrf variables 
; substitutes for 4 @cnContour resources
; 
;tjtest 
print("sequence ------------------  rasp.site_load.bparam_resources.ncl    "+REGION  + "   "+plot_param+" -----------------------")
opts_bparam = True
		opts_bparam@pmLabelBarWidthF  = 0.65  ; over-ride the default.
;$SITEARG doesnt carry through to here 

;run=systemfunc("ls -la $BASEDIR/RASP/RUN/done_start.$SITEARG |sed -e 's#^.*200#200#' -e 's#\/.*$##'")
;runtime=systemfunc("ls -la $BASEDIR/RASP/RUN/done_start.$SITEARG |sed -e 's#^.*200#200#' -e 's#\/.*$##' |sed -e 's# #@#' -e 's#.*@##'")
;rundate=systemfunc("ls -la $BASEDIR/RASP/RUN/done_start.$SITEARG |sed -e 's#^.*200#200#' -e 's# .*$##'")
;leftmarginmessage = "~F4~RASP Model Run~C~" + rundate + "~C~" + runtime + "~C~~F18~b~F4~wxtofly~C~Operator~C~~F10~TJ Olney~C~" ; ~F4~Pacific~C~Northwet~C~RASP~C~~C~Click~C~a region~C~or a~C~time~C~ above~C~to change~C~the ~C~forecast~C~map ~C~~C~ Click a~C~parameter~C~to~C~change to~C~the desired~C~forecast.~C~~C~Allow~C~time~C~for the~C~image~C~to load~C~~C~Not all~C~forecasts~C~are run~C~for every~C~time and~C~region."  ;tjo

; AS of ncl 6.2 gsnSpreadColors to True. However, this resource has been superceded by new resources cnSpanFillPalette, vcSpanLevelPalette, and stSpanLevelPalette
; doesn't work here  Not a valid resource at this time...
;opts_bparam@gsnSpreadColors = False;
opts_bparam@cnSpanFillPalette = False;
;opts_bparam@vcSpanLevelPalette = False;
;opts_bparam@stSpanLevelPalette = False;




if( plot_param .eq. "wrf=SNOWC" ) then
          opts_bparam = True
	  opts_bparam@MainTitle = "Snow cover flag yes or no"
	  opts_bparam@UnitLabel = ""
	  opts_bparam@ContourParameters = (/ 0, 1, 1 /)
	  ;;; info for data file write
	  qparaminfo = ""
end if

opts_ter = True;
opts_ter@cnLineColor = "black"
opts_ter@cnLineLabelPerimColor = "black"


