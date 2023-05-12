#!/bin/bash

LOGFILE=$0.log

echo "CRON test" >>$LOGFILE
echo " *DATE: "$(date +"%x %X") >>$LOGFILE
echo " *ARGS: $@" >>$LOGFILE
