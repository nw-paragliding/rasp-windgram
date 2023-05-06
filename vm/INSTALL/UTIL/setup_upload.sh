#!/bin/bash
source $(dirname $0)/output_util.sh
source $(dirname $0)/check_basedir.sh


print_cyan "Setup upload to wxtofly.net (Y/N)?"

FILE="$BASEDIR/WXTOFLY/wxtofly.env"
if (grep -q "WXTOFLY_UPLOAD_ENABLED=YES" $FILE); then
	if ! (perl -pi -w -e "\$bdir=\"WXTOFLY_UPLOAD_ENABLED=NO\"; s/WXTOFLY_UPLOAD_ENABLED=YES/\$bdir/g;" $FILE)
	then
		print_error "Unable to modify file wxtofly.env"
		exit -1
	fi
fi

while true; do
    read -rsn1 key
	key=${key^^}
	case $key in
		Y)
			break ;;
		N)
			exit ;;
		*)
			print_default "Press Y or N" ;;
	esac
done

print_cyan "Enter username and password"
read -p "Username: " -r username
read -p "Password: " -r password

if ! (perl -pi -w -e "\$bdir=\"WXTOFLY_UPLOAD_USERNAME=$username\"; s/WXTOFLY_UPLOAD_USERNAME=olneytj/\$bdir/g;" $FILE)
then
	print_error "Unable to modify file wxtofly.env"
	exit -1
fi
TMP_NETRC="/tmp/netrc"
if [ -e "~/.netrc" ]
then
	cat ~/.netrc >$TMP_NETRC
fi
echo "machine wxtofly.net login $username password $password" >>$TMP_NETRC
mv $TMP_NETRC ~/.netrc

if ! (perl -pi -w -e "\$bdir=\"WXTOFLY_UPLOAD_ENABLED=YES\"; s/WXTOFLY_UPLOAD_ENABLED=NO/\$bdir/g;" $FILE)
then
	print_error "Unable to modify file wxtofly.env"
	exit -1
fi
