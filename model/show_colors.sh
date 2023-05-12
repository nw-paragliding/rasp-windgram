#!/bin/bash

for i in {30..50}; do printf "\e[1;%im%i - text\e[0m\n" $i $i; done
