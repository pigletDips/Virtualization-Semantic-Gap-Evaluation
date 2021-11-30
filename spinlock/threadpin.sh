#!/bin/bash
# Get the pid of threads
pid=`ps aux | grep spinlock | grep -v grep | awk '{print $2}'`

echo $pid

cpu=0
for i in $pid
do
	echo "pin $i to cpu $1"
	taskset -pc $1 $i
#	(( cpu++ ))
done

