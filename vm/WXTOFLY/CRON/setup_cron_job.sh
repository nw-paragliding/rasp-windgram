#!/bin/bash

if [ -z $BASEDIR ]; then
	if [ -z $1 ]; then
		echo "****Error: BASEDIR variable not defined"
		exit -1
	fi
	BASEDIR=$1
	if ! source $BASEDIR/WXTOFLY/wxtofly.env ; then
		echo "****Error: $BASEDIR/WXTOFLY/wxtofly.env not found"
		exit -1
	fi
fi
echo "BASEDIR: $BASEDIR"

INSTALL=true
#check CRON is installed
echo "Checking CRON is installed"
which cron
have=$?
if [[ $have -eq 0  ]]; then
	echo "$(tput setaf 2)cron is installed$(tput sgr 0)"
else
	echo "$(tput setaf 1)cron not installed$(tput sgr 0)"
	if [ $INSTALL = true ]; then
		echo "Installing cron ..."
		if [ $OS == "ubuntu" ]; then
			sudo apt-get install -y cron
		fi
		if [ $OS == "fedora" ]; then
			sudo yum install -y cron 
		fi
		if [[ $? != 0  ]]; then
			echo "Install failed"
			exit -1
		fi
	else
		exit -1
	fi
fi

#Check CRON is running
echo "Checking CRON is running"
if (( $(ps -ef | grep -v grep | grep cron | wc -l) > 0 ))
then
	echo "$(tput setaf 2)cron service is running$(tput sgr 0)"
else
	echo "$(tput setaf 1)cron service is not running $(tput sgr 0)"
	sudo service cron start
	#Check CRON is running again
	if (( $(ps -ef | grep -v grep | grep cron | wc -l) > 0 ))
	then
		echo "$(tput setaf 2)cron service is running$(tput sgr 0)"
	else
		echo "$(tput setaf 1)Error: Unable to start cron service $(tput sgr 0)"
		exit -1
	fi
fi

echo "Deleting current CRON jobs"
crontab -r

echo "Creating CRON jobs"
WXTOFLY_CRON=$(dirname $0)
for FILE in $(find "$WXTOFLY_CRON" -type f -name "*.cron" ); 
do
	echo "Found $FILE"
	
	TMPFILE="/tmp/"$(basename $FILE)
	if ! cp -f $FILE $TMPFILE ; 
	then
		echo "$(tput setaf 1)Error: Unable to copy file $FILE to $TMPFILE$(tput sgr 0)"
		exit -1
	fi

	if ! perl -pi -w -e "\$bdir = \"$BASEDIR\"; s/{BASEDIR}/\$bdir/g;" $TMPFILE ; 
	then
		echo "$(tput setaf 1)Error: Modify $TMPFILE $(tput sgr 0)"
		exit -1
	fi
	
	if ! crontab $TMPFILE ; 
	then
		echo "$(tput setaf 1)Error: Error adding CRON job $(tput sgr 0)"
		cat $TMPFILE
		exit -1
	fi
	
done
echo "Done creating CRON jobs"

CURRENT_CRONTAB=$WXTOFLY_CRON/cron.$(date +"%Y%m%d_%H%M%S")
crontab -l >$CURRENT_CRONTAB
echo "CRON jobs saved in $CURRENT_CRONTAB"
