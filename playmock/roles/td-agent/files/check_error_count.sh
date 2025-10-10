#!/bin/bash
# ---------------------------------
# check_error_count.sh
# check_error_count.sh arg1 arg2
# arg1: Referenced file name
# arg2: pattern (fluent-plugin-datacounter of pattern1 pattern2 ...)
#  
# ---------------------------------

filename=$1
name_key=${2}_count
name_key=${name_key}'":'


[ "$(find /db0/tdlogs/zabbix-sender-count/${filename}.`date +%Y-%m-%d`.log -mmin +5 | wc -l)" -eq 0 ] && \
tail -n 1 /db0/tdlogs/zabbix-sender-count/${filename}.`date +%Y-%m-%d`.log |\
awk -F''$name_key'' '{print $2}' |awk -F',' '{print $1}'

