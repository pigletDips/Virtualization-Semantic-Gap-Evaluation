"""
+---------+           +---------+            +---------+
|   vm1   |           |   host  |            |   vm2   |
+----+----+           +----+----+            +----+----+
     |                     |                      |
     +---------vm1-------->|<--------vm2----------+
     |                     |                      |
     |<-------start--------+--------start-------->|
     |                     |                      |
     +--------ack1-------->|<-------ack2----------+
     |                     |                      |
     +-------finish------->|<-------finish--------+
     |                     |                      |
     |<--------stop--------+---------stop-------->|
     |                     |                      |
     +--------ack1-------->|<--------ack2---------+
     |                     |                      |
     +-------finish------->|<-------finish--------+
     |                     |                      |
     |                     |                      |
                                                  
"""                        

import os

def process_server(vm1conn, vm2conn):
    cmd = "start"
    vm1conn.send(cmd)
    print vm1conn.recv(1024)
    vm2conn.send(cmd)
    print vm2conn.recv(1024)

    ack1 = vm1conn.recv(1024)
    print ack1
    ack2 = vm2conn.recv(1024)
    print ack2

    if(ack1.find("finished") >= 0 and ack2.find("finished")):
        vm1conn.send("stop")
        print vm1conn.recv(1024)
        print vm1conn.recv(1024)
        vm2conn.send("stop")
        print vm2conn.recv(1024)
        print vm2conn.recv(1024)



def process_client(sc, current):
    while 1:
        cmd = sc.recv(1024)
        if cmd:
            ack = current + " received: " + cmd
            sc.send(ack)
        print "vm = ", current
        if cmp(current, "vm1") == 0:
            if cmp(cmd, "start") == 0:
                os.system("sudo ./spinlock.sh")
                sc.send("vm1 finished")
            elif cmp(cmd, "stop") == 0:
                os.system("./stop.sh")
                sc.send("vm1 stop")
                break
            else:
                pass
        elif cmp(current, "vm2") == 0:
            if cmp(cmd, "start") == 0:
                os.system("./harness.sh 8 > vm2.log")
                sc.send("vm2 finished")
            elif cmp(cmd, "stop") == 0:
                sc.send("vm2 stop")
                break
            else:
                pass
        else:
            pass



