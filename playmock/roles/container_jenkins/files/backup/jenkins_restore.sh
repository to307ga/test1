#!/usr/bin/env bash
# -- jenkins_restore.sh
#    jenkins コンテナのバックアップデータの同期（取得）とローカルコンテナへのデータのリストア
#
#    ※手動実行時に誤ってリストアしてしまうことを防ぐため、-y オプションの付与は
#      慎重に検討してください。-y を付けなければリストア実行前に確認プロンプトが表示されます。
#       
# Usage:
#    sudo /opt/containers/backup/jenkins_restore.sh <SYNC_SOURCE_HOSTNAME> [OPTIONS]
#
#    SYNC_SOURCE_HOSTNAME: 同期元コンテナが稼働するホスト名（必須）
#    OPTIONS:
#      [-h HOSTNAME | --host=HOSTNAME] : 同期元コンテナホスト名
#      [-f FILE_VER | --file-ver=FILE_VER] : リストアしたいバックアップファイルのバージョン
#          FILE_VER: jenkins の場合は日付書式 YYYY-MM-DD
#                   または 'latest' (最新ファイル：デフォルト)
#      [-y] : バックアップファイル同期後、データリストアを確認プロンプト無しで実行
#             (cron 等で自動実行する場合に指定)
#
#    実行例:
#      sudo /opt/containers/backup/jenkins_restore.sh jenkins-host1 -f latest
#        -> ローカルの jenkins バックアップディレクトリを jenkins-host1 と同期し、
#           最新ファイルでリストアを実行する。リストア前に確認プロンプトが表示される。
#
#      sudo /opt/containers/backup/jenkins_restore.sh jenkins-host1 --file-ver=2025-01-15 -y
#        -> ローカルの jenkins バックアップディレクトリを jenkins-host1 と同期し、
#           バックアップファイル jenkins-backup-2025-01-15.tar.gz からのリストアを実行する。
#           ローカルに指定したバックアップファイルが存在しない場合はエラーとなる。
#           リストア実行前の確認プロンプトは表示されない。
#
# バックアップファイル同期パス：
#    同期元：  <主稼働コンテナホスト名>:/db0/backups/jenkins/
#                 jenkins-backup-YYYY-MM-DD.tar.gz
#    同期先：  <ローカル>:/db0/backups/jenkins/
#
# 方式:
#    1. コマンドオプションの解析
#    2. 指定ホスト⇒ローカル方向でバックアップディレクトリの同期をとる
#    3. コンソール実行（または -y オプション無し）の場合、リストア実行の確認を行う
#    4. バックアップ（アーカイブ）ファイルをコンテナ内 /backup としてマウントした
#       jenkins_backup ボリュームにコピーする
#    5. コンテナ内で /backup のアーカイブファイルを /var/jenkins_home に展開する（これがリストア処理）
#       展開完了後 jenkins_backup ボリューム内の全てのファイルを削除する
#    6. jenkins サービスを再起動する
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
#    また、リストア処理はコンテナ内 jenkins ユーザーで実行されるため、jenkins_backup 
#    ボリュームの実DIRはオーナー(UID,GID) '100999' とする必要があります。
#    ※UID/GIDはホスト：コンテナ間マッピングにより [ホスト側 100000]：[コンテナ内 1]
#      となります。コンテナ内の jenkins ユーザーは UID/GID=1000 であるため、
#      コンテナホストから見ると '100999' に見えます。
#    最後に、リストアの成功/失敗に関わらず、jenkins_backup ボリュームのファイルを全て削除します。
#
set -u

# Setup environment -- Begin

# Suppress ShellCheck warnings (e.g. SC2034,SC1091) for the following { ... } block.
# The braces ensure the suppression applies only to this limited scope.
# shellcheck disable=SC2034
{
    LOG_TAGNAME="restore-jenkins"
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


# Usage
function usage() {
    log_info "Usage: $0 <SYNC_SOURCE_HOSTNAME> [-f FILE_VER | --file-ver=FILE_VER] [-y]"
    log_info "  SYNC_SOURCE_HOSTNAME: 同期元コンテナが稼働するホスト名（必須）"
    log_info "  -f, --file-ver      : バックアップファイルバージョン (YYYY-MM-DD または 'latest')"
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

# restore information
CONTAINER_NAME=jenkins
FILE_VER='latest'
BACKUP_FILE_TEMPLATE="jenkins-backup-YYYY-MM-DD.tar.gz"
BACKUP_FILE_PATTERN='jenkins-backup-*.tar.gz'
BACKUP_FILE_OWNER=gooscp
HOST_SIDE_JENKINS_USER_ID="100999"
BACKUP_VOLUME_NAME="jenkins_backup"
BACKUP_DIR="/db0/backups/jenkins"
JENKINS_SERVICE_NAME="podman-compose-jenkins.service"
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
if [[ "$FILE_VER" != "latest" && ! "$FILE_VER" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    log_error "Error: Invalid file version format: $FILE_VER. Specify 'latest' or date format 'YYYY-MM-DD'." 
    usage # display usage and exit
fi

#
# Step 2: 指定ホスト⇒ローカル方向でバックアップディレクトリの同期をとる
#

sync_directory "$SYNC_SOURCE_HOSTNAME:$BACKUP_DIR" "$BACKUP_DIR"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Failed to sync backup directory from host '$SYNC_SOURCE_HOSTNAME'."
    log_end_failed
fi
# リストア対象のファイルを特定
if [[ "$FILE_VER" == "latest" ]]; then
    # 最新ファイルを特定
    restore_file_path=$( select_latest_file "$BACKUP_DIR" "$BACKUP_FILE_PATTERN" )
    restore_file_name=$(basename "$restore_file_path")
else
    restore_file_name="${BACKUP_FILE_TEMPLATE//YYYY-MM-DD/$FILE_VER}"
    restore_file_path="$BACKUP_DIR/$restore_file_name"
fi
# リストア対象ファイルの存在確認
if [[ ! -f "$restore_file_path" ]]; then
    log_error "Error: No backup file found for restore: '$restore_file_path'."
    log_end_failed
fi


#
# Step 3: コンソール実行（または -y オプション無し）の場合、リストア実行の確認を行う
#
if [[ "$NO_CONSOLE" == "false" && "$CONFIRM" != "true" ]]; then
    read -r -p "ローカルの Jenkins コンテナにバックアップファイル '$restore_file_name' をリストアします。本当によろしいですか？ [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || { echo "キャンセルしました。"; log_end ; exit 0; }
fi

log_debug "Restoring backup file '$restore_file_name' to Jenkins container..."

#
# Step 4: バックアップ（アーカイブ）ファイルをコンテナ内 /backup としてマウントした
#         jenkins_backup ボリュームにコピーする
#
backup_volume_dir=$(container_volume_mountpoint "$BACKUP_VOLUME_NAME")
result=${?:-}
if [[ $result -ne 0 || -z "$backup_volume_dir" ]]; then
    log_error "Error: Failed to get mountpoint of volume '$BACKUP_VOLUME_NAME'."
    log_end_failed
fi
# バックアップファイルをコピーする
cp "$restore_file_path" "$backup_volume_dir/" \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Failed to copy backup file '$restore_file_path' to volume directory '$backup_volume_dir'."
    log_end_failed
fi
# ファイルのオーナーを '100999' に変更する
chown "$HOST_SIDE_JENKINS_USER_ID":"$HOST_SIDE_JENKINS_USER_ID" "$backup_volume_dir/$restore_file_name" \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Failed to change owner of file '$backup_volume_dir/$restore_file_name' to '$HOST_SIDE_JENKINS_USER_ID'."
    log_end_failed
fi

#
# Step 5: コンテナ内で /backup のアーカイブファイルを /var/jenkins_home/ に展開する（リストア処理のメイン）
#         展開完了後 jenkins_backup ボリューム内の全てのファイルを削除する
#
params=("$CONTAINER_NAME" tar zxf "/backup/$restore_file_name" -C "/var/jenkins_home")
container_exec "${params[@]}"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Restore command failed inside container: 'exec ${params[*]}'"
fi
# jenkins_backup ボリューム内の全てのファイルを削除する
# ※リストアに失敗した場合に不要なファイルが残ってしまう場合に備えた措置
if [[ -z "$backup_volume_dir" || ! -d "$backup_volume_dir" ]]; then
    log_error "Error: Backup volume directory not found: '$backup_volume_dir'."
    log_end_failed
fi
rm -f "$backup_volume_dir"/* \
    1> >(log_info_stream) \
    2> >(log_error_stream)
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Failed to delete all files in volume directory '$backup_volume_dir' after restore."
    log_end_failed
fi

#
# Step 6: jenkins サービスを再起動する
#
service_restart "$JENKINS_SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then        
    log_error "Error: Failed to restart jenkins service."
    log_end_failed
fi
# Restart コマンドはサービスの状態に関わらず成功するため、再起動後に状態を確認する
service_wait_until_active "$JENKINS_SERVICE_NAME"
result=${?:-}
if [[ $result -ne 0 ]]; then        
    log_error "Error: Failed to activate jenkins service."
    log_end_failed
fi

log_debug "Restore completed successfully from backup file '$restore_file_name'."

#
# End
#
log_end

# EOS
