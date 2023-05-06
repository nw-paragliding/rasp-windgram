;; --- begin tjo section to avoid race conditions not plotting  ------------------------------------------
;4test  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
;4test  lookfor="[BASEDIR]/WRF/WRFV2/RASP/TIGER-WINDOW/wrfout_d02_2011-05-24_03:00:00"
; revised 2010-05-23 text message changed 2011-11-19
 waitinterval=30          ;new(1,integer)  how often to recheck for wrfout file if not there initially
      
;tjtest print("sequence ------------------  sleep4data.ncl    -----------------------");
      lookfor=FILENAMES(ifile)
      print ("looking for data file to plot "+lookfor)
      filecommand="ls "+lookfor+"| sed -e 's#^.* ##' "
      resultfile=new(1,string)
      resultfile=systemfunc(filecommand)
      print("The file is:  "+resultfile)

if ( ismissing(resultfile) )
      print("1st try for "+lookfor+" no file yet.")

; not found so set up waiting loop check every 30 seconds

  stillwaiting=1
  slept=0
  if ( ismissing(resultfile) )
      print(" Trying to open "+lookfor+" at "+systemfunc("date +%H:%M:%S_%Z"))
      print("using command "+filecommand)
      print("Got result: "+resultfile)
      print("A value of missing or -999  means the file wasn't found so ncl should sleep awhile.")
      stillwaiting=1     ; flag 1 is still waiting, 0 found file
      slept=0            ; how long has it slept
      sleepmsg="Sleeping "+waitinterval+" seconds  between each attempt to read the file."
      print(" "+sleepmsg)
      
      print("Waiting for Godot, filesystem manager, to produce the file we seek.")
 
  end if




  ; let rasp.ncl loop for up to 30 minutes looking for the wrfout file...
  do while ((stillwaiting.eq.1).and.(slept.le.2100))   ;use 1800 for production half hour               
      sleep(waitinterval)
      resultfile=systemfunc(filecommand)
      if(ismissing(resultfile))  
        delete(resultfile)
         stillwaiting=1
         slept=slept+waitinterval
         sleepmsg="slept for "+slept+" seconds"
         print(" "+sleepmsg)
       else
         stillwaiting=0
         print("Finally Found "+lookfor+" Nice work Godot!")
      end if
  end do
 
else
     print("Found data file to plot: "+resultfile)   ; leave this script immediately if the file is there.
     sleepmsg="not waited at all"
end if

print("Starting to plot at "+systemfunc("date +%H:%M:%S_%Z")+" after havinging "+sleepmsg)
;; --- end tjo section to avoid race conditions not plotting ------------------------------------------
