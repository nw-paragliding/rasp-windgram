#!/bin/bash
if [ -z $1 ]
then
	echo "BASEDIR argument not specified"
	exit -1
fi
BASEDIR=$1
echo "BASEDIR=$BASEDIR"
if [ ! -d $BASEDIR ];
then
	echo "$BASEDIR does not exist"
	exit -1
fi

CD=$(pwd)
function create_domain_currN {

	REGION=$1
	N=$2

	NEW_REGION="${REGION}+${N}"

	echo "$NEW_REGION"
	
	rm -rf $BASEDIR/WRF/wrfsi/domains/${REGION}+${N}
	rm -rf $BASEDIR/WRF/WRFV2/RASP/${REGION}+${N}
	rm -rf $BASEDIR/WRF/wrfsi/domains/${REGION}+${N}-WINDOW
	rm -rf $BASEDIR/WRF/WRFV2/RASP/${REGION}+${N}-WINDOW

	cd $BASEDIR/WRF/UTIL

	./create_directory.wrfsi_linked.pl $BASEDIR/WRF/wrfsi/domains/$REGION $BASEDIR/WRF/wrfsi/domains/${REGION}+${N}
	./create_directory.wrf_linked.pl $BASEDIR/WRF/WRFV2/RASP/$REGION $BASEDIR/WRF/WRFV2/RASP/${REGION}+${N}

	cd $BASEDIR/WRF/wrfsi/domains/${REGION}+${N}
	$BASEDIR/WRF/UTIL/create_directory.wrfsi_window.pl
	
	cd $BASEDIR/WRF/WRFV2/RASP/${REGION}+${N}
	$BASEDIR/WRF/UTIL/create_directory.wrf_window.pl

	mkdir -p "$BASEDIR/RASP/HTML/$NEW_REGION/FCST"
	
	for pf in $(find $BASEDIR/WXTOFLY/RUN/PARAMETERS -type f -name "rasp.run.parameters.$REGION.*")
	do
		new_pf=${pf/$REGION/$NEW_REGION}
		cp -f $pf $new_pf
		perl -pi -w -e "\$r=\"$NEW_REGION\"; s/$REGION/\$r/g;" $new_pf

		g00="'0Z\+12','0Z\+15','0Z\+18','0Z\+21','0Z\+24','0Z\+27'"
		g06="'6Z\+6','6Z\+9','6Z\+12','6Z\+15','6Z\+18','6Z\+21'"
		g012="'12Z\+0','12Z\+3','12Z\+6','12Z\+9','12Z\+12','12Z\+15'"
		g018="'18Z\+0','18Z\+3','18Z\+6','18Z\+9'"
		
		if [ $N == 1 ]; then
			g10="'0Z\+36','0Z\+39','0Z\+42','0Z\+45','0Z\+48','0Z\+51'"
			g16="'6Z\+30','6Z\+33','6Z\+36','6Z\+39','6Z\+42','6Z\+45'"
			g112="'12Z\+24','12Z\+27','12Z\+30','12Z\+33','12Z\+36','12Z\+39'"
			g118="'18Z\+18','18Z\+21','18Z\+24','18Z\+27','18Z\+30','18Z\+33'"

			if [[ $pf == *0z* ]]; then
				perl -pi -w -e "\$r=\"$g10\"; s/$g00/\$r/g;" $new_pf ;fi
			if [[ $pf == *6z* ]]; then
				perl -pi -w -e "\$r=\"$g16\"; s/$g06/\$r/g;" $new_pf ;fi
			if [[ $pf == *12z* ]]; then
				perl -pi -w -e "\$r=\"$g112\"; s/$g012/\$r/g;" $new_pf ;fi
			if [[ $pf == *18z* ]]; then
				perl -pi -w -e "\$r=\"$g118\"; s/$g018/\$r/g;" $new_pf ;fi
		elif [ $N == 2 ]; then
			g20="'0Z\+60','0Z\+63','0Z\+66','0Z\+69','0Z\+72','0Z\+75'"
			g26="'6Z\+54','6Z\+57','6Z\+60','6Z\+63','6Z\+66','6Z\+69'"
			g212="'12Z\+48','12Z\+51','12Z\+54','12Z\+57','12Z\+60','12Z\+63'"
			g218="'18Z\+42','18Z\+45','18Z\+48','18Z\+51','18Z\+54','18Z\+57'"

			if [[ $pf == *0z* ]]; then
				perl -pi -w -e "\$r=\"$g20\"; s/$g00/\$r/g;" $new_pf ;fi
			if [[ $pf == *6z* ]]; then
				perl -pi -w -e "\$r=\"$g26\"; s/$g06/\$r/g;" $new_pf ;fi
			if [[ $pf == *12z* ]]; then
				perl -pi -w -e "\$r=\"$g212\"; s/$g012/\$r/g;" $new_pf ;fi
			if [[ $pf == *18z* ]]; then
				perl -pi -w -e "\$r=\"$g218\"; s/$g018/\$r/g;" $new_pf ;fi
		elif [ $N == 3 ]; then
			g30="'0Z\+84'"
			g36="'6Z\+78','6Z\+81','6Z\+84'"
			g312="'12Z\+72','12Z\+75','12Z\+78','12Z\+81','12Z\+84'"
			g318="'18Z\+66','18Z\+69','18Z\+72','18Z\+75','18Z\+78','18Z\+81'"
			
			if [[ $pf == *0z* ]]; then
				perl -pi -w -e "\$r=\"$g30\"; s/$g00/\$r/g;" $new_pf ;fi
			if [[ $pf == *6z* ]]; then
				perl -pi -w -e "\$r=\"$g36\"; s/$g06/\$r/g;" $new_pf ;fi
			if [[ $pf == *12z* ]]; then
				perl -pi -w -e "\$r=\"$g312\"; s/$g012/\$r/g;" $new_pf ;fi
			if [[ $pf == *18z* ]]; then
				perl -pi -w -e "\$r=\"$g318\"; s/$g018/\$r/g;" $new_pf ;
			fi
		fi
	done
}

domains=("PNW" "TIGER" "FRASER" "FT_EBEY" "PNWRAT")

for d in ${domains[@]}
do
	create_domain_currN "$d" 1
	create_domain_currN "$d" 2
	create_domain_currN "$d" 3
done

cd $CD
