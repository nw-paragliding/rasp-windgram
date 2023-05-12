;; tjo add load link to rasp.site_load.bparam_resources.ncl at end of this.
;;; SET CONTOUR PLOT bparam CONTOUR RANGE
;tjtest print("sequence ------------------  rasp.bparam_resources.ncl   ---------------------------------------")
        opts_bparam = True
        opts_bparam@MainTitle = plot_param
        ;old ;;; set default contours levels here - auto-scales if opts_bparam@contourparameters _not_ set
        ;old opts_bparam@ContourParameters = (/ 0., 800., 50. /)
        ;;; SET PARAMETER-SPECIFIC OPTIONS

if( plot_param .eq. "HGT" ) then
          ;onceonly_background: cannot alter terrain options for individual plot
          ;onceonly_background- if ( isvar("opts_ter@NoTitles") ) then 
          ;onceonly_background-   delete( opts_ter@NoTitles )
          ;onceonly_background- end if
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             ;onceonly_background- opts_ter@MainTitle = "Terrain Height ~I~[ft]~P~"
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             ;onceonly_background- opts_ter@MainTitle = "Terrain Height ~I~[m]~P~"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          opts_ter@TimeLabel = " "
          ;unused: opts_bparam@ContourParameters = (/ 0., 600., 50. /)
        end if

if( plot_param .eq. "ter" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Terrain Height"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 800., 50. /)
        end if

if( plot_param .eq. "dbl" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Depth"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
         else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 800., 50. /)
        end if

if( plot_param .eq. "sfcshf" ) then
           opts_bparam = True
          opts_bparam@MainTitle = "Sfc. Heating"
          opts_bparam@UnitLabel = "[W/m~S~2~N~]"
          ;unused: opts_bparam@ContourParameters = (/ -100., 400., 50. /)
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= W/m2 Mult= 1"
        end if
        if( plot_param .eq. "vhf" ) then
           opts_bparam = True
          opts_bparam@MainTitle = "Sfc. Virtual Heat Flux"
          opts_bparam@UnitLabel = "[W/m~S~2~N~]"
          ;unused: opts_bparam@ContourParameters = (/ -100., 400., 50. /)
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= W/m2 Mult= 1"
        end if

if( plot_param .eq. "sfcsun" ) then
           opts_bparam = True
          opts_bparam@MainTitle = "Sfc. Solar Radiation"
          opts_bparam@UnitLabel = "[W/m~S~2~N~]"
          ;unused: opts_bparam@ContourParameters = (/ 0., 600., 50. /)
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= W/m2 Mult= 1"
        end if
        if( plot_param .eq. "sfcsunpct" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Normalized Sfc. Solar Radiation"
          opts_bparam@UnitLabel = "[%]"
          ;unused: opts_bparam@ContourParameters = (/ 0., 600., 50. /)
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= % Mult= 1"
        end if


if ( plot_param .eq. "wstar" .or. plot_param .eq. "wstar_bsratio" .or. plot_param .eq. "wfpm" .or. plot_param .eq. "wfpm_woustar" ) then
        ;old if( plot_param .eq. "wstar" .or. plot_param .eq. "wstar_bsratio" ) then
          ;;; set composite type
          if ( plot_param .eq. "wstar_bsratio" .or. plot_param .eq. "wfpm_woustar" ) then
            ;;;  lcompositetype = 2 for cparam stipple
            lcompositetype = 2
          end if
          opts_bparam = True
          opts_bparam@MainTitle = "Thermal Updraft Velocity ~I~( W* )~P~  200fpm~F34;~F21~1m/s"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft/min]"
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= ft/min Mult= 1"
             if(  LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Thermal Updraft Velocity" )
               kfixedcolor = 1
               ; use blip params
               opts_bparam@ContourParameters = (/ 0., 1100., 50. /)
               ;old opts_bparam@ContourParameters = (/ 0., 1200., 100. /)
             else
               ; use blip params
               opts_bparam@ContourParameters = (/ 0.,0., 50. /)
             end if
          else
             opts_bparam@UnitLabel = "[cm/s]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= cm/s Mult= 1"
             if(  LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Thermal Updraft Velocity" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ 0., 6., 0.25 /)
             end if
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 100., 10. /)

if ( plot_param .eq. "wstar_bsratio" .or. plot_param .eq. "wfpm_woustar" ) then
          ;old if ( plot_param .eq. "wstar_bsratio" ) then
            ;4test do iii=0,(isize-1)
            ;4test do jjj=0,(jsize-1)
            ;4test    cparam(jjj,iii) = cparam(jjj,iii) + 5.0
            ;4test    if( cparam(jjj,iii) .gt. 6.5 ) then
            ;4test      cparam(jjj,iii) = 6.5 
            ;4test    end if
            ;4test end do
            ;4test end do
            ;4test cmax=max(cparam)
            ;4test cmin=min(cparam)
            ;4test print ( ">>> CMIN,CMAX= "+cmin+" "+cmax )
            opts_cparam = True
            opts_cparam@cnLinesOn = False
            opts_cparam@cnLineLabelsOn = False
            opts_cparam@cnMonoFillScale = False
            opts_cparam@cnMonoFillPattern = True
            opts_cparam@cnMonoFillColor = True     ;; allows dots everywhere the color is not a color but a pattern.
            opts_cparam@MainTitle = ""
            opts_cparam@TimeLabel =  ""
            opts_cparam@LevelLabel = ""
            opts_cparam@UnitLabel = ""
            opts_cparam@pmLabelBarDisplayMode = "NoCreate"  ; "Never" also seems to work
            ;;; set pattern
             opts_cparam@cnFillPattern = 17  ; 17=stipple
             ;old opts_cparam@cnFillPattern = 14  ; 14=triple-hash
             ;;; use minimum stipple size - seems to work best after raster conversion
             opts_cparam@cnFillDotSizeF = 0.0000 ; used only for stipple pattern 
             ;old  opts_cparam@cnFillDotSizeF = 0.0005 ; used only for stipple pattern 
             ;older (gives "interference pattern" due to raster conversion)  opts_cparam@cnFillDotSizeF = 0.002 ; used only for stipple pattern 
            ;;; set pattern color
             opts_cparam@cnFillColor = "black"
             ;unused opts_cparam@cnFillColor = "azure4" 
             ;unused opts_cparam@cnFillColor = "bisque4"   ; reddish
             ;unused opts_cparam@cnFillColor = "burleywood4" ; black
             ;unused opts_cparam@cnFillColor = "goldenrod4" ; green
             ;unused opts_cparam@cnFillColor = "tan4" ; reddish
             ;unused opts_cparam@cnFillColor = "tan4" ; reddish
             ;unused opts_cparam@cnFillColor = "tan3" ; light-tan
             ;unused opts_cparam@cnFillColor = "sienna4" ; dark brown-red
             ;unused opts_cparam@cnFillColor = "peru" ; light tan
             ;bad opts_cparam@cnFillColor = "gray60"  ; is green!
            ;;; mask, levels, & title info should all agree !
            ;2level-stipple:
            composite_title = "B/S Ratio Stipple:  Dense= 0 to 4  Sparse= 4 to 7"
            ;alt-2level-stipple: composite_title = "B/S Ratio Stipple:  Dense= 0 to 4  Sparse= 4 to 8"
            ;3level_stipple:  composite_title = "B/S Ratio Stipple:  Densest= 0 to 3  Sparsest= 6 to 9"
            ;old composite_title = "B/S Ratio Stipple: Heavy=0-4  Light=4-7"
            ;;; set stipple pattern levels
            ;2level-stipple: 
            opts_cparam@ContourParameters = (/ 0., 7.0, 4. /)
            ;alt-2level-stipple:            opts_cparam@ContourParameters = (/ 0., 8.0, 4. /)
            ;3level_stipple: opts_cparam@ContourParameters = (/ 0., 9.0, 3. /)
            ;;; set pattern stipple scale - use large FillScales value instead of masking higher values
            ;;; size of FillScales should be one more than number of contour _levels_ set by ContourParameters   
            ;;;    (note that first value not actually used)
            ;2level-stipple:
            opts_cparam@cnFillScales = (/ 0.5, 0.5, 1., 100. /)
            ;3level_stipple: opts_cparam@cnFillScales = (/ 0.3, 0.3, 0.7, 1., 100. /)
            ;;; kludge to get around missing stipples when no "contour" line produced by value range
            ;;;    produce a contour line by using interval of 1/2 max but then stipple two levels not one
            cmin = min(cparam)
            cmax = max(cparam)
            ;4test: print ( " STIPPLE CMIN,CMAX="+cmin+","+cmax ) 
            ;;; pattern fill problems if less than 1 contour interval so force at least one contour interval for that special case
            ;2level-stipple:
            if ( cmax .le. 4.0 ) then             
              opts_cparam@ContourParameters = (/ cmin, cmax, 0.5*(cmax-cmin) /)
              opts_cparam@cnFillScales = (/ 0.5, 0.5, 0.5, 0.5 /)
            end if 
            ;old-notneeded  if ( cmin .gt. 4.0 .and. cmax .le. 7.0 ) then             
            ;old-notneeded    opts_cparam@ContourParameters = (/ cmin, cmax, 0.5*(cmax-cmin) /)
            ;old-notneeded    opts_cparam@cnFillScales = (/ 0.5, 1.0, 1.0, 100. /)
            ;old-notneeded  end if 
            ;3level_stipple: if ( cmax .le. 3.0 ) then             
            ;3level_stipple:   opts_cparam@ContourParameters = (/ cmin, cmax, 0.5*(cmax-cmin) /)
            ;3level_stipple:   opts_cparam@cnFillScales = (/ 0.3, 0.3, 0.3, 0.3, 0.3 /)
            ;3level_stipple: end if 
            ;unused          opts_cparam@cnMinLevelValF = 4
            ;unused          opts_cparam@cnMaxLevelValF = 7
            qparaminfo = "Param= "+plot_param+" Unit= ft/min Mult= 1"
          end if
        end if

if ( plot_param .eq. "hglider" ) then
          ;;; switch eparam to bparam
          bparam = eparam
          delete ( eparam )
            ;;; USE  _RASTER_ MASKING (since contour masking messes up contouring of adjacent locations)
            opts_bparam@cnFillMode = "CellFill"
            opts_bparam@cnMissingValFillColor = -1 ; transparent
          ;;;  lcompositetype = 2 for cparam stipple
          lcompositetype = 2
          opts_bparam = True
          opts_bparam@MainTitle = "Thermalling Height"
          composite_title = "Stipple indicates cloudbase-limited"
          ;old composite_title = "CloudStipple:  Sparse= Cumulus  Dense= OvercastDevelopment"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
             if( LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Thermalling Height" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ 0., 22000., 1000. /)
             else
               opts_bparam@ContourParameters = (/ 0.,0., 500. /)
             end if 
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
             if(  LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Thermalling Height" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ 0., 7000., 500. /)
             end if
          end if
            opts_cparam = True
            opts_cparam@cnLinesOn = False
            opts_cparam@cnLineLabelsOn = False
            opts_cparam@cnMonoFillScale = False
            opts_cparam@cnMonoFillPattern = True
            opts_cparam@cnMonoFillColor = True
            opts_cparam@MainTitle = ""
            opts_cparam@TimeLabel =  ""
            opts_cparam@LevelLabel = ""
            opts_cparam@UnitLabel = ""
            opts_cparam@pmLabelBarDisplayMode = "NoCreate"  ; "Never" also seems to work
            ;;; set pattern
             opts_cparam@cnFillPattern = 17  ; 17=stipple
             ;;; use minimum stipple size - seems to work best after raster conversion
             opts_cparam@cnFillDotSizeF = 0.0000 ; used only for stipple pattern 
            ;;; set pattern color
             opts_cparam@cnFillColor = "black"
            ;;; mask, levels, & title info should all agree !
            ;;; set stipple pattern levels
            opts_cparam@ContourParameters = (/ 0.5, 1.5, 1. /)
            ;;; set pattern stipple scale - use large FillScales value instead of masking higher values
            ;;; size of FillScales should be one more than number of contour _levels_ set by ContourParameters   
            ;;;    (note that first value not actually used)
            opts_cparam@cnFillScales = (/ 100., 1., 0.5 /)
            ;;; kludge to get around missing stipples when no "contour" line produced by value range
            ;;;    produce a contour line by using interval of 1/2 max but then stipple two levels not one
            cmin = min(cparam)
            cmax = max(cparam)
            ;;; pattern fill problems if less than 1 contour interval so force at least one contour interval for that special case
            if ( cmax .lt. 1.0 ) then             
              opts_cparam@ContourParameters = (/ cmin, cmax, 0.5*(cmax-cmin) /)
              opts_cparam@cnFillScales = (/ 100., 100., 100. /)
            end if 
;TESTING - THIS WAS *REQUIRED* FOR RUC/NAM PROCESSING (orelse get UIV) - but moved ldatafmt=0 to main routine
;TESTING-          ldatafmt = 0
        end if

if( plot_param .eq. "hbl" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Height of BL Top"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             opts_bparam@UnitLabel = "[m]"
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
        end if

if( plot_param .eq. "hwcrit" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Height of Critical Updraft Strength ~I~(Hcrit)~P~"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
        end if

if( plot_param .eq. "dwcrit" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Depth of Critical Updraft Strength ~I~(AGL Hcrit)~P~"
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
        end if

if( plot_param .eq. "wblmaxmin" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Max. Up/Down Motion -- Convergence"
          opts_bparam@UnitLabel = "[cm/s]"
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= cm/s Mult= 1"
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if( plot_param .eq. "zwblmaxmin" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "MSL Height of maxmin Wbl"
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; *NB* BELOW PREVENTS ENORMOUSLY LONG PLOT TIME FOR THIS PARAMETER DUE TO NOISY FIELD
             opts_bparam@ContourParameters = (/ 0.,0., 1000. /)
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; *NB* BELOW PREVENTS ENORMOUSLY LONG PLOT TIME FOR THIS PARAMETER DUE TO NOISY FIELD
             opts_bparam@ContourParameters = (/ 0.,0., 250. /)
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
        end if

if( plot_param .eq. "swblmaxmin" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "AGL Height of maxmin Wbl"
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; *NB* BELOW PREVENTS ENORMOUSLY LONG PLOT TIME FOR THIS PARAMETER DUE TO NOISY FIELD
             opts_bparam@ContourParameters = (/ 0.,0., 1000. /)
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; *NB* BELOW PREVENTS ENORMOUSLY LONG PLOT TIME FOR THIS PARAMETER DUE TO NOISY FIELD
             opts_bparam@ContourParameters = (/ 0.,0., 250. /)
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
        end if

if( plot_param .eq. "pwblmaxmin" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Depth of maxmin Wbl"
          opts_bparam@UnitLabel = "[% of BL Depth]"
          ; *NB* BELOW PREVENTS ERROR "fatal:ContourPlotPreDraw: Workspace reallocation would exceed maximum size 16777216"
          opts_bparam@ContourParameters = (/ 0., 100., 10. /)
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= % Mult= 1"
        end if

if ( plot_param .eq. "blicw" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Integrated Cloud Water"
          opts_bparam@UnitLabel = "[g]"
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= g Mult= 1"
        end if

if ( plot_param .eq. "aboveblicw" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Above-BL Integrated Cloud Water"
          opts_bparam@UnitLabel = "[g]"
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= g Mult= 1"
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if ( plot_param .eq. "cwbase" .or. plot_param .eq. "blcwbase" ) then
          opts_bparam = True
          if( laglcwbase .eq. 1 ) then
            msloragl = "AGL" 
          else
            msloragl = "MSL" 
          end if

if ( plot_param .eq. "cwbase" ) then
            ;cloudbase=rh:            opts_bparam@MainTitle = "Cloud Base ["+msloragl+"] ~I~(RH>"+cwbasecriteria+")~P~"
            ;cloudbase=cloudwater:
            opts_bparam@MainTitle = "Explicit Cloud Base ["+msloragl+"] ~I~(CloudWater>"+cwbasecriteria+")~P~"
          else
            opts_bparam@MainTitle = "BL Explicit Cloud Base ["+msloragl+"] ~I~(CloudWater>"+cwbasecriteria+")~P~"
          end if
          ;;; convert to pilot units (english)
          if( UNITS .ne. "metric" ) then
            opts_bparam@UnitLabel = "[ft "+msloragl+" - max="+maxcwbaseft+"]"
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= ft"+msloragl+" Mult= 1"
          else
             opts_bparam@UnitLabel = "[m"+msloragl+" - max="+maxcwbaseft+"]"
            ;;; info for data file write
            qparaminfo = "Param= "+plot_param+" Unit= m"+msloragl+" Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if ( plot_param .eq. "rhblmax" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Max. Relative Humidity"
          opts_bparam@UnitLabel = "[%]"
          ;unused: opts_bparam@ContourParameters = (/ 0., 100., 10. /)
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= % Mult= 1"
        end if

if ( plot_param .eq. "blcloudpct" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Cloud Cover"
          opts_bparam@UnitLabel = "[%]"
          ;unused: opts_bparam@ContourParameters = (/ 0., 100., 10. /)
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= % Mult= 1"
        end if

if( plot_param .eq. "zsfclcl" .or. plot_param .eq. "zsfclclmask" .or. plot_param .eq. "zsfclclft" .or. plot_param .eq. "zsfclcl_zsfclcldif" .or. plot_param .eq. "zsfclclft_zsfclcldifft" ) then
          ;;;  lcompositetype = 1 for mask of bparam by cparam>0
          if( plot_param .eq. "zsfclclmask" .or. plot_param .eq. "zsfclcl_zsfclcldif" .or. plot_param .eq. "zsfclclft_zsfclcldifft" ) then
            lcompositetype =  1 
          end if
          opts_bparam = True
          if( plot_param .eq. "zsfclcl" .or. plot_param .eq. "zsfclclft" ) then
            opts_bparam@MainTitle = "Cu Cloudbase ~I~(Sfc. LCL)~P~"
          else
            opts_bparam@MainTitle = "Cu Cloudbase ~I~where Cu Potential > 0~P~"
          end if
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
             if( LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Cu Cloudbase" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ 0., 22000., 1000. /)
             else
               opts_bparam@ContourParameters = (/ 0.,0., 500. /)
             end if 
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
             if( LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Cu Cloudbase" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ 0., 7000., 500. /)
             end if
          end if
        end if
        if( plot_param .eq. "zsfclcldif" .or. plot_param .eq. "zsfclcldifft" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Cu Potential"
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
             if( LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for Cu Potential" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ -5000., 5000., 1000. /)  ;original site-load overrides
             else
               opts_bparam@ContourParameters = (/ 0.,0., 500. /)
             end if 
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if
        if( plot_param .eq. "zblcl" .or. plot_param .eq. "zblclmask" .or. plot_param .eq. "zblclft" .or. plot_param .eq. "zblcl_zblcldif" .or. plot_param .eq. "zblclft_zblcldifft" ) then
          ;;;  lcompositetype = 1 for mask of bparam by cparam>0
          if( plot_param .eq. "zblclmask" .or. plot_param .eq. "zblcl_zblcldif" .or. plot_param .eq. "zblclft_zblcldifft" ) then
            lcompositetype =  1 
          end if
          opts_bparam = True
          if( plot_param .eq. "zblcl" .or. plot_param .eq. "zblclft" ) then
            opts_bparam@MainTitle = "OvercastDevelopment Cloudbase ~I~(BL CL)~P~"
          else
            opts_bparam@MainTitle = "OD Cloudbase ~I~where OD Potential > 0~P~"
          end if
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
             if( LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for OD Cloudbase" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ 0., 22000., 1000. /)
             else
               opts_bparam@ContourParameters = (/ 0.,0., 500. /)
             end if 
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if
        if( plot_param .eq. "zblcldif" .or. plot_param .eq. "zblcldifft" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "OvercastDevelopment Potential"
          if( UNITS .ne. "metric" ) then
             opts_bparam@UnitLabel = "[ft]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
             if( LFIXEDCOLOR .eq. 1 ) then
               print( "    using FIXED COLOR for OD Potential" )
               kfixedcolor = 1
               opts_bparam@ContourParameters = (/ -5000., 5000., 1000. /)
             else
               opts_bparam@ContourParameters = (/ 0.,0., 500. /)
             end if 
          else
             opts_bparam@UnitLabel = "[m]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if( plot_param .eq. "bsratio" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Buoyancy/Shear Ratio"
          ;;;  limit display of bsratio for low windspeed cases
          opts_bparam@UnitLabel = "Truncated at "+limitbsratio
          ;unused: opts_bparam@ContourParameters = (/ 0., 100., 10. /)
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= nondim Mult= 1"
        end if

if( plot_param .eq. "blwindshear" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Vertical Wind Shear"
          if( UNITS .ne. "metric" ) then
            opts_bparam@UnitLabel = "[kt]"
            qparaminfo = "Param= "+plot_param+" Unit= kt Mult= 1"
          else
            opts_bparam@UnitLabel = "[m/s]"
            qparaminfo = "Param= "+plot_param+" Unit= m/s Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if( plot_param .eq. "sfctemp" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Surface Temperature ~I~(2m AGL)~P~"
          if( UNITS .ne. "metric" .and. UNITS .ne. "celsius" ) then
             opts_bparam@UnitLabel = "[F]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= F Mult= 1"
          else
             opts_bparam@UnitLabel = "[C]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= C Mult= 1"
          end if
          ;;; set alternate format for data file write
          ldatafmt = 1
          ;unused: opts_bparam@ContourParameters = (/ 0., 38., 2. /)

;;; VARY FIXED SFCTEMP WITH SEASON
if( LFIXEDCOLOR .eq. 1 ) then
  print( "    using FIXED COLOR for Sfc temp" )
  kfixedcolor = 1
  if( UNITS .ne. "metric" .and. UNITS .ne. "celsius" ) then
    if(    string_pattern_grep(qdatimeinfo,"Mar").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Apr").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"May").gt.0 ) then
      ;;; SPRING VALUE
      opts_bparam@ContourParameters = (/ 40., 80., 2. /)
    else
    if(    string_pattern_grep(qdatimeinfo,"Jun").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Jul").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Aug").gt.0 ) then
      ;;; SUMMER VALUE
      opts_bparam@ContourParameters = (/ 60., 100., 2. /)
    else
    if(    string_pattern_grep(qdatimeinfo,"Sep").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Oct").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Nov").gt.0 ) then
      ;;; FALL VALUE
      opts_bparam@ContourParameters = (/ 40., 80., 2. /)
    else
      ;;; WINTER VALUE
      opts_bparam@ContourParameters = (/ 20., 60., 2. /)
    end if
    end if
    end if
  else
    if(    string_pattern_grep(qdatimeinfo,"Mar").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Apr").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"May").gt.0 ) then
      ;;; SPRING VALUE
      opts_bparam@ContourParameters = (/  4., 26., 1. /)
    else
    if(    string_pattern_grep(qdatimeinfo,"Jun").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Jul").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Aug").gt.0 ) then
      ;;; SUMMER VALUE
      opts_bparam@ContourParameters = (/ 16.,  38., 1. /)
    else
    if(    string_pattern_grep(qdatimeinfo,"Sep").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Oct").gt.0 \
    .or. string_pattern_grep(qdatimeinfo,"Nov").gt.0 ) then
      ;;; FALL VALUE
      opts_bparam@ContourParameters = (/  4., 26., 1. /)
    else
      ;;; WINTER VALUE
      opts_bparam@ContourParameters = (/ -6., 16., 1. /)
    end if
    end if
    end if
  end if
end if

        end if

if( plot_param .eq. "sfcdewpt" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Surface Dew Point Temperature ~I~(2m AGL)~P~"
          if( UNITS .ne. "metric" .and. UNITS .ne. "celsius" ) then
             opts_bparam@UnitLabel = "[F]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= F Mult= 1"
          else
             opts_bparam@UnitLabel = "[C]"
             ;;; info for data file write
             qparaminfo = "Param= "+plot_param+" Unit= C Mult= 1"
          end if
          ;;; set alternate format for data file write
          ldatafmt = 1
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if( plot_param .eq. "bltopvariab" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Top Uncertainty/Variability ~I~(for +1degC)~P~"
          ;old opts_bparam@MainTitle = "BL Top Uncertainty/Variability (+1degC)"
          ;old opts_bparam@MainTitle = "BL Top Uncertainty/Variability (+4degF)"
          if( UNITS .ne. "metric" ) then
            opts_bparam@UnitLabel = "[ft]"
            qparaminfo = "Param= "+plot_param+" Unit= ft Mult= 1"
          else
            opts_bparam@UnitLabel = "[m]"
            qparaminfo = "Param= "+plot_param+" Unit= m Mult= 1"
          end if
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

if( plot_param .eq. "cape" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "CAPE TS poten. 300-1000=weak, 1000-2500=moderate, 2500-5300=strong"
          opts_bparam@UnitLabel = "[J/kg]"
          qparaminfo = "Param= "+plot_param+" Unit= J/kg Mult= 1"
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

        ;;; FOR BL CLOUD CONDENSATION EQUIV. HEAT FLUX

if( plot_param .eq. "qcblhf" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "BL Cloud Heating"
          opts_bparam@UnitLabel = "[W/m~S~2~N~]"
          ;unused: opts_bparam@ContourParameters = (/ -100., 400., 50. /)
          ;;; info for data file write
          qparaminfo = "Param= "+plot_param+" Unit= W/m2 Mult= 1"
        end if

        ;;; FOR LO-MID-HI-LEVEL CLOUD FRACTION

if( plot_param .eq. "wrf=CFRACL" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Low-Level Grid-Scale Cloudiness"
          opts_bparam@UnitLabel = ""
          opts_bparam@ContourParameters = (/ 0.1, 0.9, 0.1 /)
          ;;; info for data file write
          qparaminfo = ""
        end if

if( plot_param .eq. "wrf=CFRACM" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "Mid-Level Grid-Scale Cloudiness"
          opts_bparam@UnitLabel = ""
          opts_bparam@ContourParameters = (/ 0.1, 0.9, 0.1 /)
          ;unused: opts_bparam@ContourParameters = (/ -100., 400., 50. /)
          ;;; info for data file write
          qparaminfo = ""
        end if

if( plot_param .eq. "wrf=CFRACH" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "High-Level Grid-Scale Cloudiness"
          opts_bparam@UnitLabel = ""
          opts_bparam@ContourParameters = (/ 0.1, 0.9, 0.1 /)
          ;;; info for data file write
          qparaminfo = ""
        end if

          ;; MSL PRESSURE

if( plot_param .eq. "mslpress" ) then
           opts_bparam = True
           opts_bparam@MainTitle = "Mean Sea Level Pressure"
           ;;; units mb for all regions
           opts_bparam@UnitLabel = "mb"
           opts_bparam@ContourParameters = (/ 0., 0., 2. /)
           ;;; info for data file write
           qparaminfo = ""
         end if
	 
        ;;; FOR EXPERIMENTAL1 PARAMETER 

if( plot_param .eq. "experimental1" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "EXPERIMENTAL1"
          opts_bparam@UnitLabel = "[?units?]"
;;; PRESENTLY experimental1 PARAMETER IS Hlift for 175fpm criteria
          opts_bparam@MainTitle = "H_lift for 175fpm sinkrate"
          if( UNITS .ne. "metric" ) then
            opts_bparam@UnitLabel = "[ft]"
          else
            opts_bparam@UnitLabel = "[m]"
          end if
        ;grads_cloudcover opts_bparam@MainTitle = "BL Cloud Cover - grads"
        ;grads_cloudcover opts_bparam@UnitLabel = "[%]"
          qparaminfo = "Param= "+plot_param+" Unit= ? Mult= 1"
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

        ;;; FOR EXPERIMENTAL2 PARAMETER 

if( plot_param .eq. "experimental2" ) then
          opts_bparam = True
          opts_bparam@MainTitle = "EXPERIMENTAL2"
          opts_bparam@UnitLabel = "[?units?]"
;;; PRESENTLY experimental2 PARAMETER IS max CLDFRA
          opts_bparam@MainTitle = "BL Cloud Cover = CLDFRA max"
          opts_bparam@UnitLabel = "[%]"
          qparaminfo = "Param= "+plot_param+" Unit= ? Mult= 1"
          ;unused: opts_bparam@ContourParameters = (/ 0., 10., 10. /)
        end if

        ;        Plotting options for bparam
        if ( plot_param .ne. "ter" ) then
            ;single_time_file:
          opts_bparam@TimeLabel = times(it)+"Z"
          ;multiple_time_file: opts_bparam@TimeLabel = times(it) + " = " + time_save + " + " + hours + " h"
          ;;; IF NON-INTERACTIVE RUN, USE ID AS TITLE
          if ( .not. ismissing(ENV_NCL_ID) .and. ENV_NCL_ID .ne. ""  ) then
            opts_bparam@TimeLabel = trim_string( ENV_NCL_ID )
          end if
        else
          opts_bparam@TimeLabel = " "
        end if


;;----------------------------------------------------------------------------------------------------------;;
;;; SET OPTIONS VALID FOR ALL PARAMETERS
        ;old opts_bparam@UnitLabel = "BL[m]"
        ;overwrites_long_time_label
        opts_bparam@LineThickness = 0.5
        opts_bparam@cnInfoLabelOn = False
        opts_bparam@cnLineLabelsOn = False

        ;;; FOR LABEL BAR (COLORBAR)

        opts_bparam@lbAutoManage = False
        ;old-unneeded opts_bparam@lbLabelStrings = (/ 0., 200., 400., 600., 800. /)
        opts_bparam@lbLabelFont = "helvetica" ; controls font of colorbar numbers
        opts_bparam@lbLabelFontHeightF     = 0.015
        opts_bparam@lbLabelOffsetF     = 0.05  ; move numbers close to colorbar
        opts_bparam@lbTitleFont = "helvetica" ; controls font of colorbar title
        ;preAug2006(smaller_plotheight) opts_bparam@lbTitleFontHeightF     = 0.015
        ;old-title_above: opts_bparam@lbTitleOffsetF     = -0.5  ; move title lower, closer to colorbar
        ;old-title_above: opts_bparam@lbTopMarginF     = -0.2  ; move colorbar and its title upward, closer to plot - but also expands height of colorbar !
        ;old-title_above: opts_bparam@lbBottomMarginF = 0.4

        ;preAug2006(smaller_plotheight) opts_bparam@lbTopMarginF     = 0.0 ; move colorbar upward, closer to map
        ;preAug2006(smaller_plotheight) opts_bparam@lbBottomMargin F = 0.0
        ;preAug2006(smaller_plotheight) opts_bparam@lbTitleExtentF     = 0.6  ; extent of title region from bottom perimeter
        ;preAug2006(smaller_plotheight) opts_bparam@lbTitleOffsetF     = 0.0  ; buffer between title and colorbar
        ;no_effect! (so put into wrf_plot.ncl wrf_new_fill_contour routine) :  opts_bparam@pmLabelBarOrthogonalPosF = 0.010  ; move lb up vertically as much as possible, leaving space for terrain contour info print
        ;bad           lbBoxMinorExtentF = 0.6  ; cant see any effect 
        ;;; LABELBAR OPTIONS TO ALLOW LARGER VERTICAL PLOT - put units & fixed flag to side of colorbar
        ;;; specify label bar height,width to conform to my esthetics
        opts_bparam@pmLabelBarHeightF  = 0.08 ; 
        opts_bparam@pmLabelBarWidthF  = 0.80 ; 
        ;old opts_bparam@pmLabelBarWidthF  = 0.78 ; 
        ;;; eliminate label title (units string)
        opts_bparam@lbTitleOn = False
        ;;; move label bar as close to plot as possible (without making orthogonal position negative)
        opts_bparam@lbTitleExtentF     = 0.0 ; no effect of changing from 0.6
        opts_bparam@lbBottomMarginF     = 0.0 ; no apparnet effect
        opts_bparam@lbTopMarginF     = 0.0 ; no apparnet effect
        opts_bparam@pmLabelBarOrthogonalPosF  = 0.0 ; moves slightly upward
        ;unused  opts_bparam@lbJustification = "TopCenter" set in subroutine so not set here
        ;4test-display_lb_perim: opts_bparam@lbPerimOn = True ; opts_bparam@lbPerimColor = 1
        ;4test-linelabels: opts_bparam@cnLineLabelsOn = True   ; turn on line labels
        ;4test-linelabels: opts_bparam@cnLineLabelBackgroundColor = -1 ; transparent box around line label
        ;4test-linelabels: opts_bparam@cnLineLabelPlacementMode = "Computed" ; alternate method of computing line label locations
        ;4test-linelabels: opts_bparam@cnLineLabelDensityF = 2. ; increase density of line labels
        ;4test-linelabels: opts_bparam@cnLineLabelInterval = 1 ; put label on every line

        ;4test: opts_bparam@ContourParameters = (/ 0., 21000., 1000. /)
        ;4test: opts_bparam@ContourParameters = (/ 0., 0., 1000. /)

;; tjo did modify formatting to separate each parameter section. 
load "rasp.site_load.bparam_resources.ncl";    tjo makes it so this is the only modification to this file.
