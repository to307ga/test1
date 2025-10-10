#!/usr/bin/env bash
# -- gitea_restore.sh
#    gitea コンテナのバックアップデータの同期（取得）とローカルコンテナへのデータのリストア
#
#    ※手動実行時に誤ってリストアしてしまうことを防ぐため、-y オプションの付与は
#      慎重に検討してください。-y を付けなければリストア実行前に確認プロンプトが表示されます。
#       
# Usage:
#    sudo /opt/containers/backup/gitea_restore.sh <SYNC_SOURCE_HOSTNAME> [OPTIONS]
#
#    SYNC_SOURCE_HOSTNAME: 同期元コンテナが稼働するホスト名（必須）
#    OPTIONS:
#      [-f FILE_VER | --file-ver=FILE_VER] : リストアしたいバックアップファイルのバージョン
#          FILE_VER: gitea の場合は EPOCHTIME タイムスタンプ `[0-9]{10,}`
#                   または 'latest' (最新ファイル：デフォルト)
#      [-y] : バックアップファイル同期後、データリストアを確認プロンプト無しで実行
#             (cron 等で自動実行する場合に指定)
#
#    実行例:
#      sudo /opt/containers/backup/gitea_restore.sh gitea-host1 -f latest
#        -> ローカルの gitea バックアップディレクトリを gitea-host1 と同期し、
#           最新ファイルでリストアを実行する。リストア前に確認プロンプトが表示される。
#
#      sudo /opt/containers/backup/gitea_restore.sh gitea-host1 --file-ver=1756888898 -y
#        -> ローカルの gitea バックアップディレクトリを gitea-host1 と同期し、
#           バックアップファイル gitea-dump-1756888898.zip からのリストアを実行する。
#           ローカルに指定したバックアップファイルが存在しない場合はエラーとなる。
#           リストア実行前の確認プロンプトは表示されない。
#
# バックアップファイル同期パス：
#    同期元：  <主稼働コンテナホスト名>:/db0/backups/gitea/
#                 gitea-dump-EPOCHTIME.zip
#    同期先：  <ローカル>:/db0/backups/gitea/
#
# 方式:
#    1. コマンドオプションの解析
#    2. 指定ホスト⇒ローカル方向でバックアップディレクトリの同期をとる
#    3. コンソール実行（または -y オプション無し）の場合、リストア実行の確認を行う
#    4. pod-giteapod サービスを停止する
#    5. バックアップ（zip）ファイルを gitea_backup ボリュームのマウントポイントに展開する
#    6. gitea_backup ボリュームに展開したファイルを gitea_data ボリュームのマウントポイント
#       にコピーし、UID,GIDを コンテナ内 gitユーザー に合わせる（データのリストア処理）
#       Volume: gitea_backup  ==>  gitea_data
#                    ./data/  ==>  ./gitea/
#                     ./log/  ==>  ./gitea/log/
#                                  chown -R 101000:101000 /gitea/
#                   ./repos/  ==>  ./git/repositories/
#                                  chown -R 101000:101000 /git/repositories/ 
#    7. gitea_backup ボリュームの展開結果に含まれるDBダンプファイルからDBデータをリストアする
#    8. pod-giteapod サービスを起動する
#    9. gitea_backup ボリュームに展開したファイルを全て削除する
#   10. 最後に gitea サービスの起動状態を確認する
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
#    '101000' とすることでコンテナ内 git ユーザーの所有とします。
#    ※UID/GIDはホスト：コンテナ間マッピングにより [ホスト側 100000]：[コンテナ内 1]
#      となります。コンテナ内の git ユーザーは UID/GID=1001 であるため、
#      コンテナホストから見ると '101000' に見えます。
#    リストアの成功/失敗に関わらず、gitea_backup ボリュームの全てのファイルを削除します。
#
set -u

# Setup environment -- Begin

# Suppress ShellCheck warnings (e.g. SC2034,SC1091) for the following { ... } block.
# The braces ensure the suppression applies only to this limited scope.
# shellcheck disable=SC2034
{
    LOG_TAGNAME="restore-gitea"
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
BACKUP_DIR="/db0/backups/gitea"
BACKUP_FILE_TEMPLATE="gitea-dump-EPOCHTIME.zip"
BACKUP_FILE_PATTERN='gitea-dump-*.zip'
BACKUP_FILE_OWNER=gooscp
SERVICE_NAME="pod-giteapod.service"
POD_NAME="giteapod"

GITEA_CONTAINER_NAME=giteapod-gitea
BACKUP_VOLUME_NAME="gitea_backup"
DATA_VOLUME_NAME="gitea_data"
HOST_SIDE_GIT_UID="101000"

DB_CONTAINER_NAME=giteapod-giteadb
DB_DATA_VOLUME_NAME="gitea_db_data"
HOST_SIDE_MYSQL_UID="100998"
CONTAINER_SIDE_DATA_DIR="/var/lib/mysql"
DB_DUMP_FILENAME="gitea-db.sql"

# Usage
function usage() {
    log_info "Usage: $0 <SYNC_SOURCE_HOSTNAME> [-f FILE_VER | --file-ver=FILE_VER] [-y]"
    log_info "  SYNC_SOURCE_HOSTNAME: 同期元コンテナが稼働するホスト名（必須）"
    log_info "  -f, --file-ver      : バックアップファイルバージョン (epoch time '^[0-9]{10,}$' または 'latest')"
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
if [[ "$FILE_VER" != "latest" && ! "$FILE_VER" =~ ^[0-9]{10,}$ ]]; then
    log_error "Error: Invalid file version format: $FILE_VER. Specify 'latest' or epoch time numbers." 
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
    restore_file_path=$( select_latest_file "$BACKUP_DIR" "$BACKUP_FILE_PATTERN" )
    restore_file_name=$(basename "$restore_file_path")
else
    restore_file_name="${BACKUP_FILE_TEMPLATE//EPOCHTIME/$FILE_VER}"
    restore_file_path="$BACKUP_DIR/$restore_file_name"
fi
# リストア対象ファイルの存在確認
if [[ ! -f "$restore_file_path" ]]; then
    log_error "Error: exit($result): No backup file found for restore: '$restore_file_path'."
    log_end_failed
fi


#
# Step 3: コンソール実行（または -y オプション無し）の場合、リストア実行の確認を行う
#
if [[ "$NO_CONSOLE" == "false" && "$CONFIRM" != "true" ]]; then
    read -r -p "ローカルの Gitea コンテナにバックアップファイル '$restore_file_name' をリストアします。本当によろしいですか？ [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || { echo "キャンセルしました。"; log_end ; exit 0; }
fi


#
# Step 4: pod-giteapod サービスを停止する
#         Pod の状態が不安定な場合、systemctl stop ではコンテナが停止しきらない場合があるため、
#         コンテナ停止も行う
service_stop "$SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to stop service '$SERVICE_NAME'."
    log_end_failed
fi
# gitea コンテナが起動したままなら停止する
container_exists "$GITEA_CONTAINER_NAME"
result=${?:-}
if [[ $result -eq 0 ]]; then
    log_debug "Container '$GITEA_CONTAINER_NAME' exists. Stop the container."
    container_stop "$GITEA_CONTAINER_NAME"
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: exit($result): Failed to stop the container '$GITEA_CONTAINER_NAME'."
        log_end_failed
    fi
fi
# DB コンテナが起動したままなら停止する
container_exists "$DB_CONTAINER_NAME"
result=${?:-}
if [[ $result -eq 0 ]]; then
    log_debug "Container '$DB_CONTAINER_NAME' exists. Stop the container."
    container_stop "$DB_CONTAINER_NAME"
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: exit($result): Failed to stop the container '$DB_CONTAINER_NAME'."
        log_end_failed
    fi
fi


#
# Step 5: バックアップ（zip）ファイルを gitea_backup ボリュームのマウントポイントに展開する
#
backup_volume_dir=$(container_volume_mountpoint "$BACKUP_VOLUME_NAME")
result=${?:-}
if [[ $result -ne 0 || -z "$backup_volume_dir" ]]; then
    log_error "Error: exit($result): Failed to get mountpoint of volume '$BACKUP_VOLUME_NAME'."
    log_end_failed
fi
# unzip -q: quiet mode
#       -o: overwrite files WITHOUT prompting
#       -X: restore UID/GID info
#       -d: extract file into exdir
unzip -q -o -X -d "$backup_volume_dir" "$restore_file_path" \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to unzip backup file '$restore_file_path' to volume directory '$backup_volume_dir' temporally."
    log_end_failed
fi


#
# Step 6: gitea_backup ボリュームに展開したファイルを gitea_data ボリュームの
#         マウントポイントにコピーする（データのリストア処理）
#         Volume: gitea_backup  ==>  gitea_data
#                      ./data/  ==>  ./gitea/
#                       ./log/  ==>  ./gitea/log/
#                                    chown -R 101000:101000 /gitea/
#                     ./repos/  ==>  ./git/repositories/
#                                    chown -R 101000:101000 /git/repositories/
# ※ディレクトリ単位のコピーに rsync を使う
#
data_volume_dir=$(container_volume_mountpoint "$DATA_VOLUME_NAME")
result=${?:-}
if [[ $result -ne 0 || -z "$data_volume_dir" ]]; then
    log_error "Error: exit($result): Failed to get mountpoint of volume '$DATA_VOLUME_NAME'."
    log_end_failed
fi

rsync -a "$backup_volume_dir/data/" "$data_volume_dir/gitea/"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to rsync data from '$backup_volume_dir/data/' to '$data_volume_dir/gitea/'."
    log_end_failed
fi

rsync -a "$backup_volume_dir/log/" "$data_volume_dir/gitea/log/"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to rsync data from '$backup_volume_dir/log/' to '$data_volume_dir/gitea/log/'."
    log_end_failed
fi

chown -R "$HOST_SIDE_GIT_UID":"$HOST_SIDE_GIT_UID" "$data_volume_dir/gitea"

rsync -a "$backup_volume_dir/repos/" "$data_volume_dir/git/repositories/"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to rsync data from '$backup_volume_dir/repos/' to '$data_volume_dir/git/repositories/'."
    log_end_failed
fi

chown -R "$HOST_SIDE_GIT_UID":"$HOST_SIDE_GIT_UID" "$data_volume_dir/git/repositories"


#
# Step 7: gitea_backup ボリュームの展開結果に含まれるDBダンプファイルからDBデータをリストアする
#
# gitea_db_data ボリュームのディレクトリ内を空にする
db_data_volume_dir=$(container_volume_mountpoint "$DB_DATA_VOLUME_NAME")
result=${?:-}
if [[ $result -ne 0 || -z "$db_data_volume_dir" ]]; then
    log_error "Error: exit($result): Failed to get mountpoint of volume '$DB_DATA_VOLUME_NAME'."
    log_end_failed
fi
rm -rf "${db_data_volume_dir:?}"/* \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to clear the DB data directory '$DB_DATA_VOLUME_NAME'."
    log_end_failed
fi
# DBダンプファイルをDBコンテナの/tmp/dump.sqlにコピーする
chown "$CONTAINER_USER":"$CONTAINER_USER" "$backup_volume_dir/$DB_DUMP_FILENAME"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to chown DB dump file on '$backup_volume_dir/$DB_DUMP_FILENAME'."
    log_end_failed
fi
container_copy "$backup_volume_dir/$DB_DUMP_FILENAME" "$DB_CONTAINER_NAME":"/tmp/dump.sql"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to cp DB dump file from '$data_volume_dir/$DB_DUMP_FILENAME' to '$DB_CONTAINER_NAME:/tmp/dump.sql'."
    log_end_failed
fi
# giteapod-giteadb コンテナを起動した後DBデータをリストアする
container_start "$DB_CONTAINER_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to start DB container '$DB_CONTAINER_NAME'."
    log_end_failed
fi
# DBコンテナの mysql コマンド実行の準備ができるまで待つ
container_wait_until_active "$DB_CONTAINER_NAME" "mysql -u gitea -pgitea gitea -e 'SELECT 1;'" 30 3
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to activate DB container '$DB_CONTAINER_NAME'."
    log_end_failed
fi

# DBリストア開始
params=(
    "-i"
    "-e" "MYSQL_PWD=gitea"
    "$DB_CONTAINER_NAME"
    "bash" "-c"
    "mysql --default-character-set=utf8mb4 -u gitea gitea < /tmp/dump.sql"
)
container_exec "${params[@]}"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to restore DB data from dump file '/tmp/dump.sql' inside contianer '$DB_CONTAINER_NAME'."
    log_end_failed
fi
# /tmp にコピーしたダンプファイルを削除する
params=(
    "$DB_CONTAINER_NAME"
    "bash" "-c"
    "rm -f /tmp/dump.sql"
)
container_exec "${params[@]}"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to delete temporally DB dump file '/tmp/dump.sql' inside container '$DB_CONTAINER_NAME'."
    log_end_failed
fi


#
# Step 8: pod-giteapod サービスを起動する
#         ※まず giteapod Pod を停止する。これでPodのステータスが Degraded から Exited に遷移し、
#           pod-giteapod サービスを停止した時点の状態に戻り、サービス起動が正常に行われる。
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
# Step 9: gitea_backup ボリュームに展開したファイルを全て削除する
#
if [[ -z "$backup_volume_dir" || ! -d "$backup_volume_dir" ]]; then
    log_error "Error: exit($result): Backup volume directory not found: '$backup_volume_dir'. Something went wrong. This script may contain bugs."
    log_end_failed
fi
rm -rf "${backup_volume_dir:?}"/* \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: exit($result): Failed to delete all files in volume directory '$backup_volume_dir' after restore."
    log_end_failed
fi


#
# Step 10: 最後に gitea サービスの起動状態を確認する
# 
service_is_active "$SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then        
    log_error "Error: exit($result): Gitea service '$SERVICE_NAME' is not active after service start."
    log_end_failed
fi

#
# End
#
log_end

# EOS
