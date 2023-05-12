#!/bin/bash
echo "Administrator permissions required"
cp $(dirname $0)/enable_hyper_v_lis_cmd.sh /tmp/enable_hyper_v_lis_cmd.sh
sudo su -c /tmp/enable_hyper_v_lis_cmd.sh
rm -f /tmp/enable_hyper_v_lis_cmd.sh