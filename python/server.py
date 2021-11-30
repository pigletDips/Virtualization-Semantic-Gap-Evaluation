#!/usr/bin/python

import sys
import os
import socket
import tcp_process

port = 8888

ss = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

ss.bind((str(socket.INADDR_ANY), port))
ss.listen(5)

"""
wait for vm1, vm2
"""
conn1, addr1 = ss.accept()
ack1 = conn1.recv(1024)
conn2, addr2 = ss.accept()
ack2 = conn2.recv(1024)

if cmp(ack1, "vm1") == 0:
    vm1conn = conn1
    vm1addr = addr1
    vm2conn = conn2
    vm2addr = addr2
elif cmp(ack1, "vm2") == 0:
    vm1conn = conn2
    vm1addr = addr2
    vm2conn = conn1
    vm2addr = addr1

print 'vm1:', vm1conn, vm1addr
print 'vm2:', vm2conn, vm2addr

tcp_process.process_server(vm1conn, vm2conn)


cmd = "scp ubuntu@" + vm1addr[0] + ":/home/ubuntu/HyperBench-H/spinlock/vm1.log ./"
print cmd
os.system(cmd)
cmd = "scp ubuntu@" + vm2addr[0] + ":/home/ubuntu/parsec-3.0/vm2.log ./"
print cmd
os.system(cmd)


ss.close()


