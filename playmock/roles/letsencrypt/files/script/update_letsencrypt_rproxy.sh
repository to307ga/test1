#!/bin/bash

# ACTIVE-STANDBY構成におけるLetsEncrypt証明書更新スクリプト
# ACTIVEにて取得したLetsEncrypt証明書をSTANDBY機に転送する
# SSL証明書の取得結果をzabbixに送信し、失敗した場合はアラートを発火させる
# 第1引数：LetsEncryptSSL証明書を取得するドメイン
# 第2引数：実行環境(pro/dev)

# 対象ドメイン
DOMAIN=$1;
#LetsEncrypt関連のお知らせ受信メールアドレス
EMAIL="idservice@nttr.co.jp";
# ホスト名
HOST_NAME=`curl http://$DOMAIN/host.html`
HOSTNAME_FQDN=$(hostname --fqdn)
# 証明書転送用ユーザー
SEND_USER="gooscp"
# ssl証明書配置パス
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/"
# ZABBIX送信メッセージ
ZABBIX_MSG="success:$DOMAIN"
# ZABBIX監視アイテムキー
ZABBIX_KEY="to_zabbix.update_letsencrypt_ssl.monitoring"
# ZABBIX_AGENTコンフィグファイル
ZABBIX_AGENTD_CONF='/etc/zabbix/zabbix_agentd.conf'
# 送信先ZABBIXサーバー
ZABBIX_SERVERS=$( grep -v '^#' "${ZABBIX_AGENTD_CONF}" \
  | grep ServerActive \
  | sed -e 's/\s//g' -e 's/ServerActive=//g' -e 's/,/ /g' )

# 環境ごとのパラメータを設定する
if [[ $2 == "pro" ]]; then
  SUFFIX_NUM_1="001"
  SUFFIX_NUM_2="002"
elif [[ $2 == "dev" ]]; then
  SUFFIX_NUM_1="101"
  SUFFIX_NUM_2="201"
else
  ZABBIX_MSG="第2引数は[pro|dev]で指定してください:$DOMAIN"
  send_zabbix $ZABBIX_MSG
  exit 1
fi

# ZABBIX_SENDER関数
# 第1引数：ZABBIX送信メッセージ
function send_zabbix () {
  for ZABBIX_SERVER in ${ZABBIX_SERVERS}
  do
    ZABBIX_HOST=$(echo ${ZABBIX_SERVER} | cut -d: -f1)
    ZABBIX_PORT=$(echo ${ZABBIX_SERVER} | cut -d: -f2)
    zabbix_sender -vv -z ${ZABBIX_HOST} -p ${ZABBIX_PORT} -s "${HOSTNAME_FQDN}" -k ${ZABBIX_KEY} -o "$1" > /dev/null 2>&1
  done
}

# LBへの接続状況確認
if [[ $HOST_NAME != `hostname -s` ]]; then
  ZABBIX_MSG="success:STANDBY機であるため何もせず処理を終了します:$DOMAIN"
  send_zabbix $ZABBIX_MSG
  exit 0
fi

# letsencriptの証明書配置用資材の所有権を変更
chown -R $SEND_USER. /etc/letsencrypt/
chown -R $SEND_USER. /var/log/letsencrypt/
chown -R $SEND_USER. /var/lib/letsencrypt
chown -R $SEND_USER. /var/www/html/letsencrypt

# letsencriptの証明書を更新する
sudo -u $SEND_USER certbot certonly --agree-tos --webroot -w "/var/www/html/letsencrypt" -d "$DOMAIN" -m "$EMAIL" --force-renew

# letsencriptの証明書取得が失敗した場合は強制終了。
CERT_FILE_TIMESTAMP=`date '+%Y/%m/%d' -r ${CERT_PATH}cert.pem`
TODAY=`date '+%Y/%m/%d'`
if [ $CERT_FILE_TIMESTAMP != $TODAY ]; then
  ZABBIX_MSG="アクティブ機のletsencript証明書取得に失敗したため強制終了します:$HOST_NAME:$DOMAIN"
  send_zabbix $ZABBIX_MSG
  exit 1
fi

# 更新した証明書を読み込み
systemctl reload httpd

# reloadが失敗した場合は処理を強制終了
if [ $? -ne 0 ]; then
  ZABBIX_MSG="アクティブ機のhttpdのreloadに失敗したため強制終了します:$HOST_NAME:$DOMAIN"
  send_zabbix $ZABBIX_MSG
  exit 1
fi

# スタンバイ機のHOST名取得
if [[ $HOST_NAME == *-$SUFFIX_NUM_1 ]]; then
  STANDBY_HOST=`echo ${HOST_NAME::${#HOST_NAME}-3}$SUFFIX_NUM_2`
else
  STANDBY_HOST=`echo ${HOST_NAME::${#HOST_NAME}-3}$SUFFIX_NUM_1`
fi

# スタンバイ機にLetsEncrypt証明書配置用のディレクトリがなければ作成する
if [ $(sudo -u $SEND_USER ssh $SEND_USER@$STANDBY_HOST "[ -d $CERT_PATH ];echo \$?") -ne 0 ]; then
  echo "ディレクトリが存在しないため、新規に作成しました。：$STANDBY_HOST:$CERT_PATH"
  sudo -u $SEND_USER ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SEND_USER@$STANDBY_HOST mkdir -p $CERT_PATH
fi

# 所有者を変更SENDユーザーに変更する
sudo -u $SEND_USER ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SEND_USER@$STANDBY_HOST sudo chown -R $SEND_USER. /etc/letsencrypt

# スタンバイ機にLetsEncrypt証明書を転送する
sudo -u $SEND_USER scp $CERT_PATH/cert.pem $SEND_USER@$STANDBY_HOST:$CERT_PATH
sudo -u $SEND_USER scp $CERT_PATH/chain.pem $SEND_USER@$STANDBY_HOST:$CERT_PATH
sudo -u $SEND_USER scp $CERT_PATH/fullchain.pem $SEND_USER@$STANDBY_HOST:$CERT_PATH
sudo -u $SEND_USER scp $CERT_PATH/privkey.pem $SEND_USER@$STANDBY_HOST:$CERT_PATH

# STANDBY機のhttpdをreloadする
sudo -u $SEND_USER ssh $SEND_USER@$STANDBY_HOST sudo systemctl reload httpd

if [ $? -ne 0 ]; then
    ZABBIX_MSG="STANDBY機のhttpdのreloadに失敗しました:$STANDBY_HOST:$DOMAIN"
    send_zabbix $ZABBIX_MSG
    exit 1
fi

# ZABBIXへ正常終了を通知する
send_zabbix $ZABBIX_MSG
