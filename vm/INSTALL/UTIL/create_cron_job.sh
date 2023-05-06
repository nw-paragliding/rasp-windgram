#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh


print_cyan "Create CRON job (Y/N)?"

while true; do
    read -rsn1 key
	key=${key^^}
	case $key in
	
		Y)
			if ! ($BASEDIR/WXTOFLY/CRON/setup_cron_job.sh $BASEDIR)
			then
				print_error "Setting up CRON job failed"
				exit -1
			fi
			break
		;;
		
		N)
			exit
		;;
		
		*)
		
			print_default "Press Y or N"
		;;
	
	esac
done
