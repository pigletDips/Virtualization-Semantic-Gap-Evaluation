#!/bin/bash
#sar -r 2 200 | awk '{print $4}' > 800-vm.log &
free -m -s 2 -c 200 | awk '/Mem/{print $3}' > 2vm-200-vm.log &
sleep 10
insmod spinlock.ko
./test
mv *.log ~/

