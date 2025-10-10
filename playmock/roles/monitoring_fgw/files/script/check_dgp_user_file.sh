#!/bin/bash

#2022/07/06:
## 強制解約者リストが正常に出力されているかを確認するための監視スクリプト
## 強制解約者リストが毎月1日17：00までに出力されていない。またはファイル内容に問題がある場合、
## 以下のアラートが発火する
## Export DGP_USER_FILE is Error [Lv 1a]

## アラート受信後は以下のファイルを確認する
## gooid-21-pro-fgw-00x:gooid-21-pro-fgw/DGP/monthly/dgp_user_YYYYMMDDnn_ng.csv
## 実際に生成されていないまたは、内容に問題がある場合は
## 速やかにサービス担当へ一括課金結果の取り込み処理を停止するように連絡する
## goo課金利用サービス：ブログ、gooメール、GOT

DIR=/db0/www/DGP/monthly
DGP_NG_FILE=dgp_user_$(date '+%Y%m%d')??_ng.csv
DGP_CTL_FILE=dgp_user_$(date '+%Y%m%d')??_ctl.csv
THRESHOLD=30

HOSTNAME_FQDN=$(hostname --fqdn)
HOSTNAME=`hostname --short`
ZABBIX_AGENTD_CONF='/etc/zabbix/zabbix_agentd.conf'
ZABBIX_SERVERS=$( grep -v '^#' "${ZABBIX_AGENTD_CONF}" \
  | grep ServerActive \
  | sed -e 's/\s//g' -e 's/ServerActive=//g' -e 's/,/ /g' )
KEY="to_zabbix.dgp.user.file.monitoring"

MASTER=`/usr/sbin/pcs status | grep Masters | awk '{print $3}'`


# ZABBIX_SENDER関数
# 第1引数：ZABBIX送信メッセージ
function send_zabbix () {
  for ZABBIX_SERVER in ${ZABBIX_SERVERS}
  do
    ZABBIX_HOST=$(echo ${ZABBIX_SERVER} | cut -d: -f1)
    ZABBIX_PORT=$(echo ${ZABBIX_SERVER} | cut -d: -f2)
    VALUE="${VALUE}\n\nSent by ${HOSTNAME_FQDN}:$0"
    /usr/bin/zabbix_sender -vv -z ${ZABBIX_HOST} -p ${ZABBIX_PORT} -s "${HOSTNAME_FQDN}" -k ${KEY} -o "$1"
  done
}

if [[ "${MASTER}" != "${HOSTNAME}" ]]; then
  echo "HA構成のMASTER機ではないため確認処理は実施しません：MASTER=>${MASTER},HOST=>${HOSTNAME}"
  exit 0
fi

RES=`find $DIR -maxdepth 1 -name $DGP_NG_FILE 2> /dev/null`
if [ $? -ne 0 ]; then
  # 予期せぬエラーの場合
  VALUE="予期せぬエラーが発生しました。${HOSTNAME_FQDN}"
  send_zabbix $VALUE
  exit 1
elif [ -z "$RES" ]; then
  # 存在しない場合
  VALUE="強制解約者リストが生成されていません。${HOSTNAME_FQDN}:${DGP_NG_FILE}";
  send_zabbix $VALUE
  exit 1
elif  [ `cat ${RES} | wc -l` -lt ${THRESHOLD} ]; then
  # リストの行数が閾値以下だった場合
  VALUE="強制解約者リストが${THRESHOLD}行以下です。内容が正しいか確認してください。${HOSTNAME_FQDN}:${DGP_NG_FILE}";
  send_zabbix $VALUE
  exit 1
fi

RES=`find $DIR -maxdepth 1 -name $DGP_CTL_FILE 2> /dev/null`
if [ $? -ne 0 ]; then
  # 予期せぬエラーの場合
  VALUE="予期せぬエラーが発生しました。${HOSTNAME_FQDN}"
  send_zabbix $VALUE
  exit 1
elif [ -z "$RES" ]; then
  # 存在しない場合
  VALUE="強制解約者リストが生成されていません。${HOSTNAME_FQDN}:${DGP_CTL_FILE}";
  send_zabbix $VALUE
  exit 1
fi

# ファイルの正常性確認完了をzabbixへ通知する
VALUE="OK";
send_zabbix $VALUE
exit 0
