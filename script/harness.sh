#!/bin/bash

source env.sh

for i in 1 2 3
do
#       parsecmgmt -a run -p bodytrack -i native -n 8
        parsecmgmt -a run -p vips -i native -n 8
done


