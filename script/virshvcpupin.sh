#!/bin/bash

for i in $(seq 0 1 7)
do
	echo "Pin vcpu$i"
	virsh vcpupin $1 $i 0-7 --live
done


