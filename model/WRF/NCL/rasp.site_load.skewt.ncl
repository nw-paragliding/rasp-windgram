;;; TO ALTER SKEW-T SOUNDING PLOT SECTION
;;; (cannot contain procedures or functions)
; $param =~ /sounding/  
; ptop decides the top of the skewt to plot
; not sure if it will do it, but this is called from skewt section of rasp.ncl
; want to change the color map and the ptop from here.
;
; original  "wkColorMap" : "WhViBlGrYeOrReWh"
; was  gsn_define_colormap(wks,"BlGrYeOrRe");
;tjtest print("sequence ------------------  rasp.site_load.skewt.ncl "+REGION+"-----------------------")
opts_vcres = True;
opts_vcres@vcMonoWindBarbColor     = False 

Ptop=450   ; set to 700 in skewt_func.ncl so which takes contol?  skewt_func.ncl, that's which takes control!

;gsn_define_colormap(wks,"WhViBlGrYeOrReWh");
gsn_define_colormap(wks,"pgwind");
  setvalues wks
 "wkColorMap" : "pgwind"
 "wkForegroundColor" : (/0.,0.,0./)    ;black
 "wkBackgroundColor" : "white" ;(/1., .96, 1./)   ;almost white
  end setvalues
newindex = NhlNewColor(wks,0.0,0.0,0.0)   ;black
newindex = NhlNewColor(wks,0.0,0.0,1.0)   ;blue 


newindex = NhlNewColor(wks,1.00,1.00,1.00)      ; white
         ;colors         (/0.20,0.56,0.80/), \  ; sky blue
	 ;colors         (/0.00,1.00,1.00/), \  ; cyan
	 ;colors         (/0.50,0.00,1.00/), \  ; blue magenta
newindex = NhlNewColor(wks,0.00,1.00,0.00)      ; green
newindex = NhlNewColor(wks,0.14,0.56,0.14)      ; forest green
	 ;colors         (/1.00,1.00,0.00/), \  ; yellow
	 ;colors         (/1.00,0.50,0.00/), \  ; orange
	 ;colors         (/1.00,0.00,1.00/), \  ; magenta
	 ;colors         (/1.00,0.00,0.00/), \  ; red
newindex = NhlNewColor(wks,0.65,0.16,0.16)      ; brown
newindex = NhlNewColor(wks,0.86,0.58,0.44)      ; tan
         ;colors         (/0.66,0.66,0.66/), \  ; light gray
	 ;colors         (/0.40,0.40,0.40/) /)  ; dark gray

;getvalues("pgwind")


;dataOpts = True

;dataOpts@colGreen            = "(/ .0, 1.0, .0 /)"  ;
;     colBrown            = "Brown"
;     colBlue             = "(/ 0.0,0.0,1.0 /)" ;
;     colRed              = "red"


;ewindex = NhlNewColor(wks,"Brown")
;ewindex = NhlNewColor(wks,"green")
;ewindex = NhlNewColor(wks,"white")
;ewindex = NhlNewColor(wks,"blue")
;ewindex = NhlNewColor(/ .82, .41, .12 /)  ; "tan" in ngwww.ucar.edu/ngdoc/ng/ref/rgb.txt (divide by 255)

; gsn_define_colormap(wks,"blgryeorre");
;  setvalues wks
;    "wkColorMap": "blgryeorre"
;    "wkForegroundColor" : (/.2,.2,1./)
;    "wkBackgroundColor" : (/1., .96, 1./)
;  end setvalues  
  

localOpts                   = True
localOpts@tiMainString      = "Sounding for "
opts_soundingloc 	    = True
opts_soundingloc@txFontHeightF = 0.016

localOpts@gsnFrame             = False
localOpts@gsnDraw  = False

opts_soundingloc@gsnFrame             = False
opts_soundingloc@gsnDraw  = False
;opts_soundingloc@txFontColor = "black"

;if( (plot_param .eq. "sounding1") .or. (plot_param .eq. "sounding2") .or. (plot_param .eq. "sounding3") .or. (plot_param .eq. "sounding4") .or. (plot_param .eq. "sounding5") .or. (plot_param .eq. "sounding6") .or. (plot_param .eq. "sounding7") .or. (plot_param .eq. "sounding8") .or. (plot_param .eq. "sounding9") .or. (plot_param .eq. "sounding10") .or. (plot_param .eq. "sounding11") .or. (plot_param .eq. "sounding12")) then
;end if
; http://www.ncl.ucar.edu/Support/talk_archives/2006/1276.html
;
;    It would appear that this could be used for profiler like plots with an increment of xpos for each one until a final draw.
;> > [2] p[*,*] ie 2D
;> >
;> >   do n=0,N-1
;> >      skewt_data = skewT_PlotData   (wks, skewt_bkgd, p(n,:),tc(n,:),tdc(n,:),z(n,:), wspd(n,:),wdir(n,:), dataOpts)
;> >      draw (skewt_data)
;> >   end do
;> >
;> >   frame(wks)
