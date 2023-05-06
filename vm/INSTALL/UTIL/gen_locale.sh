#!/bin/bash
source $(dirname $0)/output_util.sh

#this will get rid of perl warning
print_default "Setting up locale for en_US"
sudo locale-gen en_US