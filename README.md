# Virtualization semantic gap evaluation tools
To evaluate the double scheduling problem in virtualization environment.
- spinlock: double scheduling evaluation program(kernel module).
- scripts: some scripts, including the HiKVMPerf developed by the Kunpeng community and other scripts used during experiments.
- communication: collect double scheduling evaluation program results from virtual machine.
- python: virtio-ballon based memory tuning strategy.
## spinlock
### Run spinlock benchmark in native environment
- collect results
```
tail -f /var/log/syslog > 2vm.log
```
- change to parsec3.0
```
./harness.sh
```
- change to spinlock/
```
./spinlock.sh
```





