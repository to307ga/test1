#!/bin/bash

sleep 10
systemctl stop sshd.service
systemctl start sshd.socket

retern_value=$?

if [ $retern_value -ne 0 ]; then
    systemctl start sshd.service
fi
