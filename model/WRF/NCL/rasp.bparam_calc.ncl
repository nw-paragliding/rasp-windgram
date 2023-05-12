;  tjo  this takes the passed plot_param and creates a working variable bparam that is used in the rest of the scripts named *bparam*.ncl 
if(isvar("REGION").and.isvar("plot_param")) then
print("sequence ------------------  rasp.bparam_calc.ncl              "+REGION+"    "+plot_param+"  --------------------")
end if

fmsg = -999.  ;;default_fillvalue("float")  the . matters to make it a float
           ;;; RASP PARAMETER CALCULATIONS
           ;;; for parameter in file  
	   
;;	     external NCL_JACK_FORTRAN "ncl_jack_fortran.so"  ; works!

	   
           if ( plot_param .eq. "HGT" .or. plot_param .eq. "ter" ) then
                 bparam = ter
           end if
           if ( plot_param .eq. "sfcsun" .or.  plot_param .eq. "sfcsunpct" ) then
             bparam = wrf_user_getvar(a,"SWDOWN",time) 
             ;;; fmsg = missing for this calculated parameter
             bparam@_FillValue = fmsg
             ;;; USE OF CLOUDLESS SFC SOLAR RAD PERCENT CALC
             if ( plot_param .eq. "sfcsunpct" ) then
               ;;; get julian day and gmt
               monthlength = (/ 0,31,28,31,30,31,30,31,31,30,31,30,31 /) 
               jday = 0
               kmon = stringtoint( MM )
               do imon=1,(kmon-1)
                jday = jday + monthlength( imon ) 
               end do
               jday = jday + stringtoint(DD)
               ;;; treat leap year
               if( ( stringtoint(YYYY) % 4 ) .eq. 0 .and. kmon .ge. 2 ) then
                  jday = jday + 1 
               end if
               gmthr = stringtofloat(hh) + ( stringtofloat(mm) + (stringtofloat(ss)/60.0) ) / 60.0
               if ( .not. isvar("pmb") ) then 
                 pmb = wrf_user_getvar(a,"p",time) ; pressure in mb
               end if  
               if ( .not. isvar("tc") ) then 
                 tc = wrf_user_getvar(a,"tc",time)    ; temperature (C)
               end if
               if ( .not. isvar("qvapor") ) then 
                 qvapor  = wrf_user_getvar(a,"QVAPOR",time)   ; water vapor mixing ratio in kg/kg
               end if
               ;4test: print ( "MM= "+MM+"  jday= "+jday+"  gmthr= "+gmthr )
               NCL_JACK_FORTRAN :: calc_sfcsunpct( jday,gmthr, alat,alon,ter, z,pmb,tc,qvapor, isize,jsize,ksize, bparam ) 
             end if
           end if
           if ( plot_param .eq. "sfcshf" ) then
                 bparam = wrf_user_getvar(a,"HFX",time) 
           end if
           if ( plot_param .eq. "vhf" ) then
                 if ( .not. isvar("hfx") ) then 
                   hfx = wrf_user_getvar(a,"HFX",time)
                 end if        
                 if ( .not. isvar("tc") ) then 
                   tc = wrf_user_getvar(a,"tc",time) ; temp (C)
                 end if
                 ; convert latent heat flux into additional virtual temperature heat flux
                 ; 0.61*cp/L=0.61*(1006J/Kkg)/(2.502x106J/kg)=0.000245268
                 vhf = wrf_user_getvar(a,"LH",time) 
                 NCL_JACK_FORTRAN :: minlimit2d( vhf, 0.0, isize,jsize )
                 vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*vhf
                 bparam = vhf
                 ;old bparam = hfx +  0.000245268*(tc(0,:,:)+273.16)*wrf_user_getvar(a,"LH",time) 
           end if
           if ( plot_param .eq. "dbl" ) then
                 bparam = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
                 ;;; convert to pilot units (english)
                 if( UNITS .ne. "metric" ) then
                   bparam = 3.28084 * bparam  ; in ft   
                 end if
           end if
           if ( plot_param .eq. "hbl" ) then
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
               bparam = ter + pblh
               ;;; convert to pilot units (english)
               if( UNITS .ne. "metric" ) then
                 bparam = 3.28084 * bparam  ; in ft   
               end if
           end if
           if ( plot_param .eq. "wstar" .or. plot_param .eq. "hwcrit" .or. plot_param .eq. "dwcrit" .or. plot_param .eq. "wstar_bsratio"  .or. plot_param .eq. "hglider" ) then
             if ( .not. isvar("vhf") ) then 
               if ( .not. isvar("hfx") ) then 
                   hfx = wrf_user_getvar(a,"HFX",time) ; for sfc. sensible heat flux in w/m2
               end if
               if ( .not. isvar("tc") ) then 
                  tc = wrf_user_getvar(a,"tc",time) ; temp (C)
               end if
               ; convert latent heat flux into additional virtual temperature heat flux
               ; 0.61*cp/L=0.61*(1006J/Kkg)/(2.502x106J/kg)=0.000245268
                 vhf = wrf_user_getvar(a,"LH",time) 
                 NCL_JACK_FORTRAN :: minlimit2d( vhf, 0.0, isize,jsize )
                 vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*vhf
               ;old vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*wrf_user_getvar(a,"LH",time) 
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
                   wstar = new( (/jsize,isize/), float)
                   NCL_JACK_FORTRAN :: calc_wstar( vhf,pblh, isize,jsize,ksize, wstar ) 
                   ;old NCL_JACK_FORTRAN :: calc_wstar( hfx,pblh, isize,jsize,ksize, wstar )
		   ;NCL_JACK_FORTRAN :: calc_wstar( vhf,pblh, isize,jsize,ksize, wstar )
             if ( plot_param .eq. "wstar" .or. plot_param .eq. "wstar_bsratio" ) then
               ;;; convert to pilot units (english)
               if( UNITS .ne. "metric" ) then
                   bparam = 196.85 * wstar  ; in ft/min
               else
                   bparam = 100.* wstar  ; in cm/sec
               end if
             if ( plot_param .eq. "wstar_bsratio" ) then
               ;;; calc bsratio
               if ( .not. isvar("bsratio") ) then 
                 if ( .not. isvar("blavgwindspeed") ) then 
                   if ( .not. isvar("ua") ) then 
                     ua = wrf_user_getvar(a,"ua",time) ; velocity, averaged to mass points in m/s
                     ;;; convert to pilot units (english)
                     if( UNITS .ne. "metric" ) then
                       ua = ua * 1.94386
                     end if
                   end if
                   if ( .not. isvar("va") ) then 
                     va = wrf_user_getvar(a,"va",time) ; velocity, averaged to mass points in m/s
                     if( UNITS .ne. "metric" ) then
                       va = va * 1.94386
                     end if
                   end if
                   if ( .not. isvar("pblh") ) then 
                       pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
                   end if
                   pbltop = pblh + ter ;
                   if ( .not. isvar("ublavg") ) then 
                       ublavg = new( (/jsize,isize/), float)
                       NCL_JACK_FORTRAN :: calc_blavg(ua,z,ter,pblh, isize,jsize,ksize, ublavg ) 
                   end if
                   if ( .not. isvar("vblavg") ) then 
                       vblavg = new( (/jsize,isize/), float)
                       NCL_JACK_FORTRAN :: calc_blavg(va,z,ter,pblh, isize,jsize,ksize, vblavg ) 
                   end if
                   ;;; add contours of bl-avg wind speed
                   blavgwindspeed = ( ublavg^2 + vblavg^2 )^0.5
                 end if
                 ;;; at present use constant value for bl drag coefficient
                 bsratio = wstar / sqrt( cdbl*(blavgwindspeed^2) ) 
               end if
               ;;; create variable for stipple plot
               cparam = bsratio
               ; limit not needed when using pattern with ContourParameters : NCL_JACK_FORTRAN :: maxlimit2d( cparam, limitbsratio, isize,jsize )
               ; use large FillScales value instead of masking : cparam  = mask( cparam, (cparam.lt.bsmax), True )
             end if
             end if
             if ( plot_param .eq. "hwcrit" .or. plot_param .eq. "hglider" ) then
               bparam = new( (/jsize,isize/), float)
               NCL_JACK_FORTRAN :: calc_hcrit( wstar, ter, pblh, isize,jsize, bparam ) 
               if( UNITS .ne. "metric" ) then
                 bparam = 3.28084 * bparam  ; in ft   
               end if
             end if
             if ( plot_param .eq. "hglider" ) then
               eparam = bparam 
               cparam = new( (/jsize,isize/), float)
               cparam = 0.0
        ;TESTING
        print ( " HGLIDER hwcrit bparam="+min(bparam)+","+max(bparam) ) 
        print ( " HGLIDER hwcrit eparam="+min(eparam)+","+max(eparam) ) 
        print ( " HGLIDER hwcrit cparam="+min(cparam)+","+max(cparam) ) 
             end if
             if ( plot_param .eq. "dwcrit" ) then
               bparam = new( (/jsize,isize/), float)
               NCL_JACK_FORTRAN :: calc_hcrit( wstar, ter, pblh, isize,jsize, bparam ) 
               bparam = bparam - ter 
               if( UNITS .ne. "metric" ) then
                 bparam = 3.28084 * bparam  ; in ft   
               end if
             end if
           end if
           if ( plot_param .eq. "wblmaxmin" .or. plot_param .eq. "zwblmaxmin" .or. plot_param .eq. "swblmaxmin" .or. plot_param .eq. "pwblmaxmin" ) then
             ;    only looks at values at grid points using z-averaged w
             if ( .not. isvar("wa") ) then 
               wa = wrf_user_getvar(a,"wa",time) ; vertical velocity, averaged to mass levels in m/s
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             if ( plot_param .eq. "wblmaxmin" ) then
                 bparam = new( (/jsize,isize/), float)
                 NCL_JACK_FORTRAN :: calc_wblmaxmin( 0, wa,z,ter,pblh, isize,jsize,ksize, bparam ) 
             else
               if ( plot_param .eq. "zwblmaxmin" .or. plot_param .eq. "swblmaxmin" ) then
                 bparam = new( (/jsize,isize/), float)
                 ;;; calc height of wblmaxmin level
                 if ( plot_param .eq. "zwblmaxmin" ) then
                   NCL_JACK_FORTRAN :: calc_wblmaxmin( 1, wa,z,ter,pblh, isize,jsize,ksize, bparam ) 
                 else
                   NCL_JACK_FORTRAN :: calc_wblmaxmin( 2, wa,z,ter,pblh, isize,jsize,ksize, bparam ) 
                 end if
                 if( UNITS .ne. "metric" ) then
                    bparam = 3.28084 * bparam  ; in ft   
                 end if
               else
                 bparam = new( (/jsize,isize/), float)
                 ;;; calc % of bl depth of wblmaxmin level
                 NCL_JACK_FORTRAN :: calc_wblmaxmin( 3, wa,z,ter,pblh, isize,jsize,ksize, bparam ) 
               end if
             end if
           end if
           if ( plot_param .eq. "blicw" ) then
             if ( .not. isvar("qcloud") ) then 
                 qcloud = wrf_user_getvar(a,"QCLOUD",time) ; for cloud water mixing ratio in kg/kg
             end if
             if ( .not. isvar("ppert") ) then 
                 ppert = wrf_user_getvar(a,"P",time) ; for perturb press in Pa 
             end if
             if ( .not. isvar("pb") ) then 
                 pb = wrf_user_getvar(a,"PB",time) ; for base press in Pa 
             end if
             if ( .not. isvar("psfc") ) then 
                 psfc = wrf_user_getvar(a,"PSFC",time) ; for surface press in Pa 
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             ptot = ppert + pb
                 bparam = new( (/jsize,isize/), float)
                 NCL_JACK_FORTRAN :: calc_blinteg_mixratio( qcloud, ptot, psfc, z, ter, pblh, isize,jsize,ksize, bparam ) 
           end if
           if ( plot_param .eq. "aboveblicw" ) then
             if ( .not. isvar("qcloud") ) then 
                 qcloud = wrf_user_getvar(a,"QCLOUD",time) ; for cloud water mixing ratio
             end if
             if ( .not. isvar("ppert") ) then 
                 ppert = wrf_user_getvar(a,"P",time) ; for perturb press in Pa 
             end if
             if ( .not. isvar("pb") ) then 
                 pb = wrf_user_getvar(a,"PB",time) ; for base press in Pa 
             end if
             if ( .not. isvar("psfc") ) then 
                 psfc = wrf_user_getvar(a,"PSFC",time) ; for surface press in Pa 
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             ptot = ppert + pb
                 bparam = new( (/jsize,isize/), float)
                 NCL_JACK_FORTRAN :: calc_aboveblinteg_mixratio( qcloud, ptot, z, ter, pblh, isize,jsize,ksize, bparam ) 
           end if
           if ( plot_param .eq. "cwbase" .or. plot_param .eq. "blcwbase" ) then
             ;cloudbase=rh:          if ( .not. isvar("rh") ) then 
             ;cloudbase=cloudwater:
              if ( .not. isvar("qcloud") ) then 
               ;cloudbase=rh:               rh = wrf_user_getvar(a,"rh",time) ; relative humidity in percent
                 ;cloudbase=cloudwater:
                qcloud = wrf_user_getvar(a,"QCLOUD",time) ; for cloud water mixing ratio in kg/kg
             end if
             ;;; can be either agl (=1) or msl (=0) (flag also changes titles below)
               ;agl:
             laglcwbase = 1
             ;msl:          laglcwbase = 0
             ;;; set max cloudbase to allow reasonable contour intervals
             maxcwbasem = 5486.40   ; equals 6000ft 
             maxcwbaseft = floattointeger( 3.28084*maxcwbasem )
             ;cloudbase=rh:              bparam = NCL_JACK_FORTRAN :: calc_cloudbase( rh, z, ter, cwbasecriteria, maxcwbasem, laglcwbase, isize,jsize,ksize, bparam )
             ;cloudbase=cloudwater:
             bparam = new( (/jsize,isize/), float)
             if ( plot_param .eq. "cwbase" ) then
               NCL_JACK_FORTRAN :: calc_cloudbase( qcloud, z, ter, cwbasecriteria, maxcwbasem, laglcwbase, isize,jsize,ksize, bparam  )
             else
               if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
               end if
               NCL_JACK_FORTRAN :: calc_blcloudbase( qcloud, z, ter, pblh, cwbasecriteria, maxcwbasem, laglcwbase, isize,jsize,ksize, bparam  )
             end if
             ;;; fmsg = missing for this calculated parameter
             qcloud@_FillValue = fmsg
             ;;; set missing value for "no cloudbase" cases (must match amissingvalue value set in calc_cloudbase)
             ;4test: print ( "POST-SUB: MIN,MAX="+min(bparam)+","+max(bparam) )
             ;old bparam@_FillValue = -999.
             ;;; convert to pilot units (english)
             if( UNITS .ne. "metric" ) then
               bparam = 3.28084 * bparam  ; in ft   
             end if
           end if
           if ( plot_param .eq. "rhblmax" ) then
             if ( .not. isvar("rh") ) then 
               rh = wrf_user_getvar(a,"rh",time) ; relative humidity in percent
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
                 bparam = new( (/jsize,isize/), float)
                 NCL_JACK_FORTRAN :: calc_blmax( rh, z, ter, pblh, isize,jsize,ksize, bparam  )
           end if
           if ( plot_param .eq. "blcloudpct" ) then
             if ( .not. isvar("qvapor") ) then 
               qvapor  = wrf_user_getvar(a,"QVAPOR",time)   ; water vapor mixing ratio in kg/kg
             end if
             if ( .not. isvar("qcloud") ) then 
               qcloud = wrf_user_getvar(a,"QCLOUD",time) ; for cloud water mixing ratio in kg/kg
             end if
             if ( .not. isvar("tc") ) then 
               tc = wrf_user_getvar(a,"tc",time)    ; temperature (C)
             end if
             if ( .not. isvar("pmb") ) then 
               pmb   = wrf_user_getvar(a, "p",time) ; press is vertical coordinate in mb
             end if
             if ( .not. isvar("pblh") ) then 
               pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             bparam = new( (/jsize,isize/), float)
             ;mm5tograds_param:
             NCL_JACK_FORTRAN :: calc_subgrid_blcloudpct_grads( qvapor, qcloud, tc,pmb, z, ter, pblh, cwbasecriteria, isize,jsize,ksize, bparam  )
             ;gfdleta_param:  NCL_JACK_FORTRAN :: calc_subgrid_blcloudpct_gfdleta( qvapor, qcloud, tc,pmb, z, ter, pblh, gridspacing, isize,jsize,ksize, bparam  )
           end if
           if ( plot_param .eq. "zsfclcl" .or. plot_param .eq. "zsfclcldif" .or. plot_param .eq. "zsfclclmask" .or. plot_param .eq. "hglider" ) then
             ;    only looks at values at grid points using z-averaged w
             if ( .not. isvar("pmb") ) then 
               pmb = wrf_user_getvar(a,"p",time) ; pressure in mb
             end if
             if ( .not. isvar("tc") ) then 
                 tc = wrf_user_getvar(a,"tc",time) ; temp (C)
             end if
             if ( .not. isvar("td") ) then 
                 td = wrf_user_getvar(a,"td",time) ; dewpt (C)
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             bparam = new( (/jsize,isize/), float)
             NCL_JACK_FORTRAN :: calc_sfclclheight( pmb, tc, td, z, ter, pblh, isize,jsize,ksize, bparam )
             if ( plot_param .eq. "zsfclcldif" ) then
                 bparam = ( pblh + ter ) - bparam
             end if
             if ( plot_param .eq. "zsfclclmask" ) then
               cparam = ( pblh + ter ) - bparam
               ;old bparam  = mask( bparam, (cparam.ge.0), True )
               ;old delete ( cparam )
             end if
             ;;; convert to pilot units (english)
             if( UNITS .ne. "metric" ) then
                bparam = 3.28084 * bparam  ; in ft   
             end if
             if ( plot_param .eq. "hglider" ) then
               NCL_JACK_FORTRAN :: min_2darrays( eparam,cparam, bparam,1.0, isize,jsize )
        ;TESTING
        print ( " HGLIDER zsfclcl bparam="+min(bparam)+","+max(bparam) ) 
        print ( " HGLIDER zsfclcl eparam="+min(eparam)+","+max(eparam) ) 
        print ( " HGLIDER zsfclcl cparam="+min(cparam)+","+max(cparam) ) 
             end if
           end if
           if ( plot_param .eq. "zblcl" .or. plot_param .eq. "zblcldif" .or. plot_param .eq. "zblclmask" .or. plot_param .eq. "hglider" ) then
             ;    only looks at values at grid points using z-averaged w
             if ( .not. isvar("pmb") ) then 
               pmb = wrf_user_getvar(a,"p",time) ; pressure in mb
             end if
             if ( .not. isvar("tc") ) then 
                 tc = wrf_user_getvar(a,"tc",time) ; temp (C)
             end if
             if ( .not. isvar("qvapor") ) then 
               qvapor  = wrf_user_getvar(a,"QVAPOR",time)    ; water vapor mixing ratio in kg/kg
             end if
             if ( .not. isvar("pblh") ) then 
               pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             if ( .not. isvar("qvaporblavg") ) then 
               qvaporblavg = new( (/jsize,isize/), float)
               NCL_JACK_FORTRAN :: calc_blavg(qvapor,z,ter,pblh, isize,jsize,ksize, qvaporblavg ) 
             end if
        ;4TEST: do ii = 0,(isize-1)
        ;4TEST: do jj = 0,(jsize-1)
        ;4test  print ( "II,JJ,QVsfc,QVavg= "+ii+" "+jj+" "+qvapor(0,jj,ii)+" "+qvaporblavg(jj,ii) )
        ;4TEST: end do 
        ;4TEST: end do 
        ;4test  print ( "QVsfc,QVavg(NE)= "+qvapor(0,(jsize-1),(isize-1))+" "+qvaporblavg((jsize-1),(isize-1)) )
        ;4TEST: exit
             bparam = new( (/jsize,isize/), float)
             NCL_JACK_FORTRAN :: calc_blclheight( pmb, tc, qvaporblavg, z, ter, pblh, isize,jsize,ksize, bparam )
             if ( plot_param .eq. "zblcldif" ) then
               bparam = ( pblh + ter ) - bparam
             end if
             if ( plot_param .eq. "zblclmask" ) then
               cparam = ( pblh + ter ) - bparam
               ;old bparam  = mask( bparam, (cparam.ge.0), True )
               ;old delete ( cparam )
             end if
             ;;; convert to pilot units (english)
             if( UNITS .ne. "metric" ) then
               bparam = 3.28084 * bparam  ; in ft   
             end if
             if ( plot_param .eq. "hglider" ) then
               NCL_JACK_FORTRAN :: min_2darrays( eparam,cparam, bparam,2.0, isize,jsize )

        ;TESTING
        print ( " HGLIDER zblcl bparam="+min(bparam)+","+max(bparam) ) 
        print ( " HGLIDER zblcl eparam="+min(eparam)+","+max(eparam) ) 
        print ( " HGLIDER zblcl cparam="+min(cparam)+","+max(cparam) ) 
        ;TESTING
             ncount = 0
        NCL_JACK_FORTRAN :: count_2darray( cparam, 0.0,0.1, isize,jsize, ncount ) 
        print ( " HGLIDER cparam 0values = "+ncount ) 
        NCL_JACK_FORTRAN :: count_2darray( cparam, 1.0,0.1, isize,jsize, ncount ) 
        print ( " HGLIDER cparam 1values = "+ncount ) 
        NCL_JACK_FORTRAN :: count_2darray( cparam, 2.0,0.1, isize,jsize, ncount ) 
        print ( " HGLIDER cparam 2values = "+ncount ) 

             end if
           end if
           if ( plot_param .eq. "bsratio" ) then
             if ( .not. isvar("bsratio") ) then 
               if ( .not. isvar("wstar") ) then 
                 if ( .not. isvar("vhf" ) ) then
                       if ( .not. isvar("hfx") ) then 
                         hfx = wrf_user_getvar(a,"HFX",time)
                       end if        
                       if ( .not. isvar("tc") ) then 
                         tc = wrf_user_getvar(a,"tc",time) ; temp (C)
                       end if
                       ; convert latent heat flux into additional virtual temperature heat flux
                       ; 0.61*cp/L=0.61*(1006J/Kkg)/(2.502x106J/kg)=0.000245268
                       vhf = wrf_user_getvar(a,"LH",time) 
                       NCL_JACK_FORTRAN :: minlimit2d( vhf, 0.0, isize,jsize )
                       vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*vhf
                       ;old vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*wrf_user_getvar(a,"LH",time) 
                 end if
                 if ( .not. isvar("pblh") ) then 
                     pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
                 end if
                 wstar = new( (/jsize,isize/), float)
                 ;; old NCL_JACK_FORTRAN :: calc_wstar( hfx,pblh, isize,jsize,ksize, wstar )
		 NCL_JACK_FORTRAN :: calc_wstar( vhf,pblh, isize,jsize,ksize, wstar )
               end if
               if ( .not. isvar("blavgwindspeed") ) then 
                 if ( .not. isvar("ua") ) then 
                   ua = wrf_user_getvar(a,"ua",time) ; velocity, averaged to mass points in m/s
                   ;;; convert to pilot units (english)
                   if( UNITS .ne. "metric" ) then
                     ua = ua * 1.94386
                   end if
                 end if
                 if ( .not. isvar("va") ) then 
                   va = wrf_user_getvar(a,"va",time) ; velocity, averaged to mass points in m/s
                   ;;; convert to pilot units (english)
                   if( UNITS .ne. "metric" ) then
                      va = va * 1.94386
                   end if
                 end if
                 if ( .not. isvar("pblh") ) then 
                     pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
                 end if
                 pbltop = pblh + ter ;
                 if ( .not. isvar("ublavg") ) then 
                     ublavg = new( (/jsize,isize/), float)
                     NCL_JACK_FORTRAN :: calc_blavg(ua,z,ter,pblh, isize,jsize,ksize, ublavg ) 
                 end if
                 if ( .not. isvar("vblavg") ) then 
                     vblavg = new( (/jsize,isize/), float)
                     NCL_JACK_FORTRAN :: calc_blavg(va,z,ter,pblh, isize,jsize,ksize, vblavg ) 
                 end if
                 ;;; add contours of bl-avg wind speed
                 blavgwindspeed = ( ublavg^2 + vblavg^2 )^0.5
               end if
               ;;; at present use constant value for bl drag coefficient
               bsratio = wstar / sqrt( cdbl*(blavgwindspeed^2) ) 
               ;old     bparam = wstar / sqrt( cdbl*(blavgwindspeed^2) ) 
             end if
             bparam = bsratio
             ;;;  limit display of bsratio for low windspeed cases
             NCL_JACK_FORTRAN :: maxlimit2d( bparam, limitbsratio, isize,jsize )
           end if
           if ( plot_param .eq. "blwindshear" ) then
             if ( .not. isvar("ua") ) then 
               ua = wrf_user_getvar(a,"ua",time) ; velocity, averaged to mass points in m/s
               ;;; convert to pilot units (english)
               if( UNITS .ne. "metric" ) then
                  ua = ua * 1.94386
               end if
             end if
             if ( .not. isvar("va") ) then 
               va = wrf_user_getvar(a,"va",time) ; velocity, averaged to mass points in m/s
               ;;; convert to pilot units (english)
               if( UNITS .ne. "metric" ) then
                  va = va * 1.94386
               end if
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             bparam = new( (/jsize,isize/), float)
             NCL_JACK_FORTRAN :: calc_blwinddiff(ua,va,z,ter,pblh, isize,jsize,ksize, bparam ) 
           end if
           if ( plot_param .eq. "sfctemp") then
              bparam = wrf_user_getvar(a,"T2",time) - 273.16     ; sfc.temp in C
              ;;; convert to pilot units (english)
              if( UNITS .ne. "metric" .and. UNITS .ne. "celsius" ) then
                 bparam = 32. + 1.8*( bparam )    ; in farenheit
              end if
           end if
           if ( plot_param .eq. "sfcdewpt") then
              bparam = wrf_user_getvar(a,"td2",time)    ; sfc.dewpt.temp in C
              ;;; convert to pilot units (english)
              if( UNITS .ne. "metric" .and. UNITS .ne. "celsius" ) then
                 bparam = 32. + 1.8*( bparam )    ; in farenheit
              end if
           end if
           if ( plot_param .eq. "bltopvariab" ) then
             if ( .not. isvar("thetac") ) then 
               thetac = 26.85 + wrf_user_getvar(a,"T",time) ; perturb. potential temp. in degC
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             bparam = new( (/jsize,isize/), float)
             criteriondegc = 1.0
             NCL_JACK_FORTRAN :: calc_bltop_pottemp_variability( thetac, z, ter, pblh, isize,jsize,ksize, criteriondegc, bparam ) 
             ;;; convert to pilot units (english)
             if( UNITS .ne. "metric" ) then
               bparam = 3.28084 * bparam  ; in ft   
             end if
           end if
           ;;; CALC CAPE OUTSIDE FORTRAN ROUTINE SINCE HAVE NCL SKEWT FUNCTIONS AVAILABLE
           ;;; very inefficient but leave for now
           ;;; uses sfc humidity as reference, not 100mb avg
           if ( plot_param .eq. "cape" ) then
             if ( .not. isvar("pmb") ) then 
               pmb = wrf_user_getvar(a,"p",time) ; pressure in mb
             end if
             if ( .not. isvar("tc") ) then 
               tc = wrf_user_getvar(a,"tc",time) ; temp (C)
             end if
             if ( .not. isvar("td") ) then 
              td = wrf_user_getvar(a,"td",time) ; dewpt (C)
              end if
             bparam = new( (/jsize,isize/), float)
             profilep = new( (/ksize/), float)
             profiletc = new( (/ksize/), float)
             do ii = 0,(isize-1)
             do jj = 0,(jsize-1)
               ;;; following taken from skewt_func.ncl
               ;;; pmb,tc,td index is basis for calc (0=sfc)
               plcl = fmsg             ; p (hPa) Lifting Condensation Lvl (lcl)
               tlcl = fmsg             ; temperature (C) of lcl
               kzhumidref = 0
               ptlcl_skewt( pmb(kzhumidref,jj,ii),tc(kzhumidref,jj,ii),td(kzhumidref,jj,ii), plcl,tlcl )
               profilepmb = pmb(:,jj,ii)
               profiletc = tc(:,jj,ii)
               bparam(jj,ii) = cape_thermo( profilepmb,profiletc, plcl, 0 )
             end do
             end do
             delete ( profilepmb )
             delete ( profiletc )
           end if

           ;;; CALC EXPERIMENTAL1 PARAMETER 
           ;;; PRESENTLY hcrit based on criteria=175fpm
           ;;; (was cloud cover pct ala mm5tograds until 21aug2006)
           if ( plot_param .eq. "experimental1" ) then
             if ( .not. isvar("vhf") ) then 
               if ( .not. isvar("hfx") ) then 
                   hfx = wrf_user_getvar(a,"HFX",time) ; for sfc. sensible heat flux in w/m2
               end if
               if ( .not. isvar("tc") ) then 
                  tc = wrf_user_getvar(a,"tc",time) ; temp (C)
               end if
               ; convert latent heat flux into additional virtual temperature heat flux
               ; 0.61*cp/L=0.61*(1006J/Kkg)/(2.502x106J/kg)=0.000245268
                 vhf = wrf_user_getvar(a,"LH",time) 
                 NCL_JACK_FORTRAN :: minlimit2d( vhf, 0.0, isize,jsize )
                 vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*vhf
               ;old vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*wrf_user_getvar(a,"LH",time) 
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             if ( .not. isvar("wstar") ) then 
                   wstar = new( (/jsize,isize/), float)
                   NCL_JACK_FORTRAN :: calc_wstar( vhf,pblh, isize,jsize,ksize, wstar ) 
                   ;old NCL_JACK_FORTRAN :: calc_wstar( hfx,pblh, isize,jsize,ksize, wstar ) 
             end if
             bparam = new( (/jsize,isize/), float)
             NCL_JACK_FORTRAN :: calc_hlift( 175., wstar, ter, pblh, isize,jsize, bparam ) 
             if( UNITS .ne. "metric" ) then
               bparam = 3.28084 * bparam  ; in ft   
             end if
           end if
             ;grads_cloudcover if ( .not. isvar("qvapor") ) then 
             ;grads_cloudcover   qvapor  = wrf_user_getvar(a,"QVAPOR",time)   ; water vapor mixing ratio in kg/kg
             ;grads_cloudcover end if
             ;grads_cloudcover if ( .not. isvar("qcloud") ) then 
             ;grads_cloudcover   qcloud = wrf_user_getvar(a,"QCLOUD",time) ; for cloud water mixing ratio in kg/kg
             ;grads_cloudcover end if
             ;grads_cloudcover if ( .not. isvar("tc") ) then 
             ;grads_cloudcover   tc = wrf_user_getvar(a,"tc",time)    ; temperature (C)
             ;grads_cloudcover end if
             ;grads_cloudcover if ( .not. isvar("pmb") ) then 
             ;grads_cloudcover   pmb   = wrf_user_getvar(a, "p",time) ; press is vertical coordinate in mb
             ;grads_cloudcover end if
             ;grads_cloudcover if ( .not. isvar("pblh") ) then 
             ;grads_cloudcover   pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             ;grads_cloudcover end if
             ;grads_cloudcover bparam = new( (/jsize,isize/), float)
             ;grads_cloudcover ;mm5tograds_param:
             ;grads_cloudcover NCL_JACK_FORTRAN :: calc_subgrid_blcloudpct_grads( qvapor, qcloud, tc,pmb, z, ter, pblh, cwbasecriteria, isize,jsize,ksize, bparam  )

           ;;; CALC EXPERIMENTAL2 PARAMETER 
           ;;; PRESENTLY max of CLDFRA within BL
           ;;; (was gfdleta cloudcoverpct until 22apr2007)
           if ( plot_param .eq. "experimental2" ) then
             ;;; CLDFRA NOT USED FOR ANY OTHER CALC SO DISCARD AFTER USE
             if ( .not. isvar("cldfra") ) then 
               cldfra  = wrf_user_getvar(a,"CLDFRA",time)   ; cloud fraction (0-1)
             end if
             if ( .not. isvar("pblh") ) then 
                 pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             bparam = new( (/jsize,isize/), float)
             NCL_JACK_FORTRAN :: calc_blmax( cldfra, z, ter, pblh, isize,jsize,ksize, bparam  )
             ;;; convert to percent
             bparam = 100.* bparam
             delete( cldfra )
           end if
        
           ;;; PLOT AN ARBITRARY 2D/3D PARAMETER NAME
           ;;  2D paramname = "wrf_FILEparameterNAME" where FILEparamNAME is name used for NetCDF WRF output file
           ;;  3D paramname = "wrf_FILEparameterNAME_level#" where level#=0 for lowest atm (highest soil) level
           ;;     (note that 3D level is at constant model level, NOT constant MSL, AGL, or pressure)             
           if ( string_pattern_grep(plot_param,"wrf=").gt.0 ) then
           ;old if ( string_pattern_grep(plot_param,"wrf_").gt.0 ) then
             qparaminfo = "Param= "+plot_param+" Unit= ? Mult= 1"
             param_array = split_string_into_array( plot_param,"=" ) 
	     ;if (param_array(1)="TSLB")                      ; when lout=0, this is not a problem... here wrf=TSLB=0 gives 3 elements and breaks.
	     
	     ;end if
             ;old param_array = split_string_into_array( plot_param,"_" ) 
             ;4test      
	     print ( "WRF PARAMETER = "+param_array(1) )
             if(isvar("data"))then
	       delete(data)
	     end if  
             data = wrf_user_getvar(a,param_array(1),time)
             ;;force_rasterplot:    opts_bparam = True
             ;;force_rasterplot:    opts_bparam@cnFillMode = "CellFill"
             ;;force_rasterplot:    opts_bparam@cnMissingValFillColor = -1 ; transparent
             if( dimsizes(param_array) .eq. 2 ) then
               ;;; for 2D array
               bparam = data
             else
               ;;; for 3D array
               ;;; *NB* WARNING TOP-MOST LEVEL IN SOME ARRAYS HAS MISSING VALUES THERE ! eg qcloud
               ;;; 3D SIZES CHECKED SAME FOR Z,T,uz,wa,qcloud,
               datadims = dimsizes(data)
               kkdata = datadims(0)
               jjsize = datadims(1)
               iisize = datadims(2)
               if ( ismissing(iisize) ) then
                 print( "*** REQUESTED ARRAY "+plot_param+" IS NOT 3D - DIMS="+datadims )
                 exit
               else
                 level=  stringtointeger( param_array(2) )
                 bparam = data(level,:,:)               
               end if
             end if
             delete ( data )
           end if

           ;;; FOR BL CLOUD-CONDENSATION EQUIV. HEAT FLUX
           if ( plot_param .eq. "qcblhf" ) then
             ;;; if RQCBLTEN,MU,MUB not in file then will get error failure (with message) from these calls
             rqcblten = wrf_user_getvar(a,"RQCBLTEN",time) ; for d(QC)/dt
             mu = wrf_user_getvar(a,"MU",time) ; multiplier needed for d(QC)/dt
             mub = wrf_user_getvar(a,"MUB",time) ; multiplier needed for d(QC)/dt
             mu = mu + mub
             if ( .not. isvar("pblh") ) then 
               pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
             end if
             bparam = new( (/jsize,isize/), float)
             NCL_JACK_FORTRAN :: calc_qcblhf( rqcblten,mu, z, ter, pblh, isize,jsize,ksize, bparam  )
             ;;; only use RQCBLTEN,MU,MUB for this parameters so dischard after use
             delete( rqcblten )
             delete( mu )
             delete( mub )
           end if

           ;;; FOR MSL PRESSURE
           if ( plot_param .eq. "mslpress" ) then
                 ;;; this funcion reads P,PB,PH,PHB,T,QVAPOR from file so duplicates some previous reads
                 ;;; units mb for all regions
                 bparam = wrf_user_getvar(a,"slvl",time) ; for bl depth in meters
           end if

           ;old  ;;; PLOT AN ARBITRARY 2D PARAMETER NAME IN WRF OUTPUT FILE (paramname="wrf_????")
           ;old          if ( string_pattern_grep(plot_param,"wrf_").gt.0 ) then
           ;old              param_array = split_string_into_array( plot_param,"_" ) 
           ;old              bparam = wrf_user_getvar(a,param_array(1),time) 
           ;old              ;4test: print ( "WRF PARAMETER= "+param_array(1) )
           ;old          end if
;
; BL CLOUD-CONDENSATION EQUIV. HEAT FLUX
;
;function cloudsuck(rqcblten, mu, mub, z, ter, pblh, isize, jsize, ksize)
;begin
;        bparam = new( (/jsize, isize/), float)
;	NCL_JACK_FORTRAN :: calc_qcblhf( rqcblten,mu, z, ter, pblh, isize,jsize,ksize, bparam  )
;	return(bparam)
;end
			
			
