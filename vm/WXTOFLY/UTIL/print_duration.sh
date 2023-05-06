#!/bin/bash
if [ -z $1 ]; then
	echo "****Error: Duration argument not speficied" >&2
	exit -1
fi

DURATION=$1
((HR=DURATION / 3600))
((DURATION=DURATION % 3600 ))
((MM=DURATION / 60))
((SS=DURATION % 60))

echo "$(printf "%02d:%02d:%02d" $HR $MM $SS)"
