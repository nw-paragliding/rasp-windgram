print("sequence ------------------  timestamp.ncl   "+REGION+"     "+plot_param+"     -----------------------")

operator="TJ Olney"

	lbtxtres = True
	lbtxtres@txFuncCode    = "~"
	lbtxtres@txFontHeightF = 0.015
	lbtxtres@txFontHeightF = 0.015
	lbtxtres@txJust = "CenterLeft"
	; position lower left corner of whole plot
	
	timestamp=systemfunc("date +%H:%M_%Z")
;        timestamp="~F14~~Z60Q~plotted~C~"+get_script_name()+"~C~ "+timestamp+"~C~~F14~"+operator+"~C~"
      timestamp="~F14~~Z70Q~plotted~C~ "+timestamp+"~C~~F14~"+operator+"~C~"
      timestampyNDC = 5*lbtxtres@txFontHeightF  ;was 4*
      timestampxNDC = .009      ;lower left hand corner   

;draw the timestamp  This may have to move to the end of a script if you need it to overwrite something 

gsn_text_ndc( wks, timestamp,timestampxNDC,timestampyNDC,lbtxtres )

	  rundate= systemfunc("date +%b' '%d")  ;tjo
          runyear= systemfunc("date +%Y")
	  runtime= systemfunc("date +%H:%M' '%Z")   ;tjo

if(.not.isvar("CHECK_REGION"))
CHECK_REGION=  str_sub_str(REGION,"-WINDOW","")
thisregion=str_lower(CHECK_REGION)
end if

;fcst_time=str_sub_str(
;end if
;4test 

;runtime=systemfunc("ls -l --time-style=+%l:%M%p_%Z   $BASEDIR/RASP/RUN/done_start*"+CHECK_REGION+"* |sed -e 's#^.*tj tj 0##g' -e 's#\/.*$##' |sed -e 's# #@#' -e 's#.*@#~C~#' |tail -1")
;print("-------  Using start time for "+CHECK_REGION+" as runtime "+runtime+".")
;                                                                    sed -e 's#^.*200#200#' -e 's#\/.*$##' |sed -e 's# #@#' -e 's#.*@##'")
;grep "MODEL RUN BEGINS" rasp.pnw.printout |sed -e 's/^.*at/Run at/g' -e 's#\([0-9][0-9]:[0-9][0-9]\)\(.*$\)#\1#g'
;runtime=systemfunc("grep 'MODEL RUN BEGINS' /home/jt/drjack/RASP/RUN/rasp."+thisregion+".printout |sed -e 's/^.*at/Run at/g' -e 's#\([0-9][0-9]:[0-9][0-9]\)\(.*$\)#\1#g' ")
;print ("runtime =  "+runtime)
;rundate=systemfunc("ls -la $BASEDIR/RASP/RUN/done_start."+CHECK_REGION+" |sed -e 's#^.*201#201#' -e 's# .*$##'")
;runtime=""	  
modeldata=systemfunc("ls -1tr  $BASEDIR/RASP/RUN/ETA/GRIB |tail -1 |sed -e 's#z.*#z#g' -e 's#nam.t#Using Data~C~from #g'")

url="~C~~C~URL=~C~wxtofly.net~C~"
;seealso="~C~~C~See Also~C~olneytj~C~.home~C~.comcast~C~.net/" 
leftmarginmessage = "~F4~~Z80Q~RASP~C~Model Run for~C~" + rundate + " "+runyear+"~C~~C~~C~~C~Plotted at~C~" + runtime + "~C~WRF/ARW ~C~"+displayinitmodel+" initiated~C~"+modeldata+"~C~ with ~C~"+sfcphysics+" SFC ~C~~C~~C~~F18~~F4~ ~C~Operator~C~~F10~TJ Olney~C~~C~~C~http~F17~:~F10~//~C~wxtofly.net/~C~"  ;tjo

;~F4~Pacific~C~Northwet~C~RASP~C~~C~Click~C~a region~C~or a~C~time~C~ above~C~to change~C~the ~C~forecast~C~map ~C~~C~ Click a~C~parameter~C~to~C~change to~C~the desired~C~forecast.~C~~C~Allow~C~time~C~for the~C~image~C~to load~C~~C~Not all~C~forecasts~C~are run~C~for every~C~time and~C~region

rightmarginmessage = "~F4~Pacific~C~NorthWet~C~RASP~C~~C~Forecast~C~Updated~C~Several~C~Times~C~Daily~C~~C~Fly~C~Safely~C~"+url  ;tj add signature

gsn_text_ndc( wks, leftmarginmessage ,timestampxNDC, 0.64,lbtxtres )  ;tj
	  ;was .9
gsn_text_ndc( wks, rightmarginmessage, .85, 0.66,lbtxtres )  ;tj add signature

;tjtest print("sequence ------------------ End of  timestamp.ncl "+plot_param+" "+REGION+"-----------------------")

