
;;; ********** SELECT DESIRED REGION ********* (selects file and frame)
;;; *NB* IF SET "REGION" HERE, MUST ALSO SET NEEDED REGION PARAMETERS BELOW (not in topo.ncl)
REGION = "PANOCHE"
REGION = "SW_SOUTHAFRICA"
;;; **********  ADD NEW REGION NAME HERE **********


;;; ********** SET REGION-SPECIFIC MODEL OUTPUT FILE  **********
if( REGION .eq. "PANOCHE" ) then
   UNITS="american"
   filenames = (/ \
    "/home/admin/DRJACK/WRF/WRFSI/domains/PANOCHE/static/wrfstatic_d01", \ 
    "/home/admin/DRJACK/WRF/WRFSI/domains/PANOCHE/static/wrfstatic_d02", \ 
    "/home/admin/DRJACK/WRF/WRFSI/domains/PANOCHE/static/wrfstatic_d03", \ 
   "" /)
end if
if( REGION .eq. "SW_SOUTHAFRICA" ) then
    UNITS="celsius"
   filenames = (/ \
    "/home/admin/DRJACK/WRF/WRFSI/domains/SW_SOUTHAFRICA/static/wrfstatic_d01", \ 
    "/home/admin/DRJACK/WRF/WRFSI/domains/SW_SOUTHAFRICA/static/wrfstatic_d02", \ 
    "/home/admin/DRJACK/WRF/WRFSI/domains/SW_SOUTHAFRICA/static/wrfstatic_d03", \ 
   "" /)
end if
;;; **********  ADD NEW REGION FILENAMES HERE **********


;;; ********** ADD A FRAME TO PLOT **********  (kframe depends on REGION (file) to display subgrids)
if( REGION .eq. "PANOCHE" ) then
   ldoframe = -1
   ;;;    kframe array: xl,yb, xr,yt USING NAMELIST FORTRAN INDEXS !!! (which are offset 1/2 from mass coords)
   kframe(0,:) = (/ 12,16, 29,37 /)   ; northg3
   kframe(1,:) = (/ 16,31, 39,65 /)   ; northg3
   kframe(2,:) = (/ 0,0, 0,0 /)       ; northg3
end if 
if( REGION .eq. "SW_SOUTHAFRICA" ) then
   ldoframe = -1
   ;;;    kframe array: xl,yb, xr,yt USING NAMELIST FORTRAN INDEXS !!! (which are offset 1/2 from mass coords)
   kframe(0,:) = (/ 17,16, 32,34 /)   ;
   kframe(1,:) = (/ 9,10, 35,38 /)    ;
   kframe(2,:) = (/ 0,0, 0,0 /)       ; no subgrid
end if 
;;; **********  ADD NEW REGION FRAME CORNERS HERE **********
;;; INSTRUCTIONS: to plot a dashed rectangle indicating the region covered by a subgrid nested within the plotted domain,
;;;               you must set the corner point locations of the subgrid (ala the examples above) 
;;; for first (coarsest) grid:  kframe(0,:)=(/ DOMAIN_ORIGIN_LLI, DOMAIN_ORIGIN_LLJ, DOMAIN_ORIGIN_URI, DOMAIN_ORIGIN_URJ /) ;
;;;    where DOMAIN_ORIGIN_LLI,... are _second_ value of each parameter in $BASEDIR/WRF/wrfsi/REGIONXYZ/static/wrfsi.nl
;;; for second (next-coarsest) grid:  kframe(1,:)=(/ DOMAIN_ORIGIN_LLI, DOMAIN_ORIGIN_LLJ, DOMAIN_ORIGIN_URI, DOMAIN_ORIGIN_URJ /) ;
;;;    where DOMAIN_ORIGIN_LLI,... are _third_ value of each parameter in $BASEDIR/WRF/wrfsi/REGIONXYZ/static/wrfsi.nl
;;; for last grid:  kframe(?,:) = (/ 0,0, 0,0 /) ;  (since that domain does not have a smaller subdomain nested within it)


;;; **********  SET NEW REGION CONTOUR SPACING HERE **********
        ;;; TO FIX TERRAIN CONTOUR SPACING (with auto min/max): opts_bparam@ContourParameters = (/ 0., 0., 500. /)
        ;;; TO FIX TERRAIN CONTOUR SPACING (with set min/max): opts_bparam@ContourParameters = (/ 1000., 12000., 500. /)


