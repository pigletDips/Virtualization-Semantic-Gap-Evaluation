#!/bin/bash

sudo dmesg -c

if [[ -n `lsmod | grep spinlock` ]]; then
#	echo "Please remove spinlock.ko first!"
#	exit 1
	sudo rmmod spinlock
	sleep 3
fi

make
sudo insmod spinlock.ko
./threadpin.sh 0-15

#sudo dmesg | grep SPIN > vm1.log


