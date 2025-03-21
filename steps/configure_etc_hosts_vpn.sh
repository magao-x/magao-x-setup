#!/bin/bash
if ! grep -q exao1 /etc/hosts; then
    sudo tee /etc/hosts <<'HERE'
127.0.0.1      localhost localhost.localdomain localhost4 localhost4.localdomain4
::1            localhost localhost.localdomain localhost6 localhost6.localdomain6
100.64.0.4   exao1 aoc
100.64.0.3   exao2 rtc
100.64.0.2   exao3 icc
HERE
fi
