#!/bin/bash

mkdir -p tmp

for ip in "$@"; do
  nohup bash -c "ping $ip | while read pong; do
    echo \"\$(date): \$pong\";
  done > tmp/$ip.ping 2>&1" >/dev/null 2>&1 &
done
