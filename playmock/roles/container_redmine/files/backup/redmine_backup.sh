#!/usr/bin/env bash
# -- redmine_backup.sh
#    Redmine コンテナ データバックアップ
#
# Usage:
#    sudo /opt/containers/backup/redmine_backup.sh
#
# バックアップファイル格納先：
#    /db0/backups/redmine/
#        mysql-on-<HOSTNAME>-YYYYMMDD.sql.gz
#        redmine-data-on-<HOSTNAME>-YYYYMMDD.tar.gz
#
# 方式:
#    1. バックアップファイルの世代管理ローテーションを実施
#    2. DBコンテナ内 mysqldump コマンドを実行しDBのバックアップファイルを作成
#    3. DBバックアップファイルのサイズ比較でバックアップ不良を検出
#    4. ボリューム redmine_files 内のファイルをアーカイブしバックアップファイルを作成
#    5. データバックアップファイルのサイズ比較でバックアップ不良を検出
#       
#
# 注意:
#    このスクリプトは root 実行を想定しています。
# 追加情報:
#    バックアップファイルはサーバー間同期のため、オーナーを 'gooscp' に変更します。
#
set -u

### Begin -- setup environment

# overrideable settings
: "${MAX_AGE_DAYS:=5}"

# Suppress ShellCheck warnings (e.g. SC2034,SC1091) for the following { ... } block.
# The braces ensure the suppression applies only to this limited scope.
# shellcheck disable=SC2034
{
    LOG_TAGNAME="backup-redmine"
    CONTAINER_USER="container_user"
}
COMMAND_PATH=$(cd "$(dirname "$(realpath "$0")")" && pwd)
CONTAINER_HOME=$(cd "$(realpath "$COMMAND_PATH/..")" && pwd)
BACKUP_HOME=$(cd "$(realpath "$CONTAINER_HOME/backup")" && pwd)
LIB_PATH=$(cd "$(realpath "$CONTAINER_HOME/utils/lib")" && pwd)
# shellcheck disable=SC1091
{
    source "$LIB_PATH/journal.sh"
    source "$LIB_PATH/rotate_files.sh"
    source "$LIB_PATH/container_utils.sh"
}
### End -- setup environment

#
# Start
#
log_start

# backup information
MYHOST="$(hostname -s)"
BACKUP_DATE="$(date +%Y%m%d)"
CONTAINER_NAME="redminepod-redmine"
DB_CONTAINER_NAME="redminepod-redminedb"
REDMINE_DATA_VOLUME_NAME="redmine_files"
BACKUP_DB_FILE_PATTERN="mysql-on-*.sql.gz"
BACKUP_DATA_FILE_PATTERN="redmine-data-on-*.tar.gz"
BACKUP_FILE_OWNER=gooscp
BACKUP_DIR="/db0/backups/redmine"
FAILED_SIZE="1000k"

BACKUP_DB_FILE="mysql-on-$MYHOST-${BACKUP_DATE}.sql.gz"
BACKUP_DATA_FILE="redmine-data-on-$MYHOST-${BACKUP_DATE}.tar.gz"


#
# Step 1: Rotate old backup files
#
LOG_INFO=1 # 削除ログを残す for rotate_files

rotate_files "$BACKUP_DIR" "$BACKUP_DB_FILE_PATTERN" "$MAX_AGE_DAYS"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Backup file rotation failed: 'rotate_files $BACKUP_DIR $BACKUP_DB_FILE_PATTERN $MAX_AGE_DAYS'"
    # ローテーション失敗よりもバックアップを優先するため処理は続行する
fi

rotate_files "$BACKUP_DIR" "$BACKUP_DATA_FILE_PATTERN" "$MAX_AGE_DAYS"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Backup file rotation failed: 'rotate_files $BACKUP_DIR $BACKUP_DATA_FILE_PATTERN $MAX_AGE_DAYS'"
    # ローテーション失敗よりもバックアップを優先するため処理は続行する
fi

#
# Step 2: Execute DB backup operation inside the container
#
sudo -i -u "$CONTAINER_USER" podman exec -e MYSQL_PWD=rootpw "$DB_CONTAINER_NAME" \
    mysqldump \
    -u root \
    -F \
    --lock-all-tables \
    --add-drop-database \
    --databases db_redmine | gzip -c -9 > "$BACKUP_DIR/$BACKUP_DB_FILE" \
    2> >(log_error_stream)

result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: DB backup command failed inside container."
    success_db="false"
else
    success_db="true"
fi
# Change owner of the backup files in the backup directory
if [[ "$success_db" == "true" ]]; then
    chown "$BACKUP_FILE_OWNER":"$BACKUP_FILE_OWNER" "$BACKUP_DIR"/"$BACKUP_DB_FILE" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to change owner of DB backup file(s) in '$BACKUP_DIR/$BACKUP_DB_FILE'."
        success_db="false"
    fi
fi

#
# Step 3: DBバックアップファイルの低サイズ(作成失敗)検出
#
check_small_files "$BACKUP_DIR" "$BACKUP_DB_FILE_PATTERN" "$FAILED_SIZE"
result=${?:-}
if [[ $result -eq 2 ]]; then
    log_error "Error: Redmine DB backup anomaly detected."
    success_db="false"
fi

#
# Step 4: Execute file backup operation
#
# ※旧redmine環境のバックアップは ./redmine_files ディレクトリを対象としていましたが、
#   コンテナ統合以降は 'redmine_files' ボリュームディレクトリが redmine_files ディレクトリ
#   に相当するため、カレントディレクトリを指定する形に変更しています。
LOCAL_REDMINE_DATA_DIR=$(container_volume_mountpoint "$REDMINE_DATA_VOLUME_NAME")
if [[ -z "$LOCAL_REDMINE_DATA_DIR" ]]; then
    log_error "Error: Failed to retrieve Redmine data volume mountpoint."
    success="false"
else
    tar -C "$LOCAL_REDMINE_DATA_DIR" -czf "$BACKUP_DIR/$BACKUP_DATA_FILE" "./" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to backup Redmine data files."
        success="false"
    else
        success="true"
    fi
fi
# Change owner of the backup files in the backup directory
if [[ "$success" == "true" ]]; then
    chown "$BACKUP_FILE_OWNER":"$BACKUP_FILE_OWNER" "$BACKUP_DIR"/"$BACKUP_DATA_FILE" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to change owner of data backup file(s) in '$BACKUP_DIR/BACKUP_DATA_FILE'."
        success="false"
    fi
fi

#
# Step 5: データバックアップファイルの低サイズ(作成失敗)検出
#
# ※エラー時のメッセージは関数内で log_error 関数で出力される
check_small_files "$BACKUP_DIR" "$BACKUP_DATA_FILE_PATTERN" "$FAILED_SIZE"
result=${?:-}
if [[ $result -eq 2 ]]; then
    log_error "Error: Redmine data backup anomaly detected."
    success="false"
fi

#
# End
#
if [[ "$success" != "true" ]]; then
    log_error "Redmine data backup process failed."
fi

if [[ "$success_db" != "true" ]]; then
    log_error "Redmine DB backup process failed."
fi

log_end

# EOS
