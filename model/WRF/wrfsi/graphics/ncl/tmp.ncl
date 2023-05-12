
function gen_colormap( )
begin
        ;This procedure explicitly sets the red, green, and blue
        ;intensities for each element in a colormap array.
 
        ; Set the color map
        ; Entry 0 is the background color.
 
        ; Entry 1 is the foreground color.
        ; The continental outlines in the map object use this color
        ; as a default.
        return( (/ (/.000,.000,.000/), \
                (/1.000,1.000,1.000/), \
                (/.160,.390,.660/), \
                (/.160,.390,.660/), \
                (/.975,1.000,.975/), \
                (/.950,1.000,.950/), \
                (/.925,.975,.925/), \
                (/.900,.975,.900/), \
                (/.875,.950,.875/), \
                (/.850,.950,.850/), \
                (/.825,.925,.825/), \
                (/.800,.925,.800/), \
                (/.775,.900,.775/), \
                (/.750,.900,.750/), \
                (/.725,.875,.725/), \
                (/.700,.875,.700/), \
                (/.675,.850,.675/), \
                (/.650,.850,.650/), \
                (/.625,.825,.625/), \
                (/.600,.825,.600/), \
                (/.575,.800,.575/), \
                (/.550,.800,.550/), \
                (/.525,.775,.525/), \
                (/.500,.775,.500/), \
                (/.475,.750,.475/), \
                (/.450,.750,.450/), \
                (/.425,.725,.425/), \
                (/.400,.725,.400/), \
                (/.375,.700,.375/), \
                (/.350,.700,.350/), \
                (/.325,.675,.325/), \
                (/.300,.675,.300/), \
                (/.275,.650,.275/), \
                (/.250,.650,.250/), \
                (/.225,.625,.225/), \
                (/.200,.625,.200/), \
                (/.175,.600,.175/), \
                (/.150,.600,.150/), \
                (/.125,.575,.125/), \
                (/.100,.575,.100/), \
                (/.075,.550,.075/), \
                (/.050,.550,.050/), \
                (/.025,.525,.025/), \
                (/.000,.500,.000/), \
                (/.000,.475,.000/), \
                (/.000,.450,.000/), \
                (/.000,.425,.000/), \
                (/.000,.400,.000/), \
                (/.000,.375,.000/), \
                (/.000,.350,.000/), \
                (/.000,.325,.000/), \
                (/.000,.300,.000/), \
                (/.000,.275,.000/), \
                (/.000,.250,.000/), \
                (/.000,.225,.000/) /) )
end
;
begin

  cdf_file = addfile("static.cdf","r") 
;  cdf_file = addfile("carib.cdf","r") 
;  cdf_file = addfile("baja2.cdf","r") ; baja2
;  cdf_file = addfile("taiwan.cdf","r") ; taiwan
;  cdf_file = addfile("CONUS_10.cdf","r") ; 10km CONUS
;  cdf_file = addfile("capecod.cdf","r") ; cape cod
;
  var = cdf_file->tmp(0,0,:,:)
  if (ismissing(max(var)) .and. ismissing(min(var))) then
    print("Nothing to contour -- exiting")
    exit
  end if
  lat2d = cdf_file->lat(0,0,:,:)
  lon2d = cdf_file->lon(0,0,:,:)
  varstr = "tmp"
  nx = cdf_file->Nx(0)
  xdim = nx - 1
  ny = cdf_file->Ny(0)
  ydim = ny - 1
  rnx = 1.*xdim
  rny = 1.*ydim
  if (rny .ge. rnx) then
    vpheight = .80
    vpy = 1.-((1.-vpheight)/2.)
    vpwidth = (vpheight/rny)*rnx
    vpx = (1.-((vpheight/rny)*rnx))/2.
  else
    vpwidth = .80
    vpx = (1.-vpwidth)/2.
    vpheight = (vpwidth/rnx)*rny
    vpy = 1.-((1.-((vpwidth/rnx)*rny))/2.)
  end if
  latin1 = cdf_file->Latin1
  latin2 = cdf_file->Latin2
  lov = cdf_file->LoV
  proj = cdf_file->grid_type
  projstr = ""
  do n = 0,30
    projstr = projstr + proj(0,n)
  end do
  spac = cdf_file->grid_spacing/1000.
;
; Create an application object.
;
appid = create "wrfsi" appClass defaultapp
    "appUsrDir" : "./"
    "appDefaultParent" : True
end create
;
; Set only one of the following three params to 1, depending on the type
; of output desired (NCGM=metacode file, X11=screen, PS=PostScript file)
;
    NCGM=1
    X11=0
    PS=0
;
    if (NCGM .eq. 1) then
;
; Create an ncgmWorkstation object.
;
        wid = create "wrfsiWork" ncgmWorkstationClass defaultapp
           "wkMetaName" : "./tmp.ncgm"
           "wkColorMap" : "temp1"
        end create
    else
      if (X11 .eq. 1) then
;
; Create an XWorkstation object.
;
        wid = create "wrfsiWork" xWorkstationClass defaultapp
            "wkPause" : True
            "wkColorMap" : "temp1"
        end create
      else
        if (PS .eq. 1) then
;
; Create a PSWorkstation object.
;
          wid = create "wrfsiWork" psWorkstationClass defaultapp
           "wkPSFileName" : "./tmp.ps"
           "wkColorMap" : "temp1"
          end create
        end if
      end if
    end if
;
;; Assign the colormap to the workstation.
;setvalues wid
;; Generate a colormap.
;   "wkColorMap" : gen_colormap()
;end setvalues
; Increase workspace memory
setvalues NhlGetWorkspaceObjectId()
   "wsMaximumSize": 67108864
end setvalues
;
difflat = (ny * spac) / 111.1 ; approx latitude degree spacing
difflon = (nx * spac) / 111.1 ; approx longitude degree spacing
gridsp = 1.
if (difflat .gt. 20. .or. difflon .gt. 20.) then
  gridsp = 5.
end if
if (difflat .gt. 40. .or. difflon .gt. 40.) then
  gridsp = 10.
end if
if (projstr .eq. "tangential lambert conformal  " .or.\
    projstr .eq. "secant lambert conformal      ") then
  mapproj = "LambertConformal"
  mapcentlat = 0.0 ; these values are ignored by the Lambert
  mapcentlon = 0.0 ; projection, but need to be set anyway
end if
if (projstr .eq. "mercator                      ") then
  mapproj = "Mercator"
  mapcentlat = 0.0 ; needs to be 0.0 for straight lat lines
  mapcentlon = cdf_file->center_lon
end if
if (projstr .eq. "polar stereographic           ") then
  mapproj = "Stereographic"
  mapcentlat = cdf_file->center_lat ; settings necessary for PS
  mapcentlon = lov                  ; projection
end if
;
mpid = create "mapplot" mapPlotClass wid
;
  "mpProjection" : mapproj
;
  "mpLimitMode" : "Corners"    ; Limit the map view.
  "mpLeftCornerLonF" : lon2d(1,1)
  "mpLeftCornerLatF" : lat2d(1,1)
  "mpRightCornerLonF" : lon2d(ydim,xdim)
  "mpRightCornerLatF" : lat2d(ydim,xdim)
;
  "mpLambertParallel1F" : latin1
  "mpLambertParallel2F" : latin2
  "mpLambertMeridianF" : lov
  "mpCenterLonF" : mapcentlon
  "mpCenterLatF" : mapcentlat
  "tfDoNDCOverlay" : True
;
  "mpFillAreaSpecifiers" : (/"USStatesLand"/)
  "mpSpecifiedFillColors" : (/0/)
  "mpDataBaseVersion" : "RANGS_GSHHS"
  "mpOutlineBoundarySets" : "GeophysicalAndUSStates"
  "mpGeophysicalLineColor" : "Foreground"
  "mpUSStateLineColor" : "Foreground"
  "mpUSStateLineThicknessF" : 1.25
  "mpGridSpacingF" : gridsp
  "mpGridLineColor" : "Foreground"
  "mpGridLineDashPattern" : 2
  "mpPerimOn" : True
  "mpPerimLineThicknessF" : 1.5
  "vpXF"      : vpx ; Viewport settings
  "vpYF"      : vpy
  "vpWidthF"  : vpwidth
  "vpHeightF" : vpheight
;
end create
;
mpid2 = create "mapplot" mapPlotClass wid
;
; map object strictly to create US state outlines
;
  "mpProjection" : mapproj
;
  "mpLimitMode" : "Corners"    ; Limit the map view.
  "mpLeftCornerLonF" : lon2d(1,1)
  "mpLeftCornerLatF" : lat2d(1,1)
  "mpRightCornerLonF" : lon2d(ydim,xdim)
  "mpRightCornerLatF" : lat2d(ydim,xdim)
;
  "mpLambertParallel1F" : latin1
  "mpLambertParallel2F" : latin2
  "mpLambertMeridianF" : lov
  "mpCenterLonF" : mapcentlon
  "mpCenterLatF" : mapcentlat
  "tfDoNDCOverlay" : True
;
  "mpDataBaseVersion" : "Ncarg4_1"
  "mpOutlineBoundarySets" : "USStates"
  "mpUSStateLineColor" : "Foreground"
  "mpNationalLineColor" : "Foreground"
  "mpGeophysicalLineColor" : "Foreground"
  "mpUSStateLineThicknessF" : 1.25
  "mpOutlineDrawOrder" : "Draw"
  "mpGridSpacingF" : gridsp
  "mpGridLineColor" : "Foreground"
  "mpGridLineDashPattern" : 2
  "mpPerimOn" : True
  "mpPerimLineThicknessF" : 1.5
  "vpXF"      : vpx ; Viewport settings
  "vpYF"      : vpy
  "vpWidthF"  : vpwidth
  "vpHeightF" : vpheight
;
end create
;
; Create a ScalarField object.
;
varfield = create "ScalarField" scalarFieldClass appid
    "sfDataArray" : var
;    "sfXCStartV" : 0 
;    "sfYCStartV" : 0 
;    "sfXCEndV" : xdim 
;    "sfYCEndV" : ydim
    "sfXCStartSubsetV" : 0
    "sfYCStartSubsetV" : 0
    "sfXCEndSubsetV" : xdim - 1
    "sfYCEndSubsetV" : ydim - 1
    "sfMissingValueV" : 1.0E+37
end create
;
;diff = floattoint(max(var)-min(var))
;if (diff .lt. 60) then
;  diffdiv2 = floattoint(diff/2) + 1
;  startpt = 30 - diffdiv2
;  endpt = 30 + diffdiv2
;  fillindices = ispan(startpt,endpt,1)
;else
;  diff = 60
;  fillindices = ispan(2,62,1)
;end if
;rdiff = max(var)-min(var)
;if (rdiff .le. 1.) then
;  minlv = min(var)
;  maxlv = max(var)
;  if (rdiff .gt. 0.7) then
;    levsp = .05
;    lbstr = 2
;  else
;    levsp = .025
;    lbstr = 4
;  end if
;  delete(fillindices)
;  rdiffdiv2 = floattoint((rdiff/levsp)/2) + 1
;  startpt = 30 - rdiffdiv2
;  endpt = 30 + rdiffdiv2
;  fillindices = ispan(startpt,endpt,1)
;else
;  minlv = floattoint(min(var))
;  maxlv = floattoint(max(var))
;  levsp = floattoint((max(var)-min(var))/diff)
;  lbstr = 2
;end if
minlv = min(var) - 1
maxlv = max(var) + 1
levsp = (maxlv-minlv)/50
lbstr = 4
;
; Create a ContourPlot object.
;
cnid = create "contourplot" contourPlotClass wid
    "cnScalarFieldData":  varfield
    "cnRasterModeOn" : True
;    "cnFillColors": fillindices
    "cnLevelSelectionMode" : "ManualLevels"
    "cnMinLevelValF" : minlv 
    "cnMaxLevelValF" : maxlv
    "cnLevelSpacingF" : levsp 
    "cnFillOn" : True
    "cnLinesOn" : False
    "cnLineLabelsOn" : False
    "cnInfoLabelOn" : False
    "pmTickMarkDisplayMode" : "NoCreate"
;    "tmXMajorGrid" : True
;    "tmYMajorGrid" : True
;    "tmXMinorGrid" : True
;    "tmYMinorGrid" : True
    "pmLabelBarDisplayMode" : "ALWAYS"
    "pmLabelBarHeightF" : .05
    "pmLabelBarWidthF" : 0.9
    "pmLabelBarSide" : "bottom"
    "pmLabelBarOrthogonalPosF" : 0.0
    "lbOrientation" : "horizontal"
    "lbAutoManage" : True
    "lbLabelFont" : 4
    "lbLabelFontHeightF" : .02
    "lbLabelStride" : lbstr
    "lbTitleFont" : 22  ; Helvetica-bold
    "lbTitleFontColor" : "PaleGreen4"
    "lbPerimOn" : False
    "lbBoxLinesOn" : 0
    "tiMainString" : var@long_name
    "tiMainFont" : 4
    "tiMainFontHeightF" : .015
    "tiMainFontColor" : 1
    "tiMainJust" : "CenterCenter"
    "tiMainOffsetXF" : 0.0
    "tiMainOffsetYF" :	-0.002
    "vpXF"      : vpx ; Viewport settings
    "vpYF"      : vpy
    "vpWidthF"  : vpwidth
    "vpHeightF" : vpheight
;
end create
;
txid = create "TextItems" textItemClass wid
  "txFuncCode" : "~"
  "txString" : "Powered by NCL"
  "txFont" : 4
  "txFontHeightF" : 0.008
  "txFontColor" : 1
end create
;
ianno = NhlAddAnnotation(mpid,txid)
setvalues ianno
;  "amZone":           10
  "amSide":           "bottom"
  "amJust":           "bottomright"
  "amParallelPosF":    0.49
  "amOrthogonalPosF":  0.49
end setvalues
;
; Draw map
;
draw(cnid)
draw(mpid)
draw(mpid2)
frame(wid)
;
end
;
