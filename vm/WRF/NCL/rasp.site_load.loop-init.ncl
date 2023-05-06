print("sequence----------------rasp.site_load.loop-init.ncl----------------------")
;;; TO ALTER LOOP INITIALIZATION SECTION
;;; (cannot contain procedures or functions)
;;What does this do?  there is also a loop-top
;; hopefully, I can use this and leave rasp.ncl alone! 
;tjtest print("sequence ------------------  rasp.site_load.loop-init.ncl "+REGION+"-----------------------")

;NhlTFontQuality = High;
;NhlTFontQuality = High;
     opts_ter = True
     opts_ter@cnLineColor = "black"
     opts_ter@cnLineLabelPerimColor = "black"
     ;Changed fonts
     opts_ter@cnLineLabelFontHeightF = .012
;>     opts_ter@cnLineLabelFontHeightF = .010
     opts_ter@cnConstFLabelFont = "times-bold"
     opts_ter@cnLineLabelFont = "times-bold"
;>    opts_ter@cnConstFLabelFont = "helvetica-bold"
;>    opts_ter@cnLineLabelFont = "helvetica-bold"
     opts_ter@lbTitleFont = "times-roman"
     opts_ter@lbLabelFont = "times-roman"
;>    opts_ter@lbTitleFont = "helvetica"
;>    opts_ter@lbLabelFont = "helvetica"

opts_map = True
    opts_map@LabelFont = "times-bold"
    opts_map@LabelFontHeight = .012
;>    opts_map@LabelFont = "helvetica-bold"
;>    opts_map@LabelFontHeight = .01
opts_soundingloc = True
    opts_soundingloc@txFont = "times-roman"
    opts_soundingloc@txFontColor = 1  ;tj use foreground color from pallet black would be better white
    opts_soundingloc@txFontHeightF = 0.011
;>    opts_soundingloc@txFont = "helvetica"
;>    opts_soundingloc@txFontColor = 0  ;white
;>    opts_soundingloc@txFontHeightF = 0.010
opts_w = True
                 opts_w@tiXAxisFont     = "times-roman"        ; Font for X axis label
                 opts_w@tiYAxisFont     = "times-roman"        ; Font for Y axis label
;>                 opts_w@tiXAxisFont     = "helvetica"        ; Font for X axis label
;>                 opts_w@tiYAxisFont     = "helvetica"        ; Font for Y axis label
                 opts_w@tmXBLabelFont     = "times-roman"        ; Font for X number label
;>                 opts_w@tmXBLabelFont     = "helvetica"        ; Font for X number label
                 opts_w@tmYLLabelFont     = "times-roman"        ; Font for Y number label
;>                 opts_w@tmYLLabelFont     = "helvetica"        ; Font for Y number label
                 opts_w@lbLabelFont     = "times-roman"   ; for numbers
;>                 opts_w@lbLabelFont     = "helvetica"   ; for numbers
                 opts_w@lbTitleFont     = "times-roman"   ; for string
;>                 opts_w@lbTitleFont     = "helvetica"   ; for string
                 opts_w@lbTitleFont = "times-roman"
                 opts_w@lbLabelFont = "times-roman"
;>                 opts_w@lbTitleFont = "helvetica"
;>                 opts_w@lbLabelFont = "helvetica"
opts_ws = True
         opts_ws@lbLabelFont = "times-roman"
;>         opts_ws@lbLabelFont = "helvetica"
         opts_ws@lbTitleFont = "times-roman"
;>         opts_ws@lbTitleFont = "helvetica"
         opts_ws@pmLabelBarWidthF  = 0.65      ;0.80  was tj; in rasp.ncl



