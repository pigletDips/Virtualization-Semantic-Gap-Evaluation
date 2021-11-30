#!/usr/bin/bash

import sys
import socket
import tcp_process

"""
    python client.py serverip vm1
    or
    python client.py serverip vm2
"""

serverip = str(sys.argv[1])
current = str(sys.argv[2])

sc = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
sc.connect((serverip, 8888))

sc.send(current)

tcp_process.process_client(sc, current)

sc.close()



