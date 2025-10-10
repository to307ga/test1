# Redmine backupスクリプト

umask 077

MYHOST=$(hostname -s)
#REMOTE_HOST=gooid-30-dev-log-002
# dev-wev-201 で検証中なので他への影響を避ける
REMOTE_HOST=gooid-30-dev-web-201

DATE=$(date +%Y%m%d)
REDMINE_DB0=/db0/redmine_files
REDMINE_VAR=/var/redmine_files
REDMINE_TAR=redmine-data-on-$MYHOST-${DATE}.tar.gz

MYSQL_DIR=/db0/mysql
MYSQL_DUMP_DIR=/var/mysql
MYSQL_DUMP_FILE=${MYSQL_DUMP_DIR}/mysql-on-$MYHOST-${DATE}.sql
DAYS=30

# 送信前に古いsqlファイルを削除する
find ${MYSQL_DUMP_DIR} -type f -daystart -mtime +${DAYS} -name '*.sql.gz' -exec rm {} \;

# 送信前に古いRedmineの添付ファイルを削除する
find ${REDMINE_VAR} -type f -daystart -mtime +${DAYS} -name '*.tar.gz' -exec rm {} \;

# ローカルでmysqlのバックアップ
docker exec mymysql mysqldump -u backupuser -p{{ redmine.backup_password }} -F \
 --lock-all-tables --add-drop-database --databases db_redmine | gzip -c -9 > ${MYSQL_DUMP_FILE}.gz

# ローカルでのredmine_filesのバックアップ
tar -C /db0 -cvzf ${REDMINE_VAR}/${REDMINE_TAR} redmine_files

# logサーバにsqlファイルを転送する
rsync -avh --delete ${MYSQL_DUMP_DIR}/ rsync://${REMOTE_HOST}${MYSQL_DIR}/

# logサーバにredmine添付ファイルを転送する
rsync -avh --delete ${REDMINE_VAR}/ rsync://${REMOTE_HOST}${REDMINE_DB0}/
