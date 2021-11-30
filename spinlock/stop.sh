#!/bin/bash

if [[ -n `lsmod | grep spinlock` ]]; then
        sudo rmmod spinlock
        sleep 3
fi

sudo dmesg | grep SPIN > vm1.log


