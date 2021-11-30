# Virtualization semantic gap evaluation tools
To evaluate the double scheduling problem in virtualization environment.

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





