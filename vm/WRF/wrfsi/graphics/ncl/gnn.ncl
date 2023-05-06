
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
;
  cdf_file = addfile("static.cdf","r") 
;  cdf_file = addfile("carib.cdf","r") 
;  cdf_file = addfile("baja2.cdf","r") ; baja2
;  cdf_file = addfile("florida.cdf","r") ; florida
;  cdf_file = addfile("taiwan.cdf","r") ; taiwan
;  cdf_file = addfile("alaska.cdf","r") ; alaska
;  cdf_file = addfile("CONUS_10.cdf","r") 
;
  var = cdf_file->gnn(0,0,:,:)
  lat2d = cdf_file->lat(0,0,:,:)
  lon2d = cdf_file->lon(0,0,:,:)
  varstr = "gnn"
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
           "wkMetaName" : "./gnn.ncgm"
        end create
    else
      if (X11 .eq. 1) then
;
; Create an XWorkstation object.
;
        wid = create "wrfsiWork" xWorkstationClass defaultapp
            "wkPause" : True
        end create
      else
        if (PS .eq. 1) then
;
; Create a PSWorkstation object.
;
          wid = create "wrfsiWork" psWorkstationClass defaultapp
           "wkPSFileName" : "./gnn.ps"
          end create
        end if
      end if
    end if
;
; Assign the colormap to the workstation.
setvalues wid
; Generate a colormap.
   "wkColorMap" : gen_colormap()
end setvalues
; Increase workspace memory
setvalues NhlGetWorkspaceObjectId()
   "wsMaximumSize": 33554432
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
  "mpDataBaseVersion" : "RANGS_GSHHS"
  "mpOutlineBoundarySets" : "GeophysicalAndUSStates"
  "mpGeophysicalLineColor" : "Background"
  "mpUSStateLineColor" : "Background"
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
  "mpUSStateLineColor" : "Background"
  "mpNationalLineColor" : "Background"
  "mpGeophysicalLineColor" : "Background"
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
if (difflat .lt. 20. .and. difflon .lt. 20.) then
  levsarr = (/0,0.01,2,4,6,8,10,12,14,16,18,20,22,24,26,\
              28,30,32,34,36,38,40,42,44,46,48,50,52,54,\
              56,58,60,62,64,66,68,70,72,74,76,78,80,82,\
              84,86,88,90,92,94,96,98,100/)
  colsarr = (/1,2,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,\
              19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,\
              34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,\
              49,50,51,52,53,54/)
else
  levsarr = (/0,0.01,4,8,12,16,20,24,28,32,36,40,44,48,\
              52,56,60,64,68,72,76,80,84,88,92,96,100/)
  colsarr = (/1,2,4,6,8,10,12,14,16,18,20,22,24,26,28,\
              30,32,34,36,38,40,42,44,46,48,50,52,53,54/)
end if
;
; Create a ContourPlot object.
;
cnid = create "contourplot" contourPlotClass wid
    "cnScalarFieldData":  varfield
    "cnLevelSelectionMode" : "ExplicitLevels"
    "cnLevels" : levsarr
    "cnFillColors" : colsarr
    "cnFillOn" : True
    "cnLinesOn" : False
    "cnLineLabelsOn" : False
    "cnInfoLabelOn" : False
    "pmTickMarkDisplayMode" : "NoCreate"
;    "tmXMajorGrid" : True
;    "tmYMajorGrid" : True
;    "tmXMinorGrid" : True
;    "tmYMinorGrid" : True
    "pmLabelBarDisplayMode" : "NoCreate"
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
if (difflat .lt. 20. .and. difflon .lt. 20.) then
  boxct = 53
  stride = 2
  filllabels = (/0,0.01,2,4,6,8,10,12,14,16,18,20,22,24,26,\
              28,30,32,34,36,38,40,42,44,46,48,50,52,54,\
              56,58,60,62,64,66,68,70,72,74,76,78,80,82,\
              84,86,88,90,92,94,96,98,100/)
  fillcols = (/2,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,\
              19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,\
              34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,\
              49,50,51,52,53,54/)
else
  boxct = 28
  stride = 1
  filllabels = (/0,0.01,4,8,12,16,20,24,28,32,36,40,44,48,\
              52,56,60,64,68,72,76,80,84,88,92,96,100/)
  fillcols = (/2,4,6,8,10,12,14,16,18,20,22,24,26,28,\
              30,32,34,36,38,40,42,44,46,48,50,52,53,54/)
end if
;
lbid = create "LabelBar" labelBarClass wid
    "lbAutoManage" : False
    "lbOrientation" : "horizontal"
    "lbLabelFont" : 4
    "lbLabelFontHeightF" : .008
    "lbMonoFillPattern" : True
    "lbBoxCount" : 9
    "lbBoxLinesOn" : False
    "lbBoxCount" : boxct
    "lbFillColors" : fillcols
    "lbLabelStrings" : filllabels
    "lbLabelStride" : stride
    "lbLabelAlignment" : "InteriorEdges"
    "lbPerimOn" : False
    "vpXF"      : 0.0125
    "vpYF"      : vpy-vpheight
    "vpWidthF"  : 0.975
    "vpHeightF" : 0.04
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
draw(lbid)
frame(wid)
;
end
;
