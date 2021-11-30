#!/bin/bash
# put this file under /usr/bin/
set -o xtrace

out=`ps aux |  grep "$@" | grep -v "nkill" | grep -v grep | wc -l`
if [[ $out -gt 0 ]]; then
     ps aux | grep "$@" | grep -v "nkill" | grep -v grep | awk '{print $2}' | xargs -i kill -9 {}
fi

set +o xtrace
