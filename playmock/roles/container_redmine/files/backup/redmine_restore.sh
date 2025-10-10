#!/usr/bin/env bash
# -- redmine_restore.sh
#    redmine コンテナのバックアップデータの同期（取得）とローカルコンテナへのデータのリストア
#
#    ※手動実行時に誤ってリストアしてしまうことを防ぐため、-y オプションの付与は
#      慎重に検討してください。-y を付けなければリストア実行前に確認プロンプトが表示されます。
#       
# Usage:
#    sudo /opt/containers/backup/redmine_restore.sh <SYNC_SOURCE_HOSTNAME> [OPTIONS]
#
#    SYNC_SOURCE_HOSTNAME: 同期元コンテナが稼働するホスト名（必須）
#    OPTIONS:
#      [-f FILE_VER | --file-ver=FILE_VER] : リストアしたいバックアップファイルのバージョン
#          FILE_VER: redmine の場合は日付書式 YYYYMMDD
#                   または 'latest' (最新ファイル：デフォルト)
#      [-y] : バックアップファイル同期後、データリストアを確認プロンプト無しで実行
#             (cron 等で自動実行する場合に指定)
#
#    実行例:
#      sudo /opt/containers/backup/redmine_restore.sh redmine-host1 -f latest
#        -> ローカルの redmine バックアップディレクトリを redmine-host1 と同期し、
#           最新ファイルでリストアを実行する。リストア前に確認プロンプトが表示される。
#
#      sudo /opt/containers/backup/redmine_restore.sh redmine-host1 --file-ver=20250901 -y
#        -> ローカルの redmine バックアップディレクトリを redmine-host1 と同期し、
#           バックアップファイル redmine-data-on-redmine-host1-20250901.tar.gz 及び
#           mysql-on-redmine-host1-20250901.sql.gz からのリストアを実行する。
#           ローカルに指定したバックアップファイルが存在しない場合はエラーとなる。
#           リストア実行前の確認プロンプトは表示されない。
#
# バックアップファイル同期パス：
#    同期元：  <主稼働コンテナホスト名>:/db0/backups/redmine/
#                 redmine-data-on-CONTAINER_HOSTNAME-YYYYMMDD.tar.gz
#                 mysql-on-CONTAINER_HOSTNAME-YYYYMMDD.sql.gz
#    同期先：  <ローカル>:/db0/backups/redmine/
#
# 方式:
#    1. コマンドオプションの解析
#    2. 指定ホスト⇒ローカル方向でバックアップディレクトリの同期をとる
#    3. コンソール実行（または -y オプション無し）の場合、リストア実行の確認を行う
#    4. pod-redminepod サービスを停止する
#    5. redmine-data バックアップ(tar.gz)ファイルを redmine_files ボリュームのマウントポイントに
#       展開し、UID,GIDを コンテナ内 redmineユーザーID(100998) に合わせる（データのリストア処理）
#    6. redminepod-redminedb コンテナを起動し、バックアップ(ダンプファイル)からDBデータをリストアする
#    7. pod-redminepod サービスを起動する
#    8. 最後に redmine サービスの起動状態を確認する
#
# 注意:
#    このスクリプトは root 実行を想定していますが、コンテナ操作関連処理は
#    lib/container_utils.sh 関数群で container_user 実行を想定しています。
#    ファイル/ディレクトリへのアクセスには container_user のアクセス権限が
#    必要です。
#    バックアップディレクトリの同期には lib/sync_files.sh 関数群を利用しています。
#    同期元ホストに対し root で SSH 接続できる必要があります。ssh コマンドの
#    StrictHostKeyChecking=no オプションは安全のため付与していません。したがって、
#    cron 設置する前にコンソールから実行し動作を確認してください。初回接続時は known_hosts 登録の
#    確認プロンプトが表示されますので受け入れてください。
#    もしくは事前に `sudo ssh <SYNC_SOURCE_HOST>` で接続し登録してください。
# 追加情報:
#    バックアップディレクトリはサーバー間で同一構成である必要があり、ディレクトリ名は固定です。
#    バックアップディレクトリ及びファイルはサーバー間同期のため、オーナーは 'gooscp' です。
#    データのリストア処理はコンテナホスト側で実行しますが、コピー先のファイルオーナー(UID,GID) は
#    '100988' とすることでコンテナ内 redmine ユーザーの所有とします。
#    ※UID/GIDはホスト：コンテナ間マッピングにより [ホスト側 100000]：[コンテナ内 1]
#      となります。コンテナ内の git ユーザーは UID/GID=999 であるため、
#      コンテナホストから見ると '100998' に見えます。
#
set -u

# Setup environment -- Begin

# Suppress ShellCheck warnings (e.g. SC2034,SC1091) for the following { ... } block.
# The braces ensure the suppression applies only to this limited scope.
# shellcheck disable=SC2034
{
    LOG_TAGNAME="restore-redmine"
    CONTAINER_USER="container_user"
}
COMMAND_PATH=$(cd "$(dirname "$(realpath "$0")")" && pwd)
CONTAINER_HOME=$(cd "$(realpath "$COMMAND_PATH/..")" && pwd)
LIB_PATH=$(cd "$(realpath "$CONTAINER_HOME/utils/lib")" && pwd)
# shellcheck disable=SC1091
{
    source "$LIB_PATH/journal.sh"
    source "$LIB_PATH/container_utils.sh"
    source "$LIB_PATH/sync_files.sh"
    source "$LIB_PATH/service_utils.sh"
}

# ログ出力先の決定： journald or stdout/stderr for journal.sh
if ! tty -s || [[ -z "${TERM:-}" ]]; then
    NO_CONSOLE="true"
    LOG_OUTPUT_MODE="journald"
else
    NO_CONSOLE="false"
    # shellcheck disable=SC2034
    LOG_OUTPUT_MODE="std"
fi
# Setup environment -- End

# restore information
FILE_VER='latest'
BACKUP_DIR="/db0/backups/redmine"
BACKUP_DATA_FILE_TEMPLATE="redmine-data-on-CONTAINERHOST-YYYYMMDD.tar.gz"
BACKUP_DATA_FILE_PATTERN='redmine-data-on-*.tar.gz'
BACKUP_DB_FILE_TEMPLATE="mysql-on-CONTAINERHOST-YYYYMMDD.sql.gz"
BACKUP_DB_FILE_PATTERN="mysql-on-*.sql.gz"
BACKUP_FILE_OWNER=gooscp
SERVICE_NAME="pod-redminepod.service"
POD_NAME="redminepod"

REDMINE_CONTAINER_NAME=redminepod-redmine
DATA_VOLUME_NAME="redmine_files"
HOST_SIDE_REDMINE_UID="100998"

DB_CONTAINER_NAME=redminepod-redminedb
DB_DATA_VOLUME_NAME="redmine_db_data"

# Usage
function usage() {
    log_info "Usage: $0 <SYNC_SOURCE_HOSTNAME> [-f FILE_VER | --file-ver=FILE_VER] [-y]"
    log_info "  SYNC_SOURCE_HOSTNAME: 同期元コンテナが稼働するホスト名（必須）"
    log_info "  -f, --file-ver      : バックアップファイルバージョン (YYYYMMDD または 'latest')"
    log_info "  -y                  : 確認プロンプト無しでリストアを実行"
    exit 1
}

function log_end_failed() {
    log_error "Restore process failed."
    log_end
    exit 1    
}

#
# Start
#
log_start

#
# Step 1: コマンドオプションの解析
#

# Option value defaults
FILE_VER="latest"
CONFIRM="false"

# Analyse options
SYNC_SOURCE_HOSTNAME="${1:-}"
if [[ -z "$SYNC_SOURCE_HOSTNAME" ]]; then
    log_error "Error: Sync source hostname is required."
    usage
fi
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file-ver)
            if [[ -n "${2:-}" ]]; then
                FILE_VER="$2"
                shift 2
            else
                log_error "Error: --file-ver requires an argument."
                usage
            fi
            ;;
        --file-ver=*)
            FILE_VER="${1#*=}"
            shift
            ;;
        -y)
            CONFIRM="true"
            shift
            ;;
        -*)
            log_error "Error: Unknown option $1"
            usage
            ;;
        *)
            log_error "Error: Unexpected argument $1"
            usage
            ;;
    esac
done


# オプション確認表示（デバッグ用）
# log_debug "SYNC_SOURCE_HOSTNAME : $SYNC_SOURCE_HOSTNAME"
# log_debug "FILE_VER : $FILE_VER"
# log_debug "CONFIRM  : $CONFIRM"


# FILE_VER の書式確認
if [[ "$FILE_VER" != "latest" && ! "$FILE_VER" =~ ^[0-9]{8}$ ]]; then
    log_error "Error: Invalid file version format: $FILE_VER. Specify 'latest' or date format 'YYYYMMDD'." 
    usage # display usage and exit
fi

#
# Step 2: 指定ホスト⇒ローカル方向でバックアップディレクトリの同期をとる
#
sync_directory "$SYNC_SOURCE_HOSTNAME:$BACKUP_DIR" "$BACKUP_DIR"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to sync backup directory from host '$SYNC_SOURCE_HOSTNAME'."
    log_end_failed
fi
# リストア対象のファイルを特定
if [[ "$FILE_VER" == "latest" ]]; then
    # 最新ファイルを特定
    restore_data_file_path=$(select_latest_file "$BACKUP_DIR" "$BACKUP_DATA_FILE_PATTERN")
    restore_data_file_name=$(basename "$restore_data_file_path")
    restore_db_file_path=$(select_latest_file "$BACKUP_DIR" "$BACKUP_DB_FILE_PATTERN")
    restore_db_file_name=$(basename "$restore_db_file_path")
else
    restore_data_file_name="${BACKUP_DATA_FILE_TEMPLATE//YYYYMMDD/$FILE_VER}"
    restore_data_file_name="${restore_data_file_name//CONTAINERHOST/$SYNC_SOURCE_HOSTNAME}"
    restore_data_file_path="$BACKUP_DIR/$restore_data_file_name"
    restore_db_file_name="${BACKUP_DB_FILE_TEMPLATE//YYYYMMDD/$FILE_VER}"
    restore_db_file_name="${restore_db_file_name//CONTAINERHOST/$SYNC_SOURCE_HOSTNAME}"
    restore_db_file_path="${BACKUP_DIR/$restore_db_file_name}"
fi
# リストア対象ファイルの存在確認
if [[ ! -f "$restore_data_file_path" ]]; then
    log_error "Error: exit($result): No data backup file found for restore: '$restore_data_file_path'."
    log_end_failed
fi
if [[ ! -f "$restore_db_file_path" ]]; then
    log_error "Error: exit($result): No DB backup file found for restore: '$restore_db_file_path'."
    log_end_failed
fi


#
# Step 3: コンソール実行（または -y オプション無し）の場合、リストア実行の確認を行う
#
if [[ "$NO_CONSOLE" == "false" && "$CONFIRM" != "true" ]]; then
    read -r -p "ローカルの redmine コンテナにバックアップファイル '$restore_data_file_name', '$restore_db_file_name' をリストアします。本当によろしいですか？ [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || { echo "キャンセルしました。"; log_end ; exit 0; }
fi


#
# Step 4: pod-redminepod サービスを停止する
#
service_stop "$SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to stop service '$SERVICE_NAME'."
    log_end_failed
fi


#
# Step 5: redmine-data バックアップ(tar.gz)ファイルを redmine_files ボリュームのマウントポイントに
#         展開し、UID,GIDを コンテナ内 redmineユーザーID(100998) に合わせる（データのリストア処理）
#
data_volume_dir=$(container_volume_mountpoint "$DATA_VOLUME_NAME")
result=${?:-}
if [[ $result -ne 0 || -z "$data_volume_dir" ]]; then
    log_error "Error: exit($result): Failed to get mountpoint of volume '$DATA_VOLUME_NAME'."
    log_end_failed
fi
tar -C "$data_volume_dir" -zxf  "$restore_data_file_path" \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to untar data backup file '$restore_data_file_path' to volume directory '$data_volume_dir'."
    log_end_failed
fi
chown -R "$HOST_SIDE_REDMINE_UID":"$HOST_SIDE_REDMINE_UID" "$data_volume_dir"


#
# Step 6: redminepod-redminedb コンテナを起動し、バックアップ(ダンプファイル)からDBデータをリストアする
#
container_start "$DB_CONTAINER_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to start DB container '$DB_CONTAINER_NAME'."
    log_end_failed
fi
# DBコンテナの mysql コマンド実行の準備ができるまで待つ
container_wait_until_active "$DB_CONTAINER_NAME" "mysql -u user_redmine -puserpw db_redmine -e 'SELECT 1;'"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to activate DB container '$DB_CONTAINER_NAME'."
    log_end_failed
fi

# DBリストア開始
params=(
    "-i"
    "-e" "MYSQL_PWD=userpw"
    "$DB_CONTAINER_NAME"
    "mysql"
    "-u" "user_redmine"
    "db_redmine"
)
zcat "$restore_db_file_path" | container_exec "${params[@]}"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to restore DB data from dump file '$restore_db_file_path' to contianer '$DB_CONTAINER_NAME'."
    log_end_failed
fi


#
# Step 7: pod-redminepod サービスを起動する
#         ※まず redminepod Pod を停止する。これでPodのステータスが Degraded から Exited に遷移し、
#           pod-redminepod サービスを停止した時点の状態に戻り、サービス起動が正常に行われる。
#
command_and_args=(
    "pod"
    "stop" "$POD_NAME"
)
container_ctl "${command_and_args[@]}"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to stop pod '$POD_NAME'."
    log_end_failed
fi

service_start "$SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to start service '$SERVICE_NAME'."
    log_end_failed
fi


#
# Step 8: 最後に redmine サービスの起動状態を確認する
# 
service_is_active "$SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then        
    log_error "Error: exit($result): redmine service '$SERVICE_NAME' is not active after service start."
    log_end_failed
fi

#
# End
#
log_end

# EOS
