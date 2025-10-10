#!/bin/bash

#2022/06/15:
## 試験時に生成された未来日付の強制解約者リストを
## メールシステムが誤って取り込んだことにより、
## 強制解約になったユーザーのメールの利用を停止できない事象が発生した
## 再発防止策として、fgwサーバー上に未来日のファイルが存在しないことを監視する


KEY="to_zabbix.prohibition.file.monitoring"
MY_HOSTNAME=$(hostname --fqdn)
ZABBIX_SERVERS="10.23.110.104:6951 10.23.110.105:6951"
LOG=/dev/null

DAYS_LATER_1=`date --date "1 days" "+%Y%m%d"`
DAYS_LATER_2=`date --date "2 days" "+%Y%m%d"`
DAYS_LATER_3=`date --date "3 days" "+%Y%m%d"`
DAYS_LATER_4=`date --date "4 days" "+%Y%m%d"`
DAYS_LATER_5=`date --date "5 days" "+%Y%m%d"`
DAYS_LATER_6=`date --date "6 days" "+%Y%m%d"`
DAYS_LATER_7=`date --date "7 days" "+%Y%m%d"`

MONTH_LATER_1=`date --date "next month" "+%Y%m"`

# 7日先までの未来日のファイルが存在しないことを確認する 
PROHIBITION_FILE_DAILY=`find /db0/www '(' \
-name *${DAYS_LATER_1}* -o \
-name *${DAYS_LATER_2}* -o \
-name *${DAYS_LATER_3}* -o \
-name *${DAYS_LATER_4}* -o \
-name *${DAYS_LATER_5}* -o \
-name *${DAYS_LATER_6}* -o \
-name *${DAYS_LATER_7}* \
')'`

# 来月の未来日のファイルが存在しないことを確認する
PROHIBITION_FILE_MONTHLY=`find /db0/www '(' \
-name *[^0-9]${MONTH_LATER_1}* \
')'`

if [ ${#PROHIBITION_FILE_DAILY} -ne 0 ] || [ ${#PROHIBITION_FILE_MONTHLY} -ne 0 ]; then
    VALUE="未来日のファイルが配置されています。削除してください。${MY_HOSTNAME}:${PROHIBITION_FILE_DAILY} ${PROHIBITION_FILE_MONTHLY}"
    for ZABBIX_SERVER in ${ZABBIX_SERVERS}
    do
        ZABBIX_HOST=$(echo ${ZABBIX_SERVER} | cut -d: -f1)
        ZABBIX_PORT=$(echo ${ZABBIX_SERVER} | cut -d: -f2)
        /usr/bin/zabbix_sender -vv -z ${ZABBIX_HOST} -p ${ZABBIX_PORT} -s "${MY_HOSTNAME}" -k ${KEY} -o "${VALUE}" >> ${LOG} 2>&1
    done
else

    for ZABBIX_SERVER in ${ZABBIX_SERVERS}
    do
        ZABBIX_HOST=$(echo ${ZABBIX_SERVER} | cut -d: -f1)
        ZABBIX_PORT=$(echo ${ZABBIX_SERVER} | cut -d: -f2)
        /usr/bin/zabbix_sender -vv -z ${ZABBIX_HOST} -p ${ZABBIX_PORT} -s "${MY_HOSTNAME}" -k ${KEY} -o "OK" >> ${LOG} 2>&1
    done
fi
