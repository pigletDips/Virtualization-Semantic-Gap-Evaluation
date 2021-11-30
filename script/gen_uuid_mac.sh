#!/bin/bash
uuidgen
#openssl rand -hex 6 | sed -r 's/..\B/&:/g'
echo $RANDOM | md5sum | sed 's/\(..\)/&:/g' | cut -c1-17

