print("sequence ------------------  rasp.wind_calc.ncl  "+REGION  +"     "+plot_param+"-----------------------")
            ;;; DO RASP WIND PARAMETER CALCULATIONS
             ;;; setup bl avg wind case
             if ( plot_param .eq. "blwind" ) then
                ;    only looks at values at grid points using z-averaged w
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
                ;old z = wrf_user_getvar(a,"Z",time) ; grid point height in meters
                if ( .not. isvar("pblh") ) then 
                    pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
                end if
                pbltop = pblh + ter ;
                ;;; calc bl avg winds for plotting  calc_blavg(ua,z,ter,pblh, nx,ny,nz, ublavg ) tjo in GM
                if ( .not. isvar("ublavg") ) then 
                     ublavg = new( (/jsize,isize/), float)
                     NCL_JACK_FORTRAN :: calc_blavg(ua,z,ter,pblh, isize,jsize,ksize, ublavg ) 
                end if
                if ( .not. isvar("vblavg") ) then 
                     vblavg = new( (/jsize,isize/), float)
                     NCL_JACK_FORTRAN :: calc_blavg(va,z,ter,pblh, isize,jsize,ksize, vblavg ) 
                end if
                uplot = ublavg
                vplot = vblavg
                WindTitle = "Vertically Averaged BL Wind"
                ;old qparamname = "blwindspeed"
                ;old qdatafile = "blwind.data"
                ;old  qparaminfo = "Param= "+plot_param+" Unit= m/s Mult= 1"
             end if
          
             ;;; setup sfc wind case
             if ( plot_param .eq. "sfcwind" ) then
                ;    only looks at values at grid points using z-averaged w
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
                uplot = ua(1,:,:) 
                vplot = va(1,:,:) 
                WindTitle = "Above Trees Winds Level1"
                ;old qparamname = "sfcwindspeed"
                ;old qdatafile = "sfcwind.data"
             end if

             ;;; setup bltop wind case
             if ( plot_param .eq. "bltopwind" ) then
                ;    only looks at values at grid points using z-averaged w
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
                ;old z = wrf_user_getvar(a,"Z",time) ; grid point height in meters
                if ( .not. isvar("pblh") ) then 
                    pblh = wrf_user_getvar(a,"PBLH",time) ; for bl depth in meters
                end if
                pbltop = pblh + ter ;
                ;;; calc bltop winds for plotting
                if ( .not. isvar("ubltop") ) then 
                     ubltop = new( (/jsize,isize/), float)
                     vbltop = new( (/jsize,isize/), float)
                     NCL_JACK_FORTRAN :: calc_bltopwind(ua,va,z,ter,pblh, isize,jsize,ksize, ubltop,vbltop ) 
                end if
                uplot = ubltop
                vplot = vbltop
                WindTitle = "BL Top Wind"
                ;old qparamname = "bltopwindspeed"
                ;old qdatafile = "bltopwind.data"
             end if

             ;;; setup ten meter wind case
             if ( plot_param .eq. "tenmwind" ) then
                ;    only looks at values at grid points using U10 and V10
                if ( .not. isvar("u10") ) then 
                  u10 = wrf_user_getvar(a,"U10",time) ; velocity, averaged to mass points in m/s
                  ;;; convert to pilot units (english)
                  if( UNITS .ne. "metric" ) then
                     u10 = u10 * 1.94386
                  end if
                end if
                if ( .not. isvar("v10") ) then 
                  v10 = wrf_user_getvar(a,"V10",time) ; velocity, averaged to mass points in m/s
                  ;;; convert to pilot units (english)
                  if( UNITS .ne. "metric" ) then
                     v10 = v10 * 1.94386
                  end if
                end if
		;printVarSummary(u10)
		;printVarSummary(v10)
                uplot = u10(:,:) 
                vplot = v10(:,:) 
                WindTitle = "10 Meter Winds"
             end if

             ;;; setup sfc wind0 level case
             if ( plot_param .eq. "sfcwind0" ) then
                ;    only looks at values at grid points using z-averaged w
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
                uplot = ua(0,:,:) 
                vplot = va(0,:,:) 
                WindTitle = "Lowest Available winds level0 2m"
             end if


             ;;; setup second pressure level  wind case
             if ( plot_param .eq. "sfcwind2" ) then
                ;    only looks at values at grid points using z-averaged w
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
                uplot = ua(2,:,:) 
                vplot = va(2,:,:) 
                WindTitle = "Winds level2 above trees "
                ;old qparamname = "sfcwindspeed"
                ;old qdatafile = "sfcwind.data"
             end if


