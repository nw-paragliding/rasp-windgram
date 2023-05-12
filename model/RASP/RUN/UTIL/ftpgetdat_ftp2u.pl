#!/usr/bin/perl 

### to download truncated AVN files convering limited lat/lon region
### based on NCEP capability at http://nomads6.ncdc.noaa.gov/cgi-bin/ftp2u_gfs.sh 
### from a script created by Paul Hope (Cape Town, South Africa) Jan 2006, updated May 2007

### SPECIFY SERVER TO BE USED (has been known to vary!)
$SERVER = 'nomads6.ncdc.noaa.gov' ;
#alternate: $SERVER = 'nomads5.ncdc.noaa.gov' ;

print ">start.. $ARGV[0]";

  ### READ ARGUMENT LIST
  (
    $curlexe,
    $filename,
    $leftlong,
    $rightlong,
    $toplat,
    $bottomlat,
    $ifile,
    $GRIBFTPSTDOUT,
    $GRIBFTPSTDERR,
    $outdir
  ) = split ',', $ARGV[0];

$STDOUTFILE = "${GRIBFTPSTDOUT}.${ifile}" ;
$STDERRFILE = "${GRIBFTPSTDERR}.${ifile}" ;
 $isok=10;
$maxtry=0;

# Extract WAN IP Address
$strCheckWAN = "http://checkip.dyndns.org/"; 
$strStartWAN = "Current IP Address: ";  
$strEndWAN = "</body>";   
$strDate = localtime(time);  
$strFILE = `$curlexe -s $strCheckWAN`;
$intSTART = index($strFILE, $strStartWAN) + length($strStartWAN);
$intEND = index($strFILE, $strEndWAN);
$intWANSize = $intEND - $intSTART;
$strWANIP = substr($strFILE, $intSTART, $intWANSize);
$curdate=`date -u +%Y%m%d`;

print ">>>>debug: $curlexe,
    $filename,
    $leftlong,
    $rightlong,
    $toplat,
    $bottomlat,
    $ifile,
    $GRIBFTPSTDOUT,
    $GRIBFTPSTDERR,
    $outdir,
    $strWANIP,
    $curdate  \n";

while( $isok >1) {

$in=`$curlexe -s "http://${SERVER}/cgi-bin/ftp2u_gfs.sh?file=$filename\&wildcard=\&all_lev=on\&all_var=on\&subregion=on\&leftlon=$leftlong\&rightlon=$rightlong\&toplat=$toplat\&bottomlat=$bottomlat\&results=SAVE\&rtime=1hr\&machine=$strWANIP\&user=anonymous\&password=\&ftpdir=%Fincoming_1hr\&prefix=\&dir=%2Fgfs$curdate" >| ${STDOUTFILE}.ftp2u.out 2>| ${STDERRFILE}.ftp2u.err `;
#old $in=`$curlexe -s "http://nomads6.ncdc.noaa.gov/cgi-bin/ftp2u_gfs.sh?file=$filename\&wildcard=\&all_lev=on\&all_var=on\&subregion=on\&leftlon=$leftlong\&rightlon=$rightlong\&toplat=$toplat\&bottomlat=$bottomlat\&results=SAVE\&rtime=1hr\&machine=$strWANIP\&user=anonymous\&password=\&ftpdir=%Fincoming_1hr\&prefix=\&dir=%2Fgfs$curdate" >| ${STDOUTFILE}.ftp2u.out 2>| ${STDERRFILE}.ftp2u.err `;
#older $in=`$curlexe -s "http://nomad5.ncep.noaa.gov/cgi-bin/ftp2u_gfs_dir.sh?file=$filename\&wildcard=\&all_lev=on\&all_var=on\&subregion=on\&leftlon=$leftlong\&rightlon=$rightlong\&toplat=$toplat\&bottomlat=$bottomlat\&results=SAVE\&rtime=1hr\&machine=$strWANIP\&user=anonymous\&password=\&ftpdir=%Fincoming_1hr\&prefix=\&dir=%2Fgfs$curdate" >| ${STDOUTFILE}.ftp2u.out 2>| ${STDERRFILE}.ftp2u.err `;


$in2=`grep ftp ${STDOUTFILE}.ftp2u.out`;

print ">>>>debug2 ($maxtry): $in2 \n\n" ; #>| ${STDOUTFILE}.ftp2u.out;

#old `rm ${STDOUTFILE}.ftp2u.out`;#!/usr/bin/perl






($one,$two,$three,$four,$five,$six,$seven)=split(m|/|,$in2);


# 
print "deb: $one,$two,$three,$four,$five,$six,$seven \n";

  if ( $four eq 'pub' )
         {  $isok=0; 
       # print ">>>>debug2: isok!!!\n\n"; # >| ${STDOUTFILE}.ftp2u.out;
    }
  else { sleep  60 ; }    
  $maxtry=$maxtry+1;
 if($maxtry > 15) { $isok=0;  }

}
  
print ">>>>debug3:  ftp://${SERVER}/$four/$five/$six/$seven/$filename";
#old print ">>>>debug3:  ftp://nomads6.ncdc.noaa.gov/$four/$five/$six/$seven/$filename";
#older print ">>>>debug3:  ftp://nomad5.ncep.noaa.gov/$four/$five/$six/$filename";

$fres=`$curlexe -s --disable-epsv -o $outdir/$filename "ftp://${SERVER}/$four/$five/$six/$seven/$filename" >| $STDOUTFILE 2>| $STDERRFILE`;
#old $fres=`$curlexe -s --disable-epsv -o $outdir/$filename "ftp://nomads6.ncdc.noaa.gov/$four/$five/$six/$seven/$filename" >| $STDOUTFILE 2>| $STDERRFILE`;
#older $fres=`$curlexe -s --disable-epsv -o $outdir/$filename "ftp://nomad5.ncep.noaa.gov/$four/$five/$six/$filename" >| $STDOUTFILE 2>| $STDERRFILE`;

print ">>>>debug4: fin: $fres \n";

