#!/bin/bash
SCRIPT_DIR=$(dirname $0)

source $SCRIPT_DIR/INSTALL/UTIL/output_util.sh

SOURCE_DIR=$SCRIPT_DIR/INSTALL/SOURCE
BASEDIR=$SCRIPT_DIR

print_magenta "Creating install package"
print_default "SOURCE_DIR: "$SOURCE_DIR
print_default "BASEDIR:    "$BASEDIR

if [ ! -d $SOURCE_DIR ]; then
	print_error "$SOURCE_DIR does not exist"
	exit -1
fi

if [ ! -d $BASEDIR ]; then
	print_error "$SOURCE_DIR does not exist"
	exit -1
fi

#copy files to $BASEDIR
#if ! (rsync -rv $SOURCE_DIR"/" $BASEDIR"/" );
#then
#	echo "Unable to copy files"
#	exit -1
#fi

#print_cyan "Extracting symbolic links"
#if [ ! -e $BASEDIR/all_links.tgz ]
#then
#	print_error "$BASEDIR/all_links.tgz does not exist"
#	exit -1
#fi

#if ! tar xzf $BASEDIR/all_links.tgz -C $BASEDIR
#then
#	print_error "Error extracting symbolic links"
#	exit -1
#fi
#print_default "Done"

CD=$(pwd)
cd $BASEDIR
print_cyan "Creating RASP.tgz"
if ! tar czf $SOURCE_DIR/RASP.tgz RASP
then
	print_error "Error creating RASP.tgz"
	cd $CD
	exit -1
fi
print_default "Done"

print_cyan "Creating UTIL.tgz"
if ! tar czf $SOURCE_DIR/UTIL.tgz UTIL
then
	print_error "Error creating UTIL.tgz"
	cd $CD
	exit -1
fi
print_default "Done"

print_cyan "Creating WRF.tgz"
if ! tar czf $SOURCE_DIR/WRF.tgz WRF
then
	print_error "Error creating WRF.tgz"
	cd $CD
	exit -1
fi
print_default "Done"

print_cyan "Creating WXTOFLY.tgz"
if ! tar czf $SOURCE_DIR/WXTOFLY.tgz WXTOFLY
then
	print_error "Error creating WXTOFLY.tgz"
	cd $CD
	exit -1
fi
print_default "Done"

print_cyan "Creating install package wxtofly.tgz"
if ! tar czf $BASEDIR/wxtofly.tgz INSTALL
then
	print_error "Error creating wxtofly.tgz"
	cd $CD
	exit -1
fi
cd $CD
print_default "Done"

print_magenta "Upload $BASEDIR/wxtofly.tgz to wxtofly.net (Y/N)?"

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

print_cyan "Uploading..."

TMP_NETRC="/tmp/netrc"
if [ -e "~/.netrc" ]
then
	mv ~/.netrc $TMP_NETRC
fi
echo "machine wxtofly.net login $username password $password" > ~/.netrc
echo "" >> ~/.netrc

URL="ftp://"${username}"@wxtofly.net/html/install/wxtofly.tgz"
echo "--> $URL"

if ! curl -n -T $BASEDIR/wxtofly.tgz $URL
then
	echo "****Error: $BASEDIR/wxtofly.tgz not uploaded"
	cat ~/.netrc
fi

if [ -e $TMP_NETRC ]
then
	mv $TMP_NETRC ~/.netrc
fi
