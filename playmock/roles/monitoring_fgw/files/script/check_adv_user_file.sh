#!/bin/bash

#2022/07/06:
## アドバンス有効会員リストが正常に出力されているかを確認するための監視スクリプト
## アドバンス有効会員リスト生成が3日07：00までに出力されていない場合、
## 以下のアラートが発火する
## Export ADV_USER_FILE is Error [Lv 1a]

## アラート受信後は以下のファイルを確認する
## gooid-21-pro-fgw-00x:/db0/www/adv/adv_user_YYYYMM.csv
## 実際に生成されていないまたは、内容に問題がある場合は
## 速やかにブログ担当へ一括課金結果の取り込み処理を停止するように連絡する

ADV_USER_FILE="/db0/www/adv/adv_user_`date -d '1 month ago' +'%Y%m'`.csv"
THRESHOLD=10000
HOSTNAME_FQDN=$(hostname --fqdn)
HOSTNAME=`hostname --short`
ZABBIX_AGENTD_CONF='/etc/zabbix/zabbix_agentd.conf'
ZABBIX_SERVERS=$( grep -v '^#' "${ZABBIX_AGENTD_CONF}" \
  | grep ServerActive \
  | sed -e 's/\s//g' -e 's/ServerActive=//g' -e 's/,/ /g' )
KEY="to_zabbix.adv.user.file.monitoring"

VALUE="OK";
MASTER=`/usr/sbin/pcs status | grep Masters | awk '{print $3}'`

if [[ "${MASTER}" != "${HOSTNAME}" ]]; then
  echo "HA構成のMASTER機ではないため確認処理は実施しません：MASTER=>${MASTER},HOST=>${HOSTNAME}"
  exit
fi

if [ ! -f ${ADV_USER_FILE} ] ; then
  VALUE="アドバンス有効会員リストが生成されていません。${HOSTNAME_FQDN}:${ADV_USER_FILE}"
elif [ `cat  ${ADV_USER_FILE} | wc -l` -lt ${THRESHOLD} ]; then
  VALUE="アドバンス有効会員リストが${THRESHOLD}行以下です。内容が正しいか確認してください。${HOSTNAME_FQDN}:${ADV_USER_FILE}"
fi

for ZABBIX_SERVER in ${ZABBIX_SERVERS}
do
  ZABBIX_HOST=$(echo ${ZABBIX_SERVER} | cut -d: -f1)
  ZABBIX_PORT=$(echo ${ZABBIX_SERVER} | cut -d: -f2)
  VALUE="${VALUE}\n\nSent by ${HOSTNAME_FQDN}:$0"
  /usr/bin/zabbix_sender -vv -z ${ZABBIX_HOST} -p ${ZABBIX_PORT} -s "${HOSTNAME_FQDN}" -k ${KEY} -o "${VALUE}" > /dev/null 2>&1
done
