#!/usr/bin/env bash
# -- gitea_backup.sh
#    Gitea コンテナ データバックアップ
#
# Usage:
#    sudo /opt/containers/backup/gitea_backup.sh
#
# バックアップファイル格納先：
#    /db0/backups/gitea/
#        gitea-dump-EPOCKTIME.zip
#
# 方式:
#    1. バックアップファイルの世代管理ローテーションを実施
#    2. コンテナ内 gitea dump コマンドを実行しバックアップファイルを作成
#       バックアップファイルはコンテナにマウントした 'gitea_backup'ボリュームに格納される
#    3. ボリューム 'gitea_backup' 内のバックアップファイルをコンテナホストの
#       バックアップディレクトリに移動し、バックアップファイルのオーナーを 'gooscp' に変更する
#    4. バックアップファイルのサイズ比較でバックアップ不良を検出
#
# 注意:
#    このスクリプトは root 実行を想定していますが、コンテナ操作関連処理は
#    lib/container_utils.sh 関数群で container_user 実行を想定しています。
#    ファイル/ディレクトリへのアクセスには container_user のアクセス権限が
#    必要です。
# 追加情報:
#    バックアップファイルはサーバー間同期のため、オーナーを 'gooscp' に変更します。
#    また、バックアップ処理はコンテナ内 git ユーザーで実行されるため、gitea_backup 
#    ボリュームの実DIRはオーナー(UID,GID) '101000' とする必要があります。
#    ※UID/GIDはホスト：コンテナ間マッピングにより [ホスト側 100000]：[コンテナ内 1]
#      となります。コンテナ内のgitユーザーは UID/GID=1001 であるため、
#      コンテナホストから見ると '101000' に見えます。
#    jenkins_backup ボリューム ディレクトリからのファイル移動はディレクトリ内の全ての
#    ファイルを対象とするため、rsync コマンドに --recursive オプションを指定しています。
#    これは処理不良等で過去のバックアップファイルを移動できなかった場合に備えた措置です。
#
set -u

### Begin -- setup environment

# overrideable settings
: "${MAX_AGE_DAYS:=5}"

# Suppress ShellCheck warnings (e.g. SC2034,SC1091) for the following { ... } block.
# The braces ensure the suppression applies only to this limited scope.
# shellcheck disable=SC2034
{
    LOG_TAGNAME="backup-gitea"
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
CONTAINER_NAME=giteapod-gitea
BACKUP_FILE_PATTERN='gitea-dump-*.zip'
BACKUP_FILE_OWNER=gooscp
BACKUP_VOLUME_NAME="gitea_backup"
BACKUP_DIR="/db0/backups/gitea"
FAILED_SIZE="1000k"


#
# Step 1: Rotate old backup files
#
LOG_INFO=1 # 削除ログを残す for rotate_files

rotate_files "$BACKUP_DIR" "$BACKUP_FILE_PATTERN" "$MAX_AGE_DAYS"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Backup file rotation failed: 'rotate_files $BACKUP_DIR $BACKUP_FILE_PATTERN $MAX_AGE_DAYS'"
    # ローテーション失敗よりもバックアップを優先するため処理は続行する
fi

#
# Step 2: Execute backup operation inside the container
#
params=(
    "--user" "git"
    "--workdir" "/backup"
    "$CONTAINER_NAME"
    "bash" "-c"
    '/app/gitea/gitea dump -c /data/gitea/conf/app.ini 2>&1'
)
container_exec "${params[@]}"
result=${?:-}
if [[ $result -ne 0 ]]; then
    log_error "Error: Backup command failed inside container: 'exec ${params[*]}'"
    success="false"
else
    success="true"
fi

#
# Step 3: Move backup file from volume to backup directory
#
if [[ "$success" == "true" ]]; then
    # Get local path of the volume
    LOCAL_BACKUP_DIR=$(container_volume_mountpoint "$BACKUP_VOLUME_NAME")
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to get mountpoint of volume '$BACKUP_VOLUME_NAME'."
        success="false"
    fi
fi
# Move files from volume to backup directory
# 'gitea_backup' ボリューム内のファイルを全て移動する。そのため --recursive オプションを指定する。
# 'gitea dump' コマンドはバックアップファイル名を特定できないのも理由の一つ。
if [[ "$success" == "true" ]]; then
    rsync_output=$( rsync \
        --recursive \
        --remove-source-files \
        --itemize-changes \
        "$LOCAL_BACKUP_DIR"/ \
        "$BACKUP_DIR"/ 2> >(log_error_stream) )
    
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to move backup file from volume '$BACKUP_VOLUME_NAME' to '$BACKUP_DIR'."
        success="false"
    fi
    files=$( echo "$rsync_output" | grep -c '^>' 2> >(log_error_stream) )
    if [[ $files -eq 0 ]]; then
        log_info "Error: No backup file moved from volume '$BACKUP_VOLUME_NAME' to '$BACKUP_DIR'. Parhaps backup command failed."
        success="false"
    fi
fi

# Change owner of the backup files in the backup directory
if [[ "$success" == "true" ]]; then
    chown -R "$BACKUP_FILE_OWNER":"$BACKUP_FILE_OWNER" "$BACKUP_DIR" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to change owner of backup file(s) in '$BACKUP_DIR'."
        success="false"
    fi
fi


#
# Step 4: 低サイズ(作成失敗)検出
#
check_small_files "$BACKUP_DIR" "$BACKUP_FILE_PATTERN" "$FAILED_SIZE"
result=${?:-}
if [[ $result -eq 2 ]]; then
    log_error "Error: Backup anomaly detected."
    success="false"
fi

#
# End
#
if [[ "$success" != "true" ]]; then
    log_error "Backup process failed."
fi

log_end

# EOS
