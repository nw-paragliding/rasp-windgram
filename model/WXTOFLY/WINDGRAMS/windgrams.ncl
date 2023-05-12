; TJ Olney's windgram local lapserate and lcl generator
; Requires ncl 5.1.1 for addfiles  requires ncl version 6.2 for fileexists() 
; Replace your domains regions sites wlats wlons and wgrids for those below
; can invoked without args and will print the default windgram to x11 display
;
;  sitedata.ncl contains info about all the sites for which to create windgrams
;  entries are of the form PNW,Whitehorse,d2,-121.677547,48.211233,
;                  PNW-WINDOW,AndersonLZ,w2,-122.264828,48.672150,
;  The sitedata.ncl file cannot contain spaces after the line ending commas
;  
; USAGE:  ncl windgramtj.ncl [SITE=\"sitename\"] [DOMAIN=[\"domainname\" \"all\"]] [ptop=nn] [rhcut = nn ] [show_[xxx]=[0|1]]
;
; rhcut is a number 1-99 for relative humidity.  Default is 95 so >95%rh gets cross hatched.
; The interactive default for this script can try to find a site outside the domain.  It looks for the default site by index number.
; Choose your favorite number to cross hatch the time/heights with high enough rh for clouds 
; if invoked with ncl SITE=\"sitename\" windgram.ncl it will do one windgram for that site
; if invoked with ncl DOMAIN=\"domainname\"  it will do all the sites in that domain
; if invoked with ncl DOMAIN=\"all\"   it will cycle through all domains and sites in your lists
; ptop is the number of levels, don't go over 3 less than the number of levels in the model, RASP usually 52-3=49
; as is, it calculates lcl three different ways and you must change it in the gsn_csm_addpolymarkers = command if you want to try another
; it has not been completely "error trapped" but it catches some.
;
;
;  New 7/4/2009 posting  no blipspots used to gather data, they are recalculated using DrJack functions.
;  cldfra_plot added to plot conditionally if there are supposed to be clouds  this is quite experimental  don't know what it will look like in practice.
;  hgldj_p  used to plot little overturned crescent moons that happen to look a bit like paragliders  (couldn't find any better wings) 
;  using drjack's lcl measure ... quite close to lcl1 from lclvl()  You can plot both simply by uncommenting the line
;  define default data source for testing purposes
;  add command line cldfra_cut   decimal for % at which to say it is cloudy enough to try to plot clouds.
;
; Coordinates space fix for windbarbs added.  2011_08_05
; Andrea Barcellona's fix to correct for the map projection and put windbarbs on a                                       
; N-S vertical E-W horizontal coordinate system when the grid is tilted from due N-S
;

BASEDIR=getenv("BASEDIR")
NCARG_ROOT=getenv("NCARG_ROOT")  
print("BASEDIR="+BASEDIR)
print("NCARG_ROOT="+NCARG_ROOT)

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

; ncl_jack_fortran.so must match the compilers used to compile ncl.  link /ncl_jack_fortran.so to the appropriate library for your system
external NCL_JACK_FORTRAN "$BASEDIR/WRF/NCL/ncl_jack_fortran.so";

;debug surrounds numerous diagnostic print statements set to anything other than 0 for verbose printing
debug = 0
if (isvar("debug")) then
	debug=1
end if 

;[REQUIRED]output directory
if (.not.isvar("outputDir")) then
	print("Error: outputDir not specified")
	status_exit(1)
end if
if (.not.fileexists(outputDir)) then
	print("Error: outputDir does not exist")
	status_exit(1)
end if
print("outputDir=" + outputDir)

;[REQUIRED]CSV file with list of sites
; Format: SITENAME(string) LON(float) LAT(float)
; Example:
;    Bridal    -121.748   49.171   
;    DeRoche   -122.112   49.204   
;    Elk       -121.76    49.12   
if (.not.isvar("siteListCsv")) then
	print("siteListCsv not specified")
	status_exit(1)
end if
print("siteListCsv=" + siteListCsv)
if (.not.fileexists(siteListCsv)) then
	print("Error: " + siteListCsv + " does not exist")
	status_exit(1)
end if
  
;read data from 
data = asciiread(siteListCsv, -1, "string")

siteNameArray = str_get_field(data, 1," ")
siteLatArray = stringtofloat(str_get_field(data, 2," "))
siteLonArray = stringtofloat(str_get_field(data, 3," "))

print("Loaded list of sites:")
print(siteNameArray)

;grid value used for all sites
if (.not.isvar("grid")) then
	print("Error: grid not specified")
	status_exit(1)
end if
if ((grid.ne."d2").and.(grid.ne."w2")) then
	print("Error: grid value not valid. Use w2 or d2")
	status_exit(1)
end if

;wrfDomain specifies which domain to load WRF output data from
if (.not.isvar("wrfDomain")) then
	print("Error: wrfDomain not specified")
	status_exit(1)
end if
if (.not.fileexists(BASEDIR + "/WRF/WRFV2/RASP/" + wrfDomain)) then
	print("Error: " + BASEDIR + "/WRF/WRFV2/RASP/" + wrfDomain + " does not exist")
	status_exit(1)
end if


operator="TJ Olney / Jiri"

;default settings
default_type = "x11"

;usually 20 I changed for TS upper instability depends on how tall your mountains are...
default_ptop = 30
default_rhcut = 95

;set to 1 if your grid is tilted from NS to cover an oblique area like England or Italy.
tilted_grid=1 ;0   

one_site = False  ; ??? why needed? see near line 369

testndx=0  ; in case a site requested out of range

;color choices  must be in the palette being used or the closest one will be used.
foreground_color= "white"
background_color= (/.5, .5, .9 /)  ;deep purple-blue
label_color= foreground_color
wstar_color= foreground_color
wstar_color= "yellow"
line_color= 13
templine_color= 14
colorpalette = ""
; normal lapse_res@cnFillColors         = (/ 11,10,7,8,3,-1,-1,13,14 /)      y

if (.not.isvar("useblipdata")) then
	; set to 1 to get data from existing blipspot files.here or from command line. Move blip subroutine after define numtimes
	useblipdata = 0 
end if
; blipdata routine broken for half hourly  data 2015 

; options to display or not on the windgram   
; the check for existing variable allows them to be passed on the command line.
;
; 
if (.not.isvar("unit_scheme")) then
	unit_scheme = 0;
end if

; 4 schemes   0 is feet for altitude m/s for w*  and knots for wind  Canadian influence
;     1 is feet for altitude fpm for w*  and knots for wind
;     2 is meters for altitude m/s for w*  and knots for wind 
;     3 is meters for altitude m/s for w*  and kph  for wind colors but knots for windbarbs  50 knots is flag colored red
;     4 is meters for altitude m/s for w* and kph for wind colors and kph for windbarbs themselves 50kph is flag
;     not yet fully implemented.  If you change units, please use this mechanism and pass the results around.
; 5 case unit_scheme   Put as many common variables as needed within each if else section then use the left hand side for plotting 

if (.not.isvar("tmp_units")) then
	;ok  change to 0 for C for Celcius 1 for Farenheight --  only affects the show_temp variable.
	tmp_units = 1			
end if

if (.not.isvar("show_condense")) then
	show_condense=1
end if

if (.not.isvar("show_cloudfrac")) then
	show_cloudfrac=0
end if

if (.not.isvar("show_converge")) then
	show_converge=0
end if

if (.not.isvar("show_wind")) then
	; windbarbs
	show_wind  = 1          
end if

if (.not.isvar("color_wind_barbs")) then
	if (show_wind.eq.1) then
		; change this if you want the wind barbs to be colored by a scalar of their speed  note units  
		color_wind_barbs=1 ;0     
	else
		color_wind_barbs=1
	end if
end if 

;default to no rain shown but check for it.
show_this_rain = 0  
if (.not.isvar("show_rain")) then
	;change default to  show rain. tjo 6/1/2011 change back until blip read works. sept 4 2015
	show_rain = 0   
	useblipdata = 1
	; show_this_rain=1
end if

if (.not.isvar("show_lapse")) then
	;local level to level lapse rate
	show_lapse = 1          
end if

if (.not.isvar("show_wing")) then
	; hg/pg 225ft/min 1.2m/s   soaring level markers
	show_wing  = 1          
end if

if (.not.isvar("show_lcl")) then
	; little clouds for lifted condensation level
	show_lcl   = 1          
end if

if (.not.isvar("show_snow")) then
	show_snow  = 1          ; lowest freezing level
end if

if (.not.isvar("show_pbl")) then
	; boundary layer top bar default to not show it.  Means nothing to most Foot launched pilots.
	show_pbl = 0		
end if

;force lapse if any of the others
if ((show_wing.ne.0).or.(show_lcl.ne.0).or.(show_snow.ne.0).or.(show_pbl.ne.0)) then
	show_lapse=1
end if

if (.not.isvar("hide_lapse_colors")) then
	; any other value will  make all colors  transparent  for lapse so it doesn't show but still provides scaffold for other stuff.
	hide_lapse_colors=0     
end if

if (.not.isvar("show_rh")) then
	; relative humidity greater than rh_cut -- cheap trick for clouds in the bl I use 95%
	show_rh = 1
end if

if (.not.isvar("show_temp")) then
	; temperature contours
	show_temp = 1
end if

if (.not.isvar("show_up_vel")) then
	; show vertical velocity W* at top of time column  set to 0 if no access to drJack Fortran modules.
	show_up_vel = 1
end if

if (.not.isvar("show_z_contour")) then
	; draw a contour line for the altitude  attaching presure level in the morning to corresponding altitude in evening
	show_z_contour = 1      
	; extra spacing between altitude contour lines
	z_stride=4              
end if

if (.not.isvar("show_p_contour") .and. (show_z_contour.ne.0)) then
	; draw a contour line for the presure level in the morning to corresponding altitude in evening
	show_p_contour = 1       
	; extra spacing between altitude contour lines
	p_stride=z_stride              
else
	show_p_contour = 0
end if

;; don't complain about fallbacks when parameters are out of range.
err = NhlGetErrorObjectId()
setvalues err
    "errLevel" : "Fatal"          ; only report Fatal errors
end setvalues

if (.not.isvar("type")) then
	type = default_type
end if

if (.not.isvar("ptop")) then
	ptop=default_ptop
end if

if (.not.isvar("rhcut")) then
	rhcut=default_rhcut
end if

;--------------------------------------------------------------------------------------------------------------

;generate house keeping data
offsetstring = systemfunc("date +%z")
offset = stringtoint(offsetstring)/100

pstpdt = systemfunc("date +%Z")
mm_dd = systemfunc("date -u +%b-%d")
yyyy_mm_dd = systemfunc("date -u +%Y-%m-%d")

xaxis_msg = ""
;--------------------------------------------------------------------------------------------------------------

one_site= False

;;------------------------------------end parameter parsing and setup section     

;--------------------  data ingest from wrfout files  and digest  -------------------------;
;; where to find the wrfout files to use as raw data.
filecommand1 = "ls $BASEDIR/WRF/WRFV2/RASP/" + wrfDomain + "/wrfout_d02_*"

print("Plotting parameters:") 
print("   tilted_grid = " + tilted_grid)
print("   ptop = " + ptop)
print("   Output plot type = " + type)
print("    show_lapse = " + show_lapse)
print("    show_wind  = " + show_wind)
print("    color_wind_barbs = " + color_wind_barbs)
print("    show_rh    = " + show_rh)
print("    relative humidity cutoff, rhcut = " + rhcut)
print("    show_temp = " + show_temp)
print("    debug = " + debug)
print("    useblipdata = " + useblipdata)
print("    unit_scheme = " + unit_scheme)
print("    tmp_units = " + tmp_units)
print("    show_condense = " + show_condense)
print("    show_rain = " + show_rain)
print("    show_wing = " + show_wing)
print("    show_lcl = " + show_lcl)
print("    show_snow = " + show_snow)
print("    show_pbl = " + show_pbl)
print("    show_cloudfrac = " + show_cloudfrac)
print("    hide_lapse_colors = " + hide_lapse_colors)
print("    show_up_vel = " + show_up_vel)
print("    show_z_contour = " + show_z_contour)
print("    show_p_contour = " + show_p_contour)

print(" wrf data files are found as " + BASEDIR + "/WRF/WRFV2/RASP/" + wrfDomain + "/wrfout_d02_*")
print(" offset: " + offset + " " + pstpdt )

fs = systemfunc( filecommand1 )      ;fs becomes an array of full filenames --  needs deleting between domains
onefile=fs(0)                        ; get a single file from which to get geographic data and time labels etc

print("Processing these data files: ")  
print(" " + fs) 
print("Fixed parameters, ter,z  etc.  being looked up in the file  onefile=")
print("        " + onefile)

a = addfiles(fs + ".nc", "r")          ;addfiles grabs all the files in the list above at once.
timesinfiles = a[:]->Times
b = addfile(onefile + ".nc", "r")

p=a[:]->P 
pb=a[:]->PB
press=p             ;bring along metadata
press = p + pb      ;reassign 
pmb=press/100
 
pdims=dimsizes(press)
numlevels=pdims(1)
;printVarSummary(numlevels)
numtimes=pdims(0)
numy=pdims(2)
numx=pdims(3)
taus=ispan(0,numtimes-1,1)   ;coordinate variable for Time dimension  
ilevels=ispan( 0,numlevels-1,1)

tkall=a[:]->T         ;perturbation temp
tkall = tkall + 300   ;as per wrfuser
tk = wrf_tk( press , tkall )  ;temperature Kelvin
tc=tk
tc = tk - 273.16
tc@units = "C" 
 
ter=a[:]->HGT                 ;meters above sea level 
pblh=a[:]->PBLH                 ;meters  pbl thickness 
; printVarSummary(pblh)
pblt= ter + pblh		;height of top of pbl meters
tmpu =a[:]->U                 ;
tmpv =a[:]->V
u = wrf_user_unstagger(tmpu,tmpu@stagger) 
v = wrf_user_unstagger(tmpv,tmpv@stagger)

;; adding mechanical vertical to available plot variables
tmpw =a[:]->W                 ;wind vertical component, not thermal;
w = wrf_user_unstagger(tmpw,tmpw@stagger)  ; how to display this???  average between surface and hcrit? or hglider? 
;; for one time only  w = wrf_user_getvar(a,"wa",time) ; vertical velocity, averaged to half levels in m/s 
w4plot = 100*w  ;use Jack's convention and convert to cm 
;; 

QVAPOR = a[:]->QVAPOR         ;
td=wrf_td(press,QVAPOR)       ; get the dewpoint  everywhere   use for all sites
rh = wrf_rh(QVAPOR, press, tk); get the relative humidity everywhere   use for all sites

PH  = a[:]->PH
PHB = a[:]->PHB
PH =  PH + PHB

;cldfra = a[:]->CLDFRA

PSFC = a[:]->PSFC   ; don't use for RASP time 0 is always = 0 
z = wrf_user_unstagger(PH,PH@stagger)/9.81           ; On full (w) levels
dimv = dimsizes(z)
;z = 0.5*(zmeter(:,0:dimv(0)-2,:,:)+zmeter(:,1:dimv(0)-1,:,:))    ; On half (mass) levels meters
;printVarSummary(z)
zmeter = z  ;used below in meters
z=z*3.2808   ;geopotential height from wrfoutput in feet.
z@units = "ft"
z!0 = "Time"
z!1 = "levels"
z!2 = "south_north"
z!3 = "west_east" 
z&Time = taus

zft=z
zmeter@units = "meters"
zmeter!0 = "Time"
zmeter!1 = "levels"
zmeter!2 = "south_north"
zmeter!3 = "west_east" 
zmeter&Time = taus


mslp = wrf_slp( zmeter, tk, press, QVAPOR ) 

;-------------------- To use blipspot output for params set useblipdata above --------------------------------------;
;
;-- method to retrieve rasp parameters from blipspots  ; used only for rain1 
if (useblipdata.ne.0) then
	;this gets rid of errors, but need to somehow pad the d2 from 5am to 8am 
	if (numtimes .gt. 16 ) then   
		bliptimes=(numtimes/2)+1
		bliptaus=taus(::2)
	else
		bliptimes=numtimes
		bliptaus=taus
	end if
	
	blipdir = BASEDIR + "/RASP/UTIL/blipspots/"
	;--------------------------- function for pulling raw data from a blipmap.html file. ---------------
	undef("getblip_param")
	function  getblip_param(bparam:string, bliptimes:integer, site:string, grp_key:string,numtimes:integer)
		local  outfile, outvar, cmd0, blipfile, iparam ,paramnumberof,cmiss
		;  LCL  getblip_param(lclj bliptimes Blanchard CUbase_LCL)
		begin
			blipfile=blipdir+"blipspot"+site+".html"
			cmd0 = "grep -i "+grp_key+" "+blipfile+" |sed   -e 's#<[\/t]*[rd]>#, #g' -e 's/"+grp_key+"//g' -e 's/-/0/g' -e 's/, ,//g' -e 's/^[ ]*,//g'  -e 's#<[^>]*>##g' -e 's#[a-z_A-Z]*##g' -e 's# , *##g' -e 's/^,//g'"
			;cmd0 ="grep -i "+grp_key+" "+blipfile+" |sed -e 's#<t[^>]*.>##g' -e 's#<[\/t]*[rd]>#, #g' -e 's/"+grp_key+"//g' -e 's/-/0/g' -e 's/, ,//g' -e 's/^[ ]*,//g' " ; -e 's/\([0-9]\),/\1.,/g' " ;

			print(">>>>>>>>>>> cmd0 "+cmd0)

			outfile = new(1,string)
			outfile="tempfile."+bparam
			;print("outfile= "+outfile)
			outvar = new(1,string)
			blipdata=new(1,string)
			iparam=new(numtimes,integer)
			blipdata=systemfunc(cmd0)
			outvar = "(/" + blipdata + " /)"
			paramnumberof=str_fields_count(outvar, ",")-1
			print("available blip hours ="+paramnumberof)
			print("bparam = "+bparam+"   blipdata = "+blipdata+"   outfile = "+outfile )
			asciiwrite(outfile, outvar)              ;write it to ascii file   
			;   iparam=asciiread(outfile, (/  bliptimes /), "float")    ;read it back as integer array
			;   blips=asciiread(outfile, (/  paramnumberof /), "float")    ;read it back as integer array
			;   blips=asciiread(outfile, (/  paramnumberof /), "integer")    ;read it back as integer array
			blips=asciiread(outfile, (/  bliptimes /), "integer")    ;read it back as integer array
			;  (/, 0, 0, 0, 0, 0, 0, 0, 3, 14, 0, 0, 0, 0,   /)

			cmiss=0
			print("bliptimes = "+bliptimes)

			do i=1,bliptimes-1 

				if (ismissing(blips((bliptimes-i)-1))) then
					cmiss=cmiss+1
					print("cmiss ="+cmiss)
					;	iparam(i)= blips((bliptimes-i)-1)   ;scale reversal trick and index to zero missing values will be at the end of input
					iparam(i)= blips((bliptimes-i)-1)   ;scale reversal trick and index to zero missing values will be at the end of input
				else
					iparam(i)=  blips(i-cmiss)   ;hard code should be a way to subtract number of missing 
				end if
				
				print("i="+i+"   bliptimes-i="+bliptimes+"  numtimes ="+numtimes+"   iparam(i)= "+iparam(i) )
				
			end do

			print(iparam)

			return(iparam)
		end
	;---------------------------------------------------------------------------------------------------------------------------;
	;---------------------------end  function for pulling raw data from a blipmap.html file. ---------------

;to use
;newstar=getblip_param("wstar",13,"Blanchard","Up_Velocity")  ;newstar is now a 1D 13 element array of float
;hgldj=getblip_param("hgldj",bliptimes,wsites(ns),"MaxSoar_AGL")
;hglider=getblip_param("hglider",13,"Blanchard","MaxSoar_clds")
;etc  Note Dan G's empirical formula ubtracting 1,000 from the cloud base in feet and then dividing by 1,000 =up knots
;http://www.drjack.info/cgi-bin/WEBBBS/rasp-forum_config.pl/noframes/read/5083    
;then 100*knots is approx fpm  so CB-1000/10 --> fpm   ( note: 101.27*knots=fpm)
;so (((T-DP)*400)-1000)/10 ~~ fpm   as used on the hrrr soundings and ruc soundings
end if
;---------------------------------------------------------------------------------------------------------------------------;
; end blipdata section
;---------------------------------------------------------------------------------------------------------------------------;


;
;---------------------------------------------------------------------------------------------------------------------------;
;--------------------        to calculate wstar Thermal Up velocity  -------------------------------------------------------;
;---------------------------------------------------------------------------------------------------------------------------;
 ;etc  Note Dan G's empirical formula subtracting 1,000 from the cloud base in feet and then dividing by 1,000 =up knots
 ;http://www.drjack.info/cgi-bin/WEBBBS/rasp-forum_config.pl/noframes/read/5083 
;
;
if ( .not. isvar("vhf") ) then
	if ( .not. isvar("hfx") ) then
		hfx = a[:]->HFX   ;,time) ; for sfc. sensible heat flux in w/m2
    end if
	
    ; convert latent heat flux into additional virtual temperature heat flux
    ; 0.61*cp/L=0.61*(1006J/Kkg)/(2.502x106J/kg)=0.000245268
    vhf = a[:]->LH 
	
	;NCL_JACK_FORTRAN :: minlimit2d( vhf, 0.0, isize,jsize )
	;printVarSummary(hfx)
	;printVarSummary(vhf)
	;drjacks routines calculate for only one time period  so vhf is only 2d, not 3d 
	; must calculate for each period
	;--------------------------------------------- hcrit wstar sfclcl directly 

	do i=0,numtimes-1
		  NCL_JACK_FORTRAN::minlimit2d( vhf(i,:,:), 0.0, numx,numy )
		  vhf(i,:,:) = hfx(	i,:,:) +  0.000245268*(tc(i,0,:,:)+273.16)*vhf(i,:,:)
	end do;      
end if          ;That should fully populate vhf    
    
;s_n   w_e
;wstar = new( (/jsize,isize/), float)
wstar = new( (/numtimes,numy,numx/), float)      ;has a time dimension
wstar_1 =new( (/numy,numx/), float)              ; no time dimension, returned by NCL_JACK_FORTRAN 
hcrit = new( (/numtimes,numy,numx/), float)      ;has a time dimension
hcrit_1 =new( (/numy,numx/), float)              ; no time dimension, returned by NCL_JACK_FORTRAN
sfclclheight = new( (/numtimes,numy, numx/), float)
sfclclheight_1 = new( (/numy, numx/), float)
hglider_1 = new( (/numy, numx/), float)
hglider = new( (/numtimes,numy, numx/), float)
effwing_1 = new( (/numy, numx/), float)
effwing = new( (/numtimes,numy, numx/), float)
	

; NCL_JACK_FORTRAN :: calc_wstar( vhf,pblh, isize,jsize,ksize, wstar )
; use DrJack's 2d functions for other parameters of interest -- loop over numtimes
do i=0,numtimes-1
	if (show_up_vel.ne.0.or.show_wing.ne.0) then
		NCL_JACK_FORTRAN :: calc_wstar( vhf(i,:,:),pblh(i,:,:), numx,numy,numlevels, wstar_1 )
	;   NCL_JACK_FORTRAN :: calc_wstar( vhf(i,locY,locX),pblh(i,locY,locX), 1, 1, numlevels, wstar_1 )    ;if done for one site.
		wstar(i,:,:)=wstar_1   ;put result for this iteration into the i time slot for all wstar
	end if
	; try calculating this, the experimental max soaring height at 175/m sink
	; it works but display is ugly
	; NCL_JACK_FORTRAN :: calc_hlift( 175., wstar_1, ter(i,:,:), pblh(i,:,:), numx,numy, effwing_1  )
	; effwing(i,:,:)=effwing_1*3.28084

	if (show_wing.ne.0) then
		NCL_JACK_FORTRAN :: calc_hcrit( wstar_1, ter(i,:,:), pblh(i,:,:), numx,numy, hcrit_1 )
		hcrit(i,:,:)=hcrit_1*3.28084             ;to feet ;put result for this iteration into the i time slot
	end if

	if (show_lcl.ne.0 .or. show_wing.ne.0) then                 ; need it to calculate hcrit of wing even if lcl not shown
		NCL_JACK_FORTRAN :: calc_sfclclheight( press(i,:,:,:), tc(i,:,:,:), td(i,:,:,:), zmeter(i,:,:,:), ter(i,:,:), pblh(i,:,:), numx,numy,numlevels, sfclclheight_1 )
		sfclclheight(i,:,:)=   sfclclheight_1  ;put result for this iteration into the i time slot
	end if
end do;    

;meters to feet
sfclclheight=sfclclheight*3.28084          

;---------------------------------------------------------------------------------------------------------------------------;
;--------------------------               Wstar calculated for whole region         ----------------------------------------;
;---------------------------------------------------------------------------------------------------------------------------;


llres = True
; Return integer values
llres@ReturnInt = True   
llres@MAP_PROJ  =b@MAP_PROJ
llres@TRUELAT1  =b@TRUELAT1
llres@TRUELAT2  =b@TRUELAT2
llres@STAND_LON =b@STAND_LON
llres@DX        = b@DX
llres@DY        = b@DY
XLAT  = b->XLAT(0,:,:)
XLONG = b->XLONG(0,:,:)

dims = dimsizes(timesinfiles)       
;string representation of the times in the files 
times = new(dims(0),string)       
caption = new(dims(0),integer)

;put local time into this for labels
lst = new(dims(0),integer)        
  
do i=0,dims(0)-1

    times(i) = chartostring(timesinfiles(i,8:15))
    tmp = chartostring(timesinfiles(i,11:12))
    caption(i) = stringtoint(tmp)   ;+"."+chartostring(t(2,10:12))
    lst(i) =  caption(i)+offset     ;convert UTC to local standard time 

	; make times 12 hour local clock
	;negative numbers add 24
    if ( lst(i).lt.1 )
       lst(i)= lst(i)+24
    end if   
    
    if ( lst(i).gt.12 )
		;change to non-military time.
		lst(i) = lst(i)-12                 
    end if  

end do;

day = chartostring(timesinfiles(1,0:9))

print ("For day " + day + " for " + wrfDomain + " numtimes is number of times available = "+numtimes)

;pressheights =new(pdims(1),float)
feet=new(pdims(1),float)

;;----------------------------  End of whole domain  definitions 

;-----------------------------------------------------------------------------------------------;
;-----------------------------------------------------------------------------------------------;
;----------------       Actual start of do loop for sites in one region           ---------------
;-------------------------------  ns tracks which site  ----------------------------------------;
;-----------------------------------------------------------------------------------------------;

loopstart = 0
loopend = dimsizes(siteNameArray)

; for one loxY locX at a time.
do ns = loopstart, (loopend - 1)

	windgram = outputDir + "/" + day + "_" + siteNameArray(ns) + "_windgram"

	;====================== Set up the Workstation  for this site.            ================
	; must be destroyed at end of loop  must be within the loop  color array can be outside though.
	; wks = gsn_open_wks(type , windgram)    ; open a workstation as type  with constructed name

	type@wkWidth = 800
	type@wkHeight = 800

	wks = gsn_open_wks(type, windgram)

	; create an array to be the colors each triplet is a color and the index of the triplet is the reference to that color 
	; multiply the array by 1.0 to turn it into float values 
	; then divide by 255 to put them in the required 0-1 range.
	;; note these colors were chosen for 1) ability to tell color changes 2)symbolism of the colors red=hot and danger
	;; orange not so much
	;; pink and purple are perfect
	;; light colors are light lift
	;; matching the background is stable
	;; greys are inversion   dark times for soaring pilots.
	if (colorpalette.eq."") then
		updcolors=(/ (/255,255,255/),\
		(/128,128,230/),\
		(/255,255,255/),\
		(/250,240,230/),\
		(/200,255,200/),\
		(/120,255,120/),\
		(/21,255,21/),\
		(/255,187,255/),\
		(/204,191,255/),\
		(/255,204,0/),\
		(/255,153,0/),\
		(/255,61,61/),\
		(/230,230,230/),\
		(/204,204,204/),\
		(/153,153,153/),\
		(/0,0,0/),\
		(/255,  56,  255/),\     
		(/255,  150, 255/),\      
		(/255,  196, 255/),\      
		(/255,  216, 255/),\      
		(/255,  236, 255/),\      
		(/255,  248, 255/),\      
		(/255,  248, 255/),\      
		(/255,  248, 255/),\
		(/255,  255, 0/)/) * 1.0      
		; last index is 24 is yellow for contrasting fonts

		updcolors=updcolors/255 ; but they must be in 0-1 range
	else
		updcolors=colorpalette
	end if

	gsn_define_colormap(wks, updcolors)   ; generate new color map
	setvalues wks
		"wkForegroundColor" : foreground_color              ; set at top  
		"wkBackgroundColor" : background_color              ; set at top
	end setvalues 


	;; =============================================================================================
	;; ----------------------- Start with definitions for each site in the domain

	locij = wrf_user_ll_to_ij(b, siteLonArray(ns), siteLatArray(ns), llres)
	locij = locij - 1        ; array pointers in NCL space one less than wrf space.

	locX = locij(0)
	locY = locij(1)

	maxp = max(press(:,:,locY,locX))/100 
	minp = min(press(:,:ptop-1,locY,locX))/100
	startp = round(press(0,0,locY,locX)+.5,0)/100

	;array contains actual levels taken from wrfout file == rounded
	plevels = round((press(0,:,locY,locX)/100)+.5,0)            
	; theselevels contain only the levels up to ptop 
	theselevels=plevels(0:ptop-1)               
	; don't have plevels until locY locX  use as coordinate variable for z
	z&levels = plevels                          

	;4test printVarSummary(z)

	;create an array for only the levels to be plotted.
	zhere=round(zft(:,:ptop-1,locY,locX)+.5,0)   
	;label dimensions
	zhere!0="Time"
	zhere!1="plevels"
	; set coordinate variables for each named dimension
	zhere&Time = taus
	zhere&plevels = theselevels

	zhere_m=round(zmeter(:,:ptop-1,locY,locX)+.5,0)   ;metric height same process as above
	zhere_m!0="Time"
	zhere_m!1="plevels"
	zhere_m&Time = taus 
	zhere_m&plevels = theselevels

	zfeets=zhere+"'"                             ;zfeets used for labels is a string by adding the '
	zmeters=zhere_m+"m"                          ;zmeters+"m"  ;string for labels
	meters=zmeters(0,:)                          ;get one dimensional array with these labels 
	feets=zfeets(0,:)			     ; 
	feets!0="plevels"			     ;name the dimension
	feets&plevels = theselevels                  ;add coordinate variable

	h=ter(0,locY,locX)      	;terrain model height in meters
	hft=h*3.2808             	;terrain model height in feet

	; this goes to stdout therefore part of rasp.regionxyz.printout  change elevation units if desired.
	print(" ")
	print ("Windgram for " + siteNameArray(ns) + " site:ns=" + ns + " from the " + wrfDomain + " " + grid + " grid at point " + locY + " " + locX + " " + siteLonArray(ns) + " " + siteLatArray(ns) + " model elevation:" + round(hft,0) + "ft ASL" )
	print("Pressure surface p "+round(maxp+.5,0)+"mb or "+round(hft,0)+"' = "+round(h+.5,0)+"m up to ptop min  p value   "+minp)
	
	; print the z and pressure levels at which blip winds are being reported.
	do i=0,3
		print("press level " + i + " ---> " + theselevels(i) + "mb or " + zfeets(8,i) + "  =" + zmeters(8,i) + " at time 8  " + lst(8) + ":00 lst")
	end do

	; extract measures for this site location from larger arrays.  local variables start with l
	tkloc=tk(:,:,locY,locX)       	;fill the temperature array at locY locX  tkloc  ...was tkall
	lp=press(:,:,locY,locX)       	;local point press over time
	lqv=QVAPOR(:,:,locY,locX)      ; 
	ltd = td(:,:,locY,locX)        ; pull out dewpoints at this location
	ltd = ltd +273.3           	; lclvl wants Kelvin dewpoint, so convert
	lmslp =  mslp(:,locY,locX)
	; l_cldfra = cldfra(:,:ptop-1,locY,locX)         ;cloud fraction for this location
	; l_cldfra!1 = "levels"
	; l_cldfra&levels = theselevels

	;======== CLOUD FRACTION
	if (show_cloudfrac.ne.0) then
		cldfra = a[:]->CLDFRA
		; now just at the focal point
		cldfrapoint = cldfra(:,:,locY,locX)
		; and grid it so it is only up to ptop with Time as rightmost dimension   for plotting 
		cldfragrid = cldfrapoint(bottom_top|:ptop,Time|:)  
		cldfragrid@description ="Cloud Fraction"
	end if

	if (show_pbl.ne.0) then
		lpblt=pblt(:,locY,locX)        ;point top of boundary layer in meters over time 1 dimension 
		lpblt!0 = "time"; 
		lpblt&time = taus
		lpblt_p = lmslp-((lpblt*3.2808)/32)		     ;approx mb top of boundary layer could get from zherelevel of 
		lpblt_p!0 = "time"; 
		lpblt_p&time = taus
	end if

	if (show_up_vel.ne.0) then
		lwstar = floattointeger(round(wstar(:, locY, locX)*196.85, 0))       ;same rounding as drjack m/s to f/m
		; mwstar = round((wstar(:, locY, locX)+.5)*10, 0)/10                  ;wstar in meters rounded to 1 decimal place choose which to display
		mwstar = decimalPlaces((wstar(:, locY, locX)),  1,  True)            ;shea utils has this function decimalplaces(x, places, true for round false for truncate)
		;  mwstar = round(.499+(wstar(:, locY, locX)*10), 0)/10        ;same result as shea utils       ;.5 rounds up so round(.5 +(0*10)  =  .5  5/10  = .5 not 0
																	; but round(0*10+.499)  =  0 _
		;unitscheme                                     ;by uncomenting only one of the two next lines  string wstar for labels
		swstartxt = mwstar+"m/s"              ;choose your units for top of columns.
		; swstartxt = lwstar+"fpm"
		;swstartxt = swstartxt+"~C~"+lwstar+"fpm"      ;works but runs title off top of page requires much readjustment.
	end if

	lsfclclheight = sfclclheight(:, locY, locX)

	if (show_wing.ne.0) then
		lhcrit = hcrit(:, locY, locX)
		lhglider = lhcrit                    ; transfer metadata alter below 
		do i = 0, numtimes-1
			if (lhcrit(i).le.lsfclclheight(i))
				lhglider(i) = lhcrit(i)
			else
				lhglider(i) = lsfclclheight(i)
			end if
		end do;
	end if

	if (show_lcl.ne.0) then
		lclj_p =  lmslp-(lsfclclheight/32)    ;approx mb from ft   remaining approximations...
		;bltj_p =  lmslp-(lpblt/32)            ;approx mb from ft   because plot is done on pressure level coordinates
		hgldj_p = lmslp-(lhglider/32)         ;approx mb from ft   These are always approximations anyway, so being off a few feet is irrelevant
	end if

	;find lowest freezing level  .lt. ptop
	if (show_snow.ne.0) then
		freezelevel=new(numtimes,float)
		do j=0,numtimes-1 
			do i=0,ptop-1
				if (tkloc(j,i).lt.273.15)                ; find the level where temp falls below freezing
					freezelevel(j)=theselevels(i)            ; assign it to the scalar freezelevel for this time 
					break                                    ; once found do it for the next time 
				end if
			end do;
		end do;
	end if

	if (show_condense.ne.0) then
		condense=new((/numtimes, numlevels/) ,float)  			; try a condensation level by dewpoint=temp  (DrJack says 2C difference)
		do j=0,numtimes-1 
			do i=0,ptop-1
				if (tkloc(j,i).le.(ltd(j,i)+.01))       ; find any levels where temp "really close" to dewpoint call for condensation.
					condense(j,i)=1                     ; assign it to condense as 1 or 0 this time and altitude
				else
					condense(j,i)=0    ;condense is a grid treat the same as rh.
				end if
			end do;
		end do;
	end if
		     
	;;---------------------------------------------------------------------------------------------------------------;
	;;---------------------------------------------------------------------------------------------------------------;
	;;---------------------------------   Calculate the lcl for clouds markers    -----------------------------------;
	;;---------------------------------------------------------------------------------------------------------------;
	;;---------------------------------------------------------------------------------------------------------------;
	if (show_lcl.ne.0)
		lcl1=new(numtimes,float)        ;generate a variable with the dimensions of time and pressure 

		lcl1=lclvl(lp(:,0),tkloc(:,0) ,ltd(:,0))   ;calculates   sfc LCL 
		lcl1=lcl1/100    
		lcl1=round(lcl1+.5,0)

		lp=lp/100
		lcl1@description="lifted condensation level"
		lcl1@units= "hPa"

		lcl4=(tkloc(:,0)-ltd(:,0))*400         ; alternate rule of thumb lcl
		lcl4=theselevels(0) - (lcl4/32)        ; back into pressure sort of..
		;4test  even more diagnostics than debug
		;  printVarSummary(lcl1)
		;  printVarSummary(lcl4)
		;  cl_pdiff=lp(:,0)-lcl1      ; surface pressure - pressureheight of lcl
		;  cl_fdiff=cl_pdiff*32           ; use 32'/mb approximation
		;  cloudbase=cl_fdiff+hft             ; lcl in feet AGL + GL   should actually plot lcl, not cloudbase ..
		;;---------------------------------------------------------------------------------------------------------------;
		;;---------------------------------------------------------------------------------------------------------------;
	end if

	;;---------------------------------------------------------------------------------------------------------------;
	;;---------------------------------------------------------------------------------------------------------------;
	; -------------            calculate "local" lapse rates                              ---------------------------;
	;;---------------------------------------------------------------------------------------------------------------;
	;;---------------------------------------------------------------------------------------------------------------;
	if (isvar("lapseptop"))   ;when looping through sites this is needed to keep from generating coordinate variable errors 
		delete(lapseptop)
	end if

	if (isvar("ftdiffs"))
		delete(ftdiffs)
	end if

	lapseptop=press(:,:ptop-1,locY,locX)  ; create and bring along metadata from pressure
	lapseptop!0 = "Time"
	lapseptop!1 = "levels"
	lapseptop&levels = theselevels
	lapseptop&Time = taus

	;printVarSummary(lapseptop)

	ftdiffs=z(:,1:ptop,locY,locX)-z(:,0:ptop-1,locY,locX)         ;diffs are from z level 1 up  and an ofset of z level 0 up
                                     		;height differences is feet because z was feet could be meters if z was meters
	; note: the choice to present lapse as C/1000 ft is an arbitrary one based on the "inherited" pilot practices in the region where I live tjo

	ftdiffs=ftdiffs/1000             		; convert it to thousands of feet
	t_0=tkloc(:,0:ptop-1)              		; now create two temperature matricies
	t_1=tkloc(:,1:ptop)            			; t_1 is offset up one level
	tdiffs=t_1-t_0       				; and get the difference between them as deltaT  units are K but same size as C
	;printVarSummary(tdiffs)

	lapseptop= tdiffs/ftdiffs       		 ;this is now a matrix of time x height up to ptop of local lapse rates.
	lapseptop@units = "C/1000ft"
	lapseptop@description= "Local lapse rate"
	;printVarSummary(lapseptop)

	lgrid     = lapseptop({levels|:},Time|:)          ;reverse x and y axis on this too. it is already constrained to ptop-1
	lgrid@description=""                              ;make it blank or a default it gets printed on the output
	lgrid@units=""  

	;;-----------------------------          end of lapse calculations  ---------------------------------------------;
	;;---------------------------------------------------------------------------------------------------------------;

	;;---------------------------------------------------------------------------------------------------------------;
	;--------------------------start windgram  ----------------------------------------------------------------------

	u_point   = u(:,:,locY,locX)
	v_point   = v(:,:,locY,locX)

	u_point_tmp=u_point  ;create new variable with appropriate coordinates 

	if (tilted_grid.eq.1) then
		; Andrea Barcelona's fix to correct for the map projection and put windbarbs on a 
		; N-S vertical E-W horizontal coordinate system when the grid is tilted from due N-S
		;where cosalpha and sinalpha are obtained from the wrfout file (b) , they are the same for all times 
		cosalpha = b->COSALPHA(0,:,:)
		sinalpha = b->SINALPHA(0,:,:)
		u_point_tmp   = u_point*cosalpha(locY,locX) - v_point*sinalpha(locY,locX)  
		v_point   = u_point*sinalpha(locY,locX) + v_point*cosalpha(locY,locX)  ;must use original u_point here.
		;printVarSummary(u_point_tmp)
		;printVarSummary(v_point)
		u_point = u_point_tmp
	end if

	ugrid = u_point(bottom_top|:ptop-1,Time|:)*1.94386            ;reverse the dimensions so Time is on Xaxis
	vgrid = v_point(bottom_top|:ptop-1,Time|:)*1.94386	    ; 1.94386 = mps2kts

	;printVarSummary(ugrid)
	;printVarSummary(vgrid)

	; now give all the labels and things the same coordinate variable       plevels

	plevels!0 = "levels"
	plevels&levels = plevels               ;it is its own coordinate variable hmmm.

	stplevels = flt2string(plevels)+"mb"     ; string plevels for pressure level labels
	stplevels!0 = "levels"
	stplevels&levels  =  plevels

	; the approximation  method for getting feet for the right y axis.
	;feet = round(.5+hft+((maxp-plevels)*33),0)  ; approximate elevation  cf using z or 
	;feet = round(z(numtimes-1,:,locY,locX)+.5,0)
	;feet(0)=round(hft,0)           ;base elevation number  don't use, let bottom feet be from levels not terrain. It doesn' have surface winds anyway.
	;;  feet(i)= hft + ( 121*(tk(0,0,locY,locX)+tk(0,i,locY,locX))/2   *         log10(pressheights(0))/pressheights(i) ) ; *3.2808
	;feets = feet+"'"                        ; for elevation labels string adding the ' makes it a string automagically
	;feet!0="plevels"
	;feets!0="levels"
	;feet&plevels  =  theselevels   ;plevels
	;feets&levels  =  plevels


	; these were created reversed so time in in 2nd position.
	vgrid!0 = "levels"
	vgrid!1 = "Time"
	vgrid&Time = taus
	vgrid&levels = theselevels

	ugrid!0 = "levels"
	ugrid!1 = "Time"
	ugrid&levels = theselevels
	ugrid&Time = taus

	lgrid!0 = "levels"
	lgrid!1 = "Time"
	lgrid&Time = taus
	lgrid&levels = theselevels


	; not yet implemented...should include conversion factors from the "default" output units 
	; and perhaps be a procedure or function 
	; 4 schemes   0 is feet for altitude m/s for w*  and knots for wind  Canadian influence
	;     1 is feet for altitude fpm for w*  and knots for wind
	;     2 is meters for altitude m/s for w*  and knots for wind 
	;     3 is meters for altitude m/s for w*  and kph  for wind colors but knots for windbarbs  50 knots is flag colored red
	;     4 is meters for altitude m/s for w* and kph for wind colors and kph for windbarbs themselves 50kph is flag
	;     not yet fully implemented.  If you change units, please use this mechanism and pass the results around.
	;
	;  native output from DrJack and wrf is ???
	;
	; 5 case unit_scheme   Put as many common variables as needed within each if else section 
	; then use the left hand side for plotting 
	umeters="meters"
	ufeet="feet"
	uvel="knots"
	ubarbs="knots"
	
	if (unit_scheme .eq. 0) then
		upvel=umeters;
		alt=ufeet
		uvel="knots"
	else
		if (unit_scheme .eq. 1) then   ;     1 is feet for altitude fpm for w*  and knots for wind  
			upvel=ufeet
			alt=ufeet
			uvel="knots"
		else
			if (unit_scheme .eq. 2) then  ;     2 is meters for altitude m/s for w*  and knots for wind 
				upvel=umeters 
				alt=umeters
				uvel="kph"
				ubarbs="knots"
			else
				if (unit_scheme .eq. 3) then  ;     3 is meters for altitude m/s for w*  and kph  for wind colors but knots for windbarbs  
					upvel=ufeet 
					alt=umeters
					uvel="kph"
				else
					if (unit_scheme .eq. 4) then  ;4 is meters for altitude m/s for w* and kph for wind colors and kph for windbarbs themselves 50kph is flag
						upvel=umeters 
						alt=umeters
						uvel="kph"
						ubarbs="kph"
					end if
				end if
			end if
		end if
	end if
	; print("alt= "+alt+"  upvel= "+upvel )

	; resources for all 2D plots x--> time  y -->height
	xaxis_msg= "      Local Lapse Rate in Degrees C per 1000ft  "   ;default xaxis message becomes part of tiXAxisString
	;;; SET BASIC TEXT RESOURCES
	lbtxtres = True
	lbtxtres@txtFontQuality = "High"
	lbtxtres@tiXAxisFont = 21 ;helvetica
	lbtxtres@txFuncCode    = "~"
	lbtxtres@txFontHeightF = 0.015
	lbtxtres@txFontHeightF = 0.015
	lbtxtres@txJust = "CenterLeft"

	res2D = True       ; res2D set basic resources for most other plots  
	; res2D@xyYIrregularPoints = plevels                 ; not using xy plots not needed
	; res2D@trYAxisType = "IrregularAxis"   
	res2D@txtFontQuality="High"
	res2D@tiMainFont = 21
	res2D@tiXAxisFont = 21 ;helvetica
	res2D@tiYAxisFont = 21 ;helvetica
	res2D@lbTitleFont = 4
	res2D@lbAutoManage         = False      ;test tjo see discussion on ncl-talk
	res2D@lbRightMarginF = 0.0
	res2D@lbJustification = "topleft"
	res2D@lbLeftMarginF = 0.0
	res2D@lbTopMarginF = 0.0 
	res2D@lbTitlePosition =  "Bottom"
	res2D@lbLabelPosition = "Top"
	res2D@lbLabelOffsetF = .01
	; res2D@lbFontHeightF = .016  ;default is .02
	res2D@lbLabelFontColor = label_color  ;default is foreground (white here)
	res2D@lbBoxMinorExtentF = .23   ;.33 is default
	; res2D@lbTitleOffsetF  = .05
	; res2D@lbTitleExtentF = .05
	; res2D@lbBoxMinorExtentF =  ;  default is 1.0

	res2D@gsFontQuality = "High"

	res2D@gsnDraw              = False      ; Don't draw individual plot.
	res2D@gsnFrame             = False      ; Don't advance frame.
	res2D@tiXAxisFuncCode    = "~"
	res2D@tmYRLabelFuncCode= "~"
	res2D@tmYLLabelFuncCode = "~"
	res2D@vpXF                 = 0.10       ; .1 x location 
	res2D@vpYF                 = 0.92       ; y location
	res2D@vpWidthF             = 0.82       ; .82 width big!
	res2D@vpHeightF            = 0.74       ; .8 was windgram alone  height
	res2D@tiYAxisOffsetXF        =  -.06    ;moves it slightly to the left
	res2D@tiXAxisOffsetYF        =  .005   ;-.02 ;16       ;- moves it slightly down + up  .02 makes it nicely close to the time ticmarks

	;module 3b  resources for contour plots humidity and lapse
	if (.not.isvar("tstride"))
		tstride=2
	end if
	
	resolution="~F22~1.3km~F21~"
	if (grid.eq."d2")
		tstride=1
		resolution="~F22~4.0km~F21~"
	end if 
	
	;4test print("tstride = " + tstride)
	res2D@tiXAxisString        = "~B~Time(" + pstpdt + ")   Location = " + siteLatArray(ns) + " " + siteLonArray(ns) + "  Base = " + round(hft,0) + "ft~CC~Wind(knots)  Lapse rate(C/1000ft)" ;plottime   ;ns wlat is for this region wlats is all regions...
	res2D@tiYAxisString        = " "
	;  res2D@tiYAxisString        = "Pressure_Height -- 10mb --> 300ft  "  ;don't use if it isn't obvious they shouldn't be using these.
	res2D@tiYAxisFontHeightF   = 0.02
	res2D@tiXAxisFontHeightF   = 0.025
	res2D@tiMainFontHeightF    = 0.02

	;Sun Mar-05 / TigerMt (1.3km)
	fcstday = systemfunc("date -d " + day + " +'%a %b-%d'")

	res2D@tiMainString	       = fcstday + " / " + siteNameArray(ns) + " (" + resolution + ")"
	res2D@trYMinF              = min(theselevels)
	res2D@trYMaxF              = max(theselevels)
	;needed so top labels and ticks can be different from bottom
	res2D@tmEqualizeXYSizes    = False
	;bottom tickmarks
	res2D@tmXUseBottom         = False                ;needed so top labels and ticks can be different from bottom
	res2D@tmXBMode             = "Explicit"
	res2D@tmXBValues           = taus(::tstride)
	res2D@tmXBLabelsOn         = True ; times   
	res2D@tmXBLabels           = lst(::tstride)   ;  times   pst pdt??

	if (show_up_vel.ne.0) then
		; top tick marks 
		res2D@tmXTOn               = True
		res2D@tmXTLabelsOn         = True ; wstar
		res2D@tmXTMinorOn          = False
		res2D@tmXTMajorLineColor   = line_color
		res2D@tmXTMajorLengthF     = .02
		;  res2D@tmXTLabelDeltaF      = .01
		res2D@tmXTMode             = "Explicit"
		res2D@tmXTValues           = taus(::tstride)
		res2D@tmXTLabels 	       = swstartxt(::tstride)  ;wstar string form as top label
		res2D@tmXTLabelFontColor   = wstar_color
		res2D@tmXTLabelFontHeightF = .014
		res2D@tmXTLabelFont            = 21
	end if
	
	res2D@tmYLLabelFont        = 21                ;helvetica http://www.ncl.ucar.edu/Document/Graphics/font_tables.shtml
	res2D@tmYRLabelFont        = 21
	res2D@tmXBLabelFont        = 21
	res2D@tmXBLabelJust        = "CenterCenter"
	res2D@tmXBLabelFontHeightF = .016
	res2D@tmYLLabelFontColor   =  label_color
	res2D@tmYLMajorLengthF     = .01
	res2D@tmYLLabelDeltaF      =  -1
	res2D@tmXBMajorLengthF     = .01
	res2D@tmYLOn               = True
	res2D@tmYLMode             = "Explicit"
	res2D@tmYLBorderOn         = True
	; tweak the placement of the title strings  only these are being shown all others are off.
     
	ystride=floattointeger(round(ptop/9,0))  ; generate reasonable stride value much closer than automatic 

	;ystride=floattointeger(round(ptop/9,0))  ; generate reasonable stride value much closer than automatic 

	res2D@tmYLLabels           = stplevels(:ptop-1:ystride)+"~C~"+meters(:ptop-1:ystride)
	;res2D@tmYLLabels           = stplevels(:ptop:ystride)
	;res2D@tmYLLabels           =  meters(:ptop-1:ystride)

	res2D@tmYLValues           = theselevels(::ystride); plevels ;(::ystride)
	res2D@tmYUseLeft           = False   ; necessary for right labels to work at all
	res2D@tmYROn               = True
	res2D@tmYLLabelsOn         = True
	res2D@tmYRLabelsOn         = True
	res2D@tmYRMode             = "Explicit"
	res2D@tmYRBorderOn         = True
	res2D@tmYRLabels           = feets(:ptop-1:ystride)
	res2D@tmYRValues           = theselevels(::ystride) ; plevels;(::ystride)
	res2D@tmYLLabelFontHeightF = .016
	res2D@tmYRLabelFontHeightF = .016
	res2D@tmYRMajorLengthF     = .01
	res2D@tmYRLabelDeltaF      =  -1
	res2D@tmYLBorderOn         = True 
	res2D@tmYLBorderOn         = True 

	;show_rain=0  ; rain debugged June 1, 2011 tjo in use july 28, 2010 tjo see Andrea's implementation.
	if (show_rain.ne.0) then
		rain1= new(numtimes,integer)
		;rain1=getblip_param("rain1", 13, "siteNameArray(ns)","1hr_rain_acc" )  added 4th parameter so different start times can be used.
		rain1 = getblip_param("rain1",bliptimes,siteNameArray(ns),"1hr_rain_acc",numtimes)
		print("Checking for Rain in forecast.  bliptimes = "+bliptimes)
		rain=systemfunc("cat tempfile.rain1")
		if (.not.(rain.eq."(/missing /)")) then
			print("rain ="+rain)
			;print (rain1)
			
			if (.not.(max(rain1).gt.0)) then
				show_this_rain=0
				print("No rain in the forecast for "+siteNameArray(ns)+".")
			else
				show_this_rain=1
				print("Rain in forecast for "+siteNameArray(ns)+".")
			end if
		end if

		if (show_this_rain.ne.0) then
			; this might be generalizable to all getblips, but for now make it specific to rain1
			do i=0,numtimes-1
				if (ismissing(rain1(i))) then
					rain1(i)=0
				end if
			end do
		end if
 
		;print(rain1)
		;--------- Resources for rain plot an xy plo
		rain_res=res2D
		rain_res@gsnXYBarChart = True
		rain_res@gsnXYBarChartBarWidth = 0.35           ; change bar widths
		rain_res@gsnXYBarChartColors = (/6/) ; choose color from those available
		rain_res@gsnXYBarChartPatterns = (/16/) ; choose 
		rain_res@gsnRightString = "*"
		rain_res@trYMinF = 0.0
		rain_res@trYMaxF = 20.0

		rain_res@tiMainString	      = ""
		rain_res@tiXAxisString        = ""
		rain_res@tiYAxisString        = ""
		;   rain_res@tmXTValues        = bliptaus ;res2D@tmXTValues           = taus(::tstride) just use whatever res2d had.
		rain_res@trYReverse = True
		;  -------- tickmark resources                                                                                           
		rain_res@tmYROn = False
		rain_res@tmYLOn = False
		rain_res@tmXBOn = False
		rain_res@tmXBLabelsOn = False
		rain_res@tmXTOn = False
		rain_res@tmXTLabelsOn = False

		;------------------
		;;-------------------------------------------------------------------------------------------------------;
		;;--------begin defining the cloud fraction plot resources 
		;;-------------------------------------------------------------------------------------------------------;

		if (show_cloudfrac.ne.0) then
			cldfra_res=res2D
			;  -------- title resources  
			cldfra_res@tiMainString = ""
			cldfra_res@tiXAxisString = ""
			cldfra_res@tiYAxisString = ""

			;  -------- tickmark resources   
			cldfra_res@tmYROn = False
			cldfra_res@tmYLOn = False
			cldfra_res@tmXBOn = False
			cldfra_res@tmXBLabelsOn = False
			cldfra_res@tmXTOn = False
			cldfra_res@tmXTLabelsOn = False

			;  -------- scalar field resources
			cldfra_res@sfYArray = theselevels

			;  -------- label bar resources
			cldfra_res@lbLabelFontHeightF = 0.002

			;  -------- contour resources
			cldfra_res@cnLevelSelectionMode = "ExplicitLevels"
			cldfra_res@cnLevels = (/ 0.1,0.3,0.5,0.7,1 /)         	;set at top of script or command line
			cldfra_res@cnFillPatterns = (/ -1,6,6,6,6,6 /)      		; white crosshatching
			cldfra_res@cnFillColors = (/"white","grey20","grey15","grey10","grey5","black" /)  ; white crosshatching
			cldfra_res@cnFillScales = (/ -1,0.6,0.5,0.4,0.3,0.2 /)  ; white crosshatching
			cldfra_res@cnFillScaleF = .3
			cldfra_res@cnFillOn = True
			cldfra_res@cnMonoFillPattern = False
			cldfra_res@cnMonoFillScale = False
			cldfra_res@cnMonoFillColor = False
			cldfra_res@cnFillColor = "black"
			cldfra_res@cnFillPattern = 16        
			cldfra_res@cnFillDotSizeF = 0.04    
			cldfra_res@cnLinesOn = False
			cldfra_res@cnLineLabelsOn = False
			cldfra_res@cnInfoLabelOn = False

			cldfra_plot=gsn_contour(wks,cldfragrid,cldfra_res)
			;....
			draw(cldfra_plot)
		end if
		;;---------------------End cldfra section--------------------------------------------------

		;-------- Rain   resources   
		rain_res@tmYROn = False
		rain_res@tmYLOn = False
		rain_res@tmXBOn = False
		rain_res@tmXBLabelsOn = False
		rain_res@tmXTOn = False
		rain_res@tmXTLabelsOn = False
		;   rain_res@gsnXYBarChartColors = (/"blue"/)     
		; draw rain1 barchart  ;move to end
		; printVarSummary(rain1)
		; print(taus)

		rain_plot = gsn_csm_xy(wks,taus,rain1,rain_res)
	end if  ;end of if (show_rain)

	hum_res=res2D  ;define it even if not used.

	if (show_rh.ne.0)
		;;-------------------------------------------------------------------------------------------------------;
		;;--------begin defining the relative humidity plot resources only plot if gt 95% -- use small cross hatch
		;;-------------------------------------------------------------------------------------------------------;
		;4test printVarSummary(rh)
		; now just at the focal point
		rhpoint = rh(:,:,locY,locX)
		; and grid it so it is only up to ptop with Time as rightmost dimension for plotting 
		rhgrid     = rhpoint(bottom_top|:ptop,Time|:)  
		rhgrid@description ="Relative Humidity"

		; define plotting resources for the relative humidity plot with only 2 levels below and above rhcut (default 95%)
		hum_res=res2D
		hum_res@sfYArray             = theselevels
		hum_res@cnLevelSelectionMode = "ExplicitLevels"
		hum_res@cnLevels             = (/ rhcut /)    ; set at top of script or command line  eg. rhcut=.98 
		hum_res@cnFillOn             = True
		hum_res@cnFillColors         = (/-1,1/)       ; white crosshatching
		hum_res@cnFillScaleF         = .3
		hum_res@cnFillPattern        = 6              ;6 crosshatch  17 is stipple
		hum_res@cnFillDotSizeF       = 0.04           ;default is 0.0
		hum_res@tmXBOn               = False          ; turn off things that we don't want 
		hum_res@tmYROn               = False
		hum_res@cnLinesOn            = False
		hum_res@cnLineLabelsOn       = False
		hum_res@tmXTLabelsOn         = False
		hum_res@tmXBLabelsOn         = False
		hum_res@cnInfoLabelOn        = False
		hum_res@tiMainString	        = ""
		hum_res@tiXAxisString        = ""
		hum_res@tiYAxisString        = ""
		hum_res@lbLabelFontHeightF   = 0.002
		; ----------------create the plot object ---------------------------
		rel_humd=gsn_contour(wks,rhgrid,hum_res)
		;;---------------------End relative humidity section --------------------------------------------------
	end if

	;   cldfra_res = res2D
	;   cldfra_res@cnFillScaleF = .3
	;   cldfra_res@tmYROn = False
	;   cldfra_res@tmXBOn = False
	;   cldfra_res@cnFillOn = True
	;   cldfra_res@cnFillPattern = 15  ;6        ; 6-16 crosshatch  17 is stipple
	;   cldfra_res@cnFillDotSizeF = 0.07      ;default is 0.0  applies to 17 stipple
	;   cldfra_res@cnFillDrawOrder = "PostDraw"
	;   cldfra_res@cnLinesOn = False
	;   cldfra_res@cnLineLabelsOn = False
	;   cldfra_res@tmXTOn  = False
	;   cldfra_res@tmYLLabelsOn = True
	;   cldfra_res@tmYRLabelsOn = False
	;   cldfra_res@tmXTLabelsOn = False
	;   cldfra_res@tmXBLabelsOn = False
	;   cldfra_res@cnInfoLabelOn = False
	;   cldfra_res@tiMainString	      = ""
	;   cldfra_res@tiXAxisString        = ""
	;   cldfra_res@tiYAxisString        = ""
	;   cldfra_res@lbLabelFontHeightF = 0.002
	;   cldfra_res@cnMonoFillPattern = True                  ; use same pattern for all levels
	;   cldfra_res@cnLevelSelectionMode = "ExplicitLevels"
	;   cldfra_res@cnLevels =            (/.5, .75,.85,.95 /)               ;
	;   cldfra_res@cnFillColors         = (/-1,12,13,14,15/)                 ; grey to black crosshatching
	;   cldfra_res@cnFillBackgroundColor = "white"
	;   cldfra_res@cnFillScaleF = .5
	;   cldfra_res@cnFillPattern = 6 
	;   cldfra_res@cnFillDotSizeF = 0.06 
    
	;;-------------------------------------------------------------------------------------------------------;
	;;-------------------------------------------------------------------------------------------------------;
	;     resources for local lapse rate contour plot 
	;;-------------------------------------------------------------------------------------------------------;
	lapse_res = res2D
	lapse_res@sfYArray = theselevels
	lapse_res@trYMinF   = min(theselevels)  ;minp
	lapse_res@trYMaxF   = max(theselevels)  ;p
	lapse_res@trYReverse = True             ; coordinates are pressure so  true for plevels coordinates
	lapse_res@cnLevelSelectionMode = "ExplicitLevels"  ; -3 is condsidered absolutely unstable  
	lapse_res@cnLevels =            (/ -3.,-2.5,-2.0,-1.5,-1.2, -.5, 0.,.5 /)
   
	if (hide_lapse_colors.eq.0)
		;lapse_res@cnFillColors         = (/ 11,10,7,8,3,-1,-1,13,14 /)      ;should work pink and purple reversed using updraft.rgb 12,13,14  gray
		;lapse_res@cnFillColors         = (/ 16, 17, 18, 19, 20 , -1, -1, 13, 14 /)  ; for use with a "gradient" style palette with colored barbs
		lapse_res@cnFillColors         = (/ 11,10, 7,   8,  3,-1,-1,13,14 /)      ;should work pink and purple reversed using updraft.rgb 12,13,14  gray
	else
		lapse_res@cnFillColors         = (/ -1,-1,-1,-1,-1,-1,-1,-1,-1 /)      ;all transparent so lapse rate doesn't show.
	end if
   
	lapse_res@cnFillOn             = True
	lapse_res@cnLinesOn            = False
	lapse_res@cnLineLabelsOn       = False
	lapse_res@tmXTLabelsOn         = False ;change to use wstar at top
	lapse_res@tmXBLabelsOn         = False
	lapse_res@cnInfoLabelOn        = False
	lapse_res@tiMainString	  = ""
	lapse_res@tiXAxisString        = ""
	lapse_res@tiYAxisString        = ""
	lapse_res@lbLabelFontHeightF   = 0.014
	lapse_res@pmLabelBarOrthogonalPosF = 0.036

	;;-------------------------------------------------------------------------------------------------------;
	;;-------------------------------------------------------------------------------------------------------;
	;               resources for lcl markers
	;;-------------------------------------------------------------------------------------------------------;
	; Add some cloud markers to plot all markers are plotted with a contour plot, not a vector plot:
	;  - Create a cloud marker.
	;  - Set some marker resources.
	;  - Attach markers to "plot" using gsn_add_polymarker
	;    Font 37 has a cloud for the letter k   19 / is a "paraglider",  20 E static= C ,20 / a blipspot, 20 6 a crescent moon angle 270 is a paraglider.
	;    34 E is a blipspot  34 D is an Xspot, 36 ) is turbulence, 37 B  180deg a rogollo wing 37g raindropblown   35 < ... 
	;    37 F lightning  g and o Rain, q snowflake ,r fastcloud, k puffycloud  
	mstring = "k"
	fontnum = 37
	xoffset = 0.0
	yoffset = 0.0
	tallyoffset = 0.5
	ratio   = .75
	tall  = 1.5
	size    = 1.4   ; 2 if sparse
	angle   = 0.0
    
	cloud = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, ratio, size, angle)  ;puffy cloud
	darkcloud = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, 1, 3, angle)  ; big puffy cloud for coloring dark dewpt=tmp
	cloudfast = NhlNewMarker(wks, "r", 37, xoffset, tallyoffset, tall, size, 0)          ;wind blown cloud
	paragl = NhlNewMarker(wks, "6", 20, xoffset, yoffset, tall, .5, 270)                 ;crescent moon tipped over
	ceilingmrk = NhlNewMarker(wks, "<", 35, xoffset, yoffset,  ratio, size, angle)       ;unused  three dots
	pbl_mark = NhlNewMarker(wks, "E", 20, xoffset, yoffset,  .3, 3*size, angle)            ; horizontal bar 
	snowflake= NhlNewMarker(wks, "q", 37, xoffset, yoffset,   1, 1, 0)                   ; snowflake for freezing level
	raindrop=NhlNewMarker(wks, "g", 37, xoffset, yoffset,   1, .2, 0)			 ; raindrop thing curved
	rogallo=NhlNewMarker(wks, "B", 37, xoffset, yoffset,   .5, .5, 180)  			 ; rogallo wing head on
	hgldr=NhlNewMarker(wks, "-", 35, xoffset, yoffset,   1.5, 1.2, 40)  			 ; high aspect hg narrow wings
	mkres                    = True
	mkres@gsClipOn           = False         ;symbols may overhang edges of the viewport.
	mkres@gsMarkerIndex      = cloud
	mkres@gsMarkerSizeF      = 0.03
	mkres@gsMarkerThicknessF = 2
	mkres@gsMarkerColor      = "white"
	;xmarkers=taus
        
	mkres2 = mkres   ; copy mkres then change color and marker
	mkres2@gsMarkerColor      = "white"  ;12        ; using for drjack sfclclheight   grey cloud spare for CCL or stratus
	mkres2@gsMarkerIndex      = cloud

	mkres3 =mkres
	mkres3@gsMarkerThicknessF = 3
	mkres3@gsMarkerColor	   ="blue"
	mkres3@gsMarkerIndex      = paragl


	mkres4 =mkres
	mkres4@gsMarkerColor      ="white"
	;mkres4@gsMarkerIndex      = ceilingmrk
	mkres4@gsMarkerIndex      = snowflake    ;freezing level

	mkres5 =mkres
	mkres5@gsMarkerIndex      = pbl_mark     ;pbl_mark
	mkres5@gsMarkerColor      = "yellow"
   
	mkres6=mkres
	mkres6@gsMarkerIndex = darkcloud   ; for use where dewpoint=temperature 
	mkres6@gsFillIndex = 16 ;   http://www.ncl.ucar.edu/Document/Graphics/Images/fillpatterns.png
	mkres6@gsMarkerColor = "grey"

	mkres7 =mkres
	mkres7@gsMarkerThicknessF = 3
	mkres7@gsMarkerColor	   ="blue"
	mkres7@gsMarkerIndex      = hgldr
   
	;;----------------------------Vector plot resources for windgram ----------------------------------------;
	;;----most tick mark labels come from here --------------------------------------------------------------;
	uv_res = res2D
	uv_res@tmYUseLeft           	  = False  	; 
	uv_res@vcRefAnnoOn      	  = False       ; turns off the ref vector
	uv_res@vcRefLengthF     	  = 0.030       ; .04 set length of ref vector
	uv_res@vcGlyphStyle     	  =  "WindBarb"  ; turn on wind barbs  other choices CurlyVector LineArrow FillArrow
	;control this below  uv_res@vcMonoWindBarbColor      = False ;True   	;False    colored barbs  get lost in the lapse colors only sho if hiding lapse
	uv_res@vcWindBarbColor         = "white"  ;gray48" ;(\ 0.9,0.9,0.9 \) ;    colored barbs  get lost in the lapse colors only sho if hiding lapse
	uv_res@vcLevelSelectionMode    = "ExplicitLevels" ; will explicitly set the levels
	uv_res@vcWindBarbLineThicknessF= 3           ; has been 3 set the wind barb thickness 3 works well for png output
	uv_res@vcExplicitLabelBarLabelsOn = True
	; if using arrows instead of windbarbs
	;   uv_res@vcFillArrowsOn = True
	;   uv_res@vcMonoLineArrowColor = False
	;   uv_res@vcFillArrowFillColor = False
	;   uv_res@vcMonoFillArrowEdgeColor = False
	; without these defined, the colors are reasonable the settings with ;; are possibly marginally better.
	; but if there is a larger spread of windspeeds eg ptop =40  then the default color assignments fail
	;   uv_res@vcLevels 		  = (/ 5.,7.5,10.,12.5,15.,17.5,20.,22.5 /)   ;knots 1.852km 1.1507mph 
	uv_res@vcLevels 		  = (/ 3.,6.,9.,12.,15.,18.,21. /) ;*1.852   ;knots 1.852km 1.1507mph
	;  uv_res@vcLevels                = (/2.7,5.4,8.1,10.8,13.5,16.2,18.9,21.6 /) ;color by 5 kilometer/hr increments 
	;   uv_res@vcLevelColors  	  =  (/3,4,5,6,7,8,9,10,11,11,11/); (/12,13,14,15,16,17,18,19 /) ;4,5,6,8,9,10,11
	;was   uv_res@vcLevelColors     =  (/3,4,5,6,7,8,9,10,11,11,11/); (/12,13,14,15,16,17,18,19 /) ;4,5,6,8,9,10,11
	uv_res@vcLevelColors         =  (/4,4,5,1,1,1,1,1,1,1,1/); (/12,13,14,15,16,17,18,19 /) ;4,5,6,8,9,10,11

	uv_res@vcWindBarbCalmCircleSizeF = .35 ;
	;  but need a windspeed legend somehow... 5,10,15,20,25,30,35																		       
	;;;;;;;;;;;;;;;;;;;;;
	uv_res@vcMapDirection = False      ; needed to disassociate the coordinate plane from the wind barbs thanks Andrea Barcellona
	;;;;;;;;;;;;;;;;;;;; 
	;   uv_res@vcLevelColors  	  = (/2,3,4,5,6,7,8,9,10/) 
	;  uv_res@vcMonoFillArrowEdgeColor = True
	;  uv_res@vcFillArrowEdgeColor = "black"
	; if (ptop.le.31) then 
	;  wstride=ystride
	; else
	;  wstride=2*ystride
	; end if
 
	uv_res@tmYLOn = True
	uv_res@tmYROn = True
	uv_res@tmYRValues = theselevels(::ystride) ;  theselevels is plevels up to ptop-1
	uv_res@tmYLValues = theselevels(::ystride) ;  
	uv_res@tmYLLabelsOn = True
	uv_res@tmYRLabelsOn = True
	uv_res@tmYRLabels = feets(:ptop-1:ystride)
	;  uv_res@tmYLLabels = stplevels(:ptop:ystride)
	;  uv_res@tmYLLabels = meters(:ptop:ystride)
	uv_res@tmYLLabels = stplevels(:ptop-1:ystride)+"~C~"+meters(:ptop-1:ystride)
	uv_res@trYMinF = min(theselevels) ;minp
	uv_res@trYMaxF = max(theselevels) ;p
	uv_res@trYReverse = False   	;checked must be false here.  
  
	;-----------------------------------------------------------------------------------------------------;
	;-----------------------------------------------------------------------------------------------------;
	;-------------     the  end of main site loop plots what has been set up.  ---------------------------;
	;-----------------------------------------------------------------------------------------------------;
	;-----------------------------------------------------------------------------------------------------;

	;;; SET BASIC TEXT RESOURCES
	lbtxtres = True
	lbtxtres@txtFontQuality = "High"
	lbtxtres@txFuncCode    = "~"  
	lbtxtres@txFontHeightF = 0.015                  
	lbtxtres@txFontHeightF = 0.015                  
	lbtxtres@txJust = "CenterLeft"         
	; position

	;;;       Create a Time Stamp for the plot -- when it was plotted.
	;;      timestamp=systemfunc("date +%H:%M_%Z")
	; ABC Oct 9, 2012 - Added date to timestamp and fixed extra space.
	;timestamp=systemfunc("date +%Y-%m-%d' '%H:%M' '%Z")
	timestamp=systemfunc("date +'Plotted '%a' '%H:%M''%Z")
	;TJO July 6, 2015  changed to have for date  and when plotted times.        

	timestamp="~F14~~Z60Q~" + timestamp + "~C~~F14~" + operator
	;      timestamp="~F14~~Z60Q~plotted~C~"+timestamp+"~C~~F14~TJ Olney"
	timestampyNDC = 5 * lbtxtres@txFontHeightF  ;was 4*
	timestampxNDC = .005 ;lbtxtres@txFontHeightF
	;draw the timestamp  
	gsn_text_ndc ( wks, timestamp, timestampxNDC, timestampyNDC, lbtxtres )

	;create the lapse_plot object -- colored backgrounds
	lapse_plot=gsn_csm_contour(wks,lgrid,lapse_res)

	;create the wind_gram  object  -- wind barbs
	wind_gram = gsn_vector(wks, ugrid, vgrid, uv_res)

	;print(" Maximum cloud fraction upto ptop-1 is ="+max(l_cldfra))
	;print(" cloud fraction cut off is ="+cldfra_cut)
	;if (max(l_cldfra).ge.cldfra_cut)
	;	cldfra_plot=gsn_contour(wks,l_cldfra,cldfra_res)
	;end if

	raspmsg="RASP~F35~d~F14~~Z80Q~~C~DrJack"          ;RASPtm italic DrJack
	gsn_text_ndc (wks, raspmsg, .005, .975, lbtxtres)    ;put the message .94 from bottom and .01 from left 800x800 48px down 8px in

	stablemsg=""

	;; if we are coloring in the lapse rate this section applies.
	if (show_lapse.ne.0)
		if ((hide_lapse_colors.ne.0).or.(color_wind_barbs.eq.1))
			;  uv_res@vcMonoFillArrowFillColor = False
			uv_res@vcMonoWindBarbColor      =  False ;True  	;False    they get lost in the lapse colors
			if (debug.ne.0) then
				print(" hide_lapse_colors = "+hide_lapse_colors+" or color_wind barbs ="+color_wind_barbs+" and therefore monoWindbarb color set to False there should have been colors")
			end if
		else
			if (debug.ne.0)
				print(" hide_lapse_colors = "+hide_lapse_colors+" or color_wind barbs ="+color_wind_barbs+" and therefore monoWindbarb color set to False there should NOT NOT have been colors")
			end if
			uv_res@vcMonoWindBarbColor      =  True     ; make default monochrome windbarbs False   	;False    they get lost in the lapse colors
			;  uv_res@vcMonoFillArrowFillColor = False
		end if  

		lapse_plot=gsn_csm_contour(wks,lgrid,lapse_res)

		if (show_lcl.ne.0)
			marker = gsn_add_polymarker(wks,lapse_plot,taus,lclj_p,mkres)       ; dr jack's lcl calc  was lcl4 -- These are all pretty darn close to lclvl()
		end if

		if (show_wing.ne.0) 
			marker3 = gsn_add_polymarker(wks,lapse_plot,taus,hgldj_p,mkres3)       ; hgldj_p max soar w/clouds  sideways crescent moons
			;   marker7 = gsn_add_polymarker(wks,lapse_plot,taus,effwing_p,mkres7)     ; efficient wing at 175fpm sink rate  ignore clouds
		end if

		if (show_snow.ne.0) 
			marker4 = gsn_add_polymarker(wks,lapse_plot,taus,freezelevel,mkres4)       ; lowest freezing level snowflakes
		end if

		if (show_pbl.ne.0) 
			marker5 = gsn_add_polymarker(wks,lapse_plot,taus,lpblt_p,mkres5)       ; level of planetary boundary layer
		end if

		if (show_condense.ne.0)
			condenselevels=gsn_contour(wks,condense,hum_res)
			;     marker6 = gsn_add_polymarker(wks,lapse_plot,taus,lpblt_p,mkres6)       ; level of planetary boundary layer
		end if

		lbtxtres@txFontHeightF = 0.02
		;-2.5,-2.0,-1.5,-1.2,
		stablemsg="~F14~~Z60Q~Unstable      Conditional Instability               Stable            Inverted ";~C~-3C/1000ft      Local Lapse Rate           -1.2C/1000ft"
		draw(lapse_plot)
	end if

	if (show_rh.ne.0)
		rhmsg="~F14~~Z60Q~rhcut~C~"+rhcut+"%"
		gsn_text_ndc ( wks, rhmsg, .93, timestampyNDC,lbtxtres )
		rel_humd=gsn_contour(wks,rhgrid,hum_res)
		draw(rel_humd)
	end if

	if (show_wind.ne.0)
		wind_gram = gsn_vector(wks,ugrid,vgrid,uv_res)
		draw(wind_gram)
		;   delete(wind_gram)
	end if   
    ;.102 .024 puts the stable msg at left border of colored bar. 
   gsn_text_ndc ( wks, stablemsg, .102, .024,lbtxtres )  ; was .113, .024 for bottom of box

	;;  ----------------  Temperature contour lines if desired.
	if (show_temp.ne.0)
		if (tmp_units.eq.1)
			tcloc=((tkloc-273.15)*1.8)+32         ; Farenheight  tmp_units=0 for Celcius
		else
			tcloc=tkloc-273.15                    ; Celcius
		end if  

		tcloc!0="Time"
		tcloc!1="bottom_top"
		tcgrid=tcloc(bottom_top|:ptop,Time|:)   ;reverse x and y trick to get time  on horizontal axis

		tc_res=res2D
		tc_res@sfYArray = theselevels
		tc_res@cnFill = False
		tc_res@cnLinesOn = True
		tc_res@cnLineLabelsOn = True
		tc_res@cnLineColor = templine_color
		tc_res@tmXBLabelsOn = False
		tc_res@cnInfoLabelOn = False
		tc_res@tiMainString       = ""
		tc_res@tiXAxisString        = ""
		tc_res@tiYAxisString        = ""
		showtemp=gsn_contour(wks,tcgrid,tc_res)
		draw(showtemp)
		delete(showtemp)
	end if

	;; use real altitude for right hand labels!
	; zhere is the msl altitude in feet at each pressure level at each time at this location
	if (show_z_contour.ne.0)  
		zgrid = zhere(plevels|:ptop-1,Time|:)
		;;  z contours
		z_res = res2D
		z_res@sfYArray = theselevels
		;z_res@cnFill = False
		z_res@cnLinesOn = True
		z_res@cnLineLabelsOn = False  ;very busy if True
		z_res@tmXBLabelsOn = False
		z_res@tmYLLabelsOn = False
		z_res@tmYRLabelsOn = False
		z_res@cnInfoLabelOn = False
		z_res@tiMainString       = ""
		z_res@tiXAxisString        = ""
		z_res@tiYAxisString        = ""
		z_res@trYReverse   = True
		z_res@cnLevelSelectionMode     = "ExplicitLevels" ; will explicitly set the levels

		;printVarSummary(numtimes)
		;printVarSummary(theselevels)
		;printVarSummary(plevels)
		;printVarSummary(zhere)

		;  z_res@cnLevels            = zhere(numtimes-1,plevels|:ptop-1:ystride*4) ; will explicitly set the levels
		;  z_res@cnLevels            = zhere(numtimes-1:,plevels:ystride*4) ; will explicitly set the levels
		zlevels=zhere(numtimes-1,:)
		z_res@cnLevels            = zlevels(:ptop-1:z_stride) ; will explicitly set the levels stride for p and z must match
		showz=gsn_contour(wks,zgrid,z_res)
		draw(showz)
		delete(showz)
	end if

	;4 test show_p_contour = 1
	if (show_p_contour.ne.0)  
		;  create a set of pressure lines to show change in pressure during day.
		phere=pmb(:,:,locY,locX)
		phere!0 = "Time"
		phere&Time = taus
		phere!1 = "levels"
		phere&levels = plevels
		pgrid=phere(levels|:ptop-1,Time|:)
		;printVarSummary(phere)
		;printVarSummary(pgrid)
		p_res=z_res
		p_res@cnLineColor = "red"
		p_res@cnLevels          = plevels(:ptop-1:p_stride) ; will explicitly set the levels stride must match z_res stride
		showp=gsn_contour(wks,pgrid,p_res)
		draw(showp) 
		; write_matrix(pgrid, "24f5.0", False)
	end if

	;has to be last to show at all.
	;avoid fatal error above and set to 0 if no rain in forecast.
	if (show_this_rain.ne.0)
	   draw(rain_plot) 
	end if

	if (debug.eq.2) then
		;;; ------------------------------debugging section 
		thisdebug = True

		print("The following is the output from list_hlus ")
		list_hlus()
		print(" ")
		print(" ")
		print(" ")
		print("The following is the output from list_files")
		list_files()
		print(" ")
		print(" ")
		print(" ")
		print("The following is the output from list_vars")
		list_vars()
		print(" ")
		print(" ")
		print(" ")

		print("There are these gsn objects being created by the program")
		print(" ")
		findgsn = "egrep '=.*gsn' windgramtj.ncl |egrep -v '^ *;'"
		gsnlist = systemfunc( findgsn )
		print(gsnlist)
		print(" ")

		bb = NhlGetBB((/rel_humd,lapse_plot,wind_gram/))
		;bb = NhlGetBB((/rel_humd,timestamp,lapse_plot,wind_gram,raspmsg,marker/))
		print("the bounding boxes of the various plotted items are below ")
		print(bb)
		  
		print("begin res2D")
		print_opts(res2D, res2D, thisdebug)
		print(" ")
		print(" ")

		print("begin lapse_res")
		print_opts(lapse_res, lapse_res, thisdebug)
		print(" ")
		print(" ")

		print("begin hum_res")
		print_opts(hum_res, hum_res, thisdebug)
		print (" ")
		print (" ")

		print("begin uv_res")
		print_opts(uv_res, uv_res, thisdebug)
		print(" ")
		print(" ")

		do i = 0, numtimes-1
			print ("lcl1(" + i + ") =" + lcl1(i) + " hPa ")
		end do;

		print("press at surface = " + press(0,0,locY,locX)/100 + "pressure at top of region =" + press(0,ptop,locY,locX)/100)
		print("hgt =" + hft + "  z lowest surface = " + z(0,0,locY,locX) + " ")
	end if

	; now frame the plot   
	frame(wks)                            

	delete(wks)

	nclv = get_ncl_version() ;returns string like 6.0.0 or 5.2.1
	nclv_c = stringtochar(nclv) ; creates an array of character types 
	vnum = stringtoint(chartostring(nclv_c(0))) ; takes first element of above and turns it into an integer
	delete(nclv)
	delete(nclv_c)
	
	; deal with ncl png naming issue 5.1 5.2 goes away in  6.0.0. so only try if vnum < 6
	if ((type .eq. "png") .and. (vnum.lt.6))
		mvcommand="mv " + windgram + ".000001.png " + windgram + ".png"
		print(" " + mvcommand)
		system(mvcommand)
	end if

	;destroy(wks)

end do; 
;;-----------------------------------------------------------------------------------------------------------------;
;;    end of site loop   is doing a region we loop through here once for each site in the region keeping data intact
;;-----------------------------------------------------------------------------------------------------------------;

delete(ns)

delete(a)
delete(b)
delete(caption)

delete(day)
delete(fs)
delete(onefile)

if (isvar("zmeters"))
	delete(zmeters)
end if 

if (isvar("zhere"))
	delete(zhere)
end if 

if (isvar("zhere_m"))
	delete(zhere_m)
end if 

if (isvar("zmeter"))
	delete(zmeter)
end if

if (isvar("zft"))
	delete(zft)
end if

if (isvar("z"))
	delete(z)
end if

if (isvar("zfeet"))
	delete(zfeet)
end if 

if (isvar("feets"))
	delete(feets)
end if

delete(filecommand1)
 
delete(freezelevel)

if (isvar("ftdiffs"))
	delete(ftdiffs)
end if

if (isvar("hdiffs"))
	delete(hdiffs)
end if

delete(hfx)
delete(h)

;delete(cl_fdiff)
;delete(cl_pdiff)
;delete(cloudbase)
;delete(counter)
;delete(height_0)
;delete(heights)
;delete(lapse)
;delete(l_cldfra;delete(levels)
;delete(slst)
;delete(hpbl)
;delete(tpbl)
;delete(pressheights)

delete(lapseptop)
delete(lcl1)
delete(lcl4)
delete(lclj_p)
;delete(bltj_p)
delete(hgldj_p)

delete(plevels)
delete(theselevels)
delete(lgrid)
delete(locij)
delete(lp)

if (show_pbl.ne.0) then
	delete(lpblt)
	delete(lpblt_p)
end if


delete(lqv)
delete(lmslp)
delete(lhcrit)
delete(lsfclclheight)
delete(lhglider)
delete(lst)
delete(ltd)
delete(maxp)
delete(minp)
delete(mslp)
delete(p)
delete(numx)
delete(numy)
delete(numlevels)

delete(pb)
delete(PH)
delete(PHB)
delete(press)
delete(pmb)
delete(pblh)
delete(pblt)

delete(PSFC)
delete(QVAPOR)
delete(rh)

if (show_rh.ne.0) then
	delete(rhpoint)
	delete(rhgrid)
end if

delete(t_0)
delete(t_1)
delete(taus)
delete(bliptaus)
delete(tc)
delete(tcloc)
delete(tcgrid)
delete(td)
delete(tdiffs)
delete(ter)
delete(times)
delete(timesinfiles)
delete(tk)
delete(tkall)
delete(tkloc)
delete(tmp)
delete(tmpu)
delete(tmpv)
delete(u)
delete(ugrid)
delete(u_point)
delete(v)
delete(vhf)
delete(vgrid)
delete(v_point)
delete(XLAT)
delete(XLONG)
delete(wstar)
delete(lwstar)
delete(wstar_1)
delete(mwstar)
delete(swstartxt)
        
delete(hcrit)
delete(hcrit_1)
delete(sfclclheight)
delete(sfclclheight_1)
delete(hglider_1)
delete(hglider) 
delete(zgrid)

; must delete domain specific variables that have dimensions
;delete the resources as well
delete(res2D)
delete(lbtxtres)
delete(lapse_res)
delete(hum_res)
delete(mkres)
delete(mkres2)
delete(mkres3)
delete(mkres4)
delete(llres)
delete(uv_res)
delete(tc_res)
delete(z_res)
;delete(cldfra_res)

delete(outputDir)
delete(grid)
delete(data)
delete(siteListCsv)
delete(siteNameArray)
delete(siteLatArray)
delete(siteLonArray)
delete(wrfDomain)