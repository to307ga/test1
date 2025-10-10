#!/usr/bin/env bash
# -- sync_files.sh
#    ファイル同期関連ヘルパー関数群
#
# 注意:
# このライブラリを読み込むスクリプトが root 実行されることを想定しています。
# ファイル同期は同期先ホスト(つまりこのスクリプトを実行する)から同期元ホストに対し
# SSH で接続し pull する前提です。ユーザーは 'gooscp' を想定しています。したがって、
# 指定する転送元ホストのユーザーおよびディレクトリのアクセス権、並びに転送先ディレクトリの
# アクセス権が 'gooscp' ユーザーにあるよう適切に設定されている必要があります。
# 'gooscp' ユーザー作成の責任は common ロールにあります。
# 同期ディレクトリに対する 'gooscp' ユーザーのアクセス権付与の責任はこのライブラリを
# 利用する側にあります（例： コンテナのバックアップデータを同期対象とする場合、
# container_gitea や container_jenkins など）
#
set -u

# guard: prevent multiple sourcing
if [ -n "${__MY_SYNC_LOADED+x}" ]; then
  return 0
fi
__MY_SYNC_LOADED=1
# setup environment
__MYLIB_PATH="${BASH_SOURCE[0]}"
__MYLIB_DIR="$(cd "$(dirname "$__MYLIB_PATH")" && pwd)"
# shellcheck disable=SC1091
source "$__MYLIB_DIR/journal.sh"

SYNC_USER="gooscp"  # 同期処理を実行するユーザー。同期対象ディレクトリに対するアクセス権が必要

# ensure_trainling_slash <path>
# Usage:
#    dir="/some/path"
#    dir="$(ensure_trailing_slash "$dir")"
#
# Return  末尾に'/'が付いたパス
#
function ensure_trailing_slash() {
    local path="${1:-}"
    [[ "$path" != */ ]] && path="$path/"
    echo "$path"
}

# sync_directory <src_dir> <dest_dir> [exclude_pattern] [include_pattern] [delete_extra:true]
#      src_dir:     同期元ディレクトリ (必須)
#      dest_dir:    同期先ディレクトリ (必須)
#      exclude_pattern: 除外パターン (rsync --exclude オプション
#      include_pattern: 含めるパターン (rsync --include オプション
#      delete_extra:   true:同期元に無いファイルを同期先から削除する(デフォルト)
#
function sync_directory() {
    local src_dir="${1:-}"
    local dest_dir="${2:-}"
    local exclude_pattern="${3:-}"
    local include_pattern="${4:-}"
    local delete_extra="${5:-true}"

    if [[ -z "$src_dir" || -z "$dest_dir" ]]; then
        log_error "Error: Missing required argument(s) in sync_directory function."
        return 1
    fi

    src_dir="$(ensure_trailing_slash "$src_dir")"
    dest_dir="$(ensure_trailing_slash "$dest_dir")"

    local rsync_opts=(--archive --partial --itemize-changes)
    if [[ "$delete_extra" == "true" ]]; then
        rsync_opts+=(--delete)  # delete files in dest not in src if specified
    fi
    if [[ -n "$exclude_pattern" ]]; then
        rsync_opts+=(--exclude="$exclude_pattern")
    fi
    if [[ -n "$include_pattern" ]]; then  
        rsync_opts+=(--include="$include_pattern")
    fi  
    rsync_opts+=("$src_dir" "$dest_dir")
    log_debug "Syncing from '$src_dir' to '$dest_dir'..." # 同期にかかる時間を見たいので開始～終了ログを出力する
    sudo -u "$SYNC_USER" rsync "${rsync_opts[@]}" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: rsync command failed during sync from '$src_dir' to '$dest_dir'."
        return 1
    fi
    log_debug "Sync completed successfully from '$src_dir' to '$dest_dir'."
    return 0
}


# select_latest_file <dir> <pattern>
#    dir:     検索対象ディレクトリ (必須)
#    pattern: 検索パターン (必須)
#
# Return  最新のファイル名 (フルパス)
#         見つからなかった場合は空文字列を返す
#
function select_latest_file() {
    local dir="${1:-}"
    local pattern="${2:-}"

    if [[ -z "$dir" || -z "$pattern" ]]; then
        log_error "Error: Missing required argument(s) in select_latest_file function."
        return 1
    fi

    local latest_file
    latest_file=$(
        find "$dir" \
          -maxdepth 1 \
          -type f \
          -name "$pattern" \
          -printf '%T@ %p\n' \
          2> >(log_error_stream) \
        | sort -n \
        | tail -1 \
        | cut -d' ' -f2-
    )
    result=${?:-}
    if [[ $result -ne 0 ]]; then
        log_error "Error: Failed to find files in directory '$dir' with pattern '$pattern'."
        return 1
    fi

    echo "${latest_file:-}"
    return 0
}


#
# --- Main: for testing directly via console.
#
if [[ "$(basename "$0")" == "sync_files.sh" ]]; then

    SRC_DIR=${1:-}
    DEST_DIR=${2:-}
    EXCLUDE_PATTERN=${3:-}
    INCLUDE_PATTERN=${4:-}
    DELETE_EXTRA=${5:-true}

    # shellcheck disable=SC2034
    LOG_OUTPUT_MODE="std"  # ログ出力先をコンソールに： stdout/stderr for journal.sh


    echo "Ensure trailing slash:"
    echo "  SRC_DIR='$SRC_DIR' -> '$(ensure_trailing_slash "$SRC_DIR")'"
    echo "  DEST_DIR='$DEST_DIR' -> '$(ensure_trailing_slash "$DEST_DIR")'"

    echo "Starting sync..."
    sync_directory "$SRC_DIR" "$DEST_DIR" "$EXCLUDE_PATTERN" "$INCLUDE_PATTERN" "$DELETE_EXTRA"

    latest_file=$(select_latest_file "$DEST_DIR" "*")
    echo "Latest file: ${latest_file}"

fi

# EOS
