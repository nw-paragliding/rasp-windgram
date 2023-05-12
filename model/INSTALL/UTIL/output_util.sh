#!/bin/bash

shopt -s expand_aliases

#define colors
grey='\e[1;30m%s\e[0m\n'
red='\e[1;31m%s\e[0m\n'
green='\e[1;32m%s\e[0m\n'
yellow='\e[1;33m%s\e[0m\n'
blue='\e[1;34m%s\e[0m\n'
magenta='\e[1;35m%s\e[0m\n'
cyan='\e[1;36m%s\e[0m\n'
default='%s\n'

alias print_error="printf \"\e[1;31m  ****Error: %s\e[0m\n\" "
alias print_ok="printf \"$green\" "
alias print_red="printf \"$red\" "
alias print_green="printf \"$green\" "
alias print_yellow="printf \"$yellow\" "
alias print_blue="printf \"$blue\" "
alias print_magenta="printf \"$magenta\" "
alias print_cyan="printf \"$cyan\" "
alias print_default="printf \"$default\" "