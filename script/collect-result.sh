#!/bin/bash

# save the cycles from dmesg 
sudo dmesg | grep SPIN | awk '{print $5}' > $1
cat $1 | awk '{if($1 > 500000) {print $1}}'



