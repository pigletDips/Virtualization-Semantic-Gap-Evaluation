#!/usr/bin/python

from __future__ import print_function
import sys
import libvirt
from argparse import ArgumentParser
from optparse import OptionParser
import time

INFLATE = 0
STABLE = 1
DEFLATE = 2

class WSS:
    """
    Estimate the working set size (WSS) through virtio-balloon in the host.
    """
    maxmem = 0
    def __init__(self, domain):
        """
        Create a WSS instance.
        @domain: the VM being operated on

        self.__domain:  The name of the virtual machine.
        self.__conn:    The connection.
        self.__dom:     Lookup a domain on the given hypervisor based on its name. 
        self.__dominfo: The result 'virsh dominfo NAME'
        self.__maxmem:  The configured memory of the virtual machine. 
        """
        self.__balloon_state = STABLE
        self.__domain = domain
        conn = libvirt.open('qemu:///system')
        if conn == None:
            print('Failed to open connection to qemu:///system', file=sys.stderr)
            sys.exit(1)
        self.__conn = conn
        self.__dom = self.__conn.lookupByName(self.__domain)
        if self.__dom == None:
            print('Failed to find the domain '+domName, file=sys.stderr)
            sys.exit(1)
        self.__dominfo = self.__dom.info()
        self.maxmem = self.__dominfo[2]
        print("maxmem = ", self.maxmem)

    def __del__(self):
        self.__dom.setMemoryStatsPeriod(0)
        self.__conn.close() 

    def memStats(self):
        stats  = self.__dom.memoryStats()
        return stats
        
    def memShow(self, stats):
        print("Memory Statistics of", "[",self.__domain,"]")
#        print(stats)
        for name in stats:
            print("%-15s %15s" % (name,str(stats[name])))

    def setMem(self, size):
        ret = self.__dom.setMemory(size)
        return ret

    def setPeriod(self, period):
        ret = self.__dom.setMemoryStatsPeriod(period)
        return ret

if __name__ == '__main__':
    '''
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("domain")
    args = parser.parse_args()
    wss = WSS(args.domain)
    '''

    parser = OptionParser()
    parser.add_option('-n', '--name', dest='name', default='', help='The vitual machine name')
    def usage():
        parser.print_help()
        sys.exit(1)
    options, args = parser.parse_args()
    print("args = ",args)
    if len(args) > 0:
        usage()
    wss = WSS(options.name)
    
    print("maxmem = ",wss.maxmem)
#    sys.exit(1)

    wss.setPeriod(5)
    time.sleep(5)
    stats = wss.memStats()
    wss.memShow(stats)

    prev_swap_out = curr_swap_out = stats['swap_out']
    prev_usable = curr_usable = stats['usable']
    time.sleep(5)
    stat = wss.memStats()
    curr_swap_out = stats['swap_out']
    curr_usable = stats['usable']
    actual = stats['actual']

    if curr_swap_out <= prev_swap_out:
        wss.__balloon_state = INFLATE
    else:
        wss.__balloon_state = DEFLATE

    while 1:
        if wss.__balloon_state == INFLATE:
            print("INFLATE")
            if curr_usable > 256*1024:
                wss.__balloon_state = INFLATE
                actual = stats['actual'] - curr_usable + 200*1024
                wss.setMem(actual)
                time.sleep(10)
                stats = wss.memStats()
                prev_usable = curr_usable
                curr_usable = stats['usable']
            else:
                wss.__balloon_state = STABLE
            wss.memShow(stats)
        elif wss.__balloon_state == STABLE:
            print("STABLE")
            stats = wss.memStats()
            prev_usable = curr_usable
            curr_usable = stats['usable']
            prev_swap_out = curr_swap_out
            curr_swap_out = stats['swap_out']
            time.sleep(30)
            if curr_swap_out > prev_swap_out:
                wss.__balloon_state = DEFLATE
            # usable mememory increase implies memory free in guest
            elif curr_usable > 512*1024 and curr_swap_out <= prev_swap_out:
                wss.__balloon_state = INFLATE
            wss.memShow(stats)
        elif wss.__balloon_state == DEFLATE:
            print("DEFLATE")
            actual = wss.maxmem
            wss.setMem(actual)
            time.sleep(5)
            stats = wss.memStats()
            wss.__balloon_state = STABLE
            wss.memShow(stats)



