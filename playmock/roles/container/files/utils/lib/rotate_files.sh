#!/usr/bin/env bash
# -- rotate_files.sh
#    ・世代管理 - 指定日数より古いファイルは削除する
#    ・処理不良によるバックアップ喪失を防ぐ - バックアップファイルが削除対象でも指定数より少なくしない
#
set -u

# guard: prevent multiple sourcing
if [ -n "${__ROTATE_FILES_LOADED+x}" ]; then
  return 0
fi
__ROTATE_FILES_LOADED=1
# setup environment
__MYLIB_PATH="${BASH_SOURCE[0]}"
__MYLIB_DIR="$(cd "$(dirname "$__MYLIB_PATH")" && pwd)"
# shellcheck disable=SC1091
source "$__MYLIB_DIR/journal.sh"

#
# Constants
#
DEFAULT_MAX_AGE_DAYS=7 # 実行日から指定日以上古いファイルは削除する
MIN_RETAINED_FILES=1   # 全ファイル喪失を防ぐため MAX_AGE_DAYS より古くても残しておきたいファイル数

# overrideable settings
: "${LOG_INFO:=0}"     # 削除ログを残したい場合は 1 それ以外は 0 にする

#
# Functions
#

# ensure_trainling_slash <path>
#
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

# rotate_files <target_dir> <file_pattern> [max_age_days:7] [min_retained_files:1]
#            target_dir: 対象ディレクトリ
#          file_pattern: 対象ファイル名パターン(shell glob パターン)
#          max_age_days: 最大保持世代(日数>0)
#    min_retained_files: 最小保持ファイル数(>=0)
#                        - ファイルの世代が指定より古くても消し過ぎて
#                        - しまわない様に残しておく数
# Return  =0: Success
#        !=0: Fail
#
function rotate_files() {
    local target_dir="${1:-}"
    local file_pattern="${2:-}"
    local max_age_days="${3:-$DEFAULT_MAX_AGE_DAYS}"
    local min_retain_files="${4:-$MIN_RETAINED_FILES}"

    # 引数チェック
    if [[ -z "$target_dir" || -z "$file_pattern" || -z "$max_age_days" ]]; then
        log_error "Error: Missing requried parameter(s). Usage: rotate_files <directory> <file_pattern> [max_age_days:>0]"
        return 1
    fi
    target_dir="$(ensure_trailing_slash "$target_dir")"

    if (( max_age_days < 1 )); then
        log_error "Error: Parameter #3 ('max_age_days') must be greater than or equal 1."
        return 1
    fi
    if (( min_retain_files < 0 )); then
        log_error "Error: Parameter #4 ('min_retain_files') must be greater then or equal 0."
        return 1
    fi


    # 該当ファイル一覧（更新日時の降順）
    local files=()
    readarray -d '' -t files < <(
        find "$target_dir" -type f -name "$file_pattern" -printf "%T@ %p\0" 2> >(log_error_stream) |
        sort -z -nr 2> >(log_error_stream) |
        awk -v RS='\0' -v ORS='\0' '{sub(/^[^ ]+ /, ""); print}' 2> >(log_error_stream)
    )
    # 空文字列だけの配列なら除去(readarray だけでは要素数0のリストが作れない)
    if (( ${#files[@]} == 1 )) && [[ -z "${files[0]}" ]]; then
        files=()
    fi
    local total_files="${#files[@]}"

    # 削除対象ファイルを抽出（指定日数より古いもの）
    local old_files=()
    for file in "${files[@]}"; do
        if [[ $(find "$file" -daystart -mtime +"$max_age_days" -print) ]]; then
            old_files+=("$file")
        fi
    done
    local total_old_files="${#old_files[@]}"

    # 削除可能数の計算（MIN_RETAINED_FILES 未満にならないようにする）
    local deletable_count=$total_old_files
    if (( (total_files - total_old_files) < min_retain_files )); then
        deletable_count=$(( total_files - min_retain_files ))
    fi

    # echo "max_age_days=$max_age_days"
    # echo "min_retained_files=$MIN_RETAINED_FILES"
    # echo "total_files=$total_files"
    # echo "old_files=${#old_files[@]}"
    # echo "deletable_count=$deletable_count"

    local deleted=0
    for file in "${old_files[@]}"; do
        if (( deleted >= deletable_count )); then
            break
        fi
        if [[ "$LOG_INFO" -ne 0 ]]; then
            log_info "Deleting: $file"
        fi
        rm -f "$file" 2> >(log_error_stream)
        ((deleted++)) || true   # set -e のため常に結果を真とする
    done
}


# check_small_files <target_dir> <file_name_pattern> <min_size>
#
# Usage:
#    check_small_files "$TARGET_DIR" "backup-*.tar.gz" "1M"   
#
#    min_size: find -size 指定のサイズ書式
#
# Return:  =0: 指定サイズ未満のファイルは存在しない
#          =1: 指定ディレクトリが存在しない
#          =2: 指定サイズ未満のファイルが見つかった  
#
check_small_files() {
    local target_dir="${1:-}"
    local file_name_pattern="${2:-}"
    local min_size="${3:-}"

    if [[ ! -d "$target_dir" ]]; then
        log_error "Error: check_small_files(): Parameter #1('target_dir') specified directory not found: $target_dir"
        return 1
    fi
    target_dir="$(ensure_trailing_slash "$target_dir")"

    small_files=$(
        find "$target_dir" \
        -type f \
        -name "$file_name_pattern" \
        -size -"${min_size}" \
        2> >(log_error_stream)
    )

    if [[ -n "$small_files" ]]; then
        log_error "Error: check_small_files(): One or more smaller than minimum size ($min_size) found: $small_files"
        return 2
    else
        return 0
    fi
}

#
# --- Main: for testing directly via console.
#
if [[ "$(basename "$0")" == "rotate_files.sh" ]]; then
    TARGET_DIR=${1:-}
    FILE_PATTERN=${2:-}
    MAX_AGE_DAYS=${3:-}

    # shellcheck disable=SC2034
    LOG_OUTPUT_MODE="std"  # ログ出力先をコンソールに： stdout/stderr for journal.sh


    LOG_INFO=1
    rotate_files "$TARGET_DIR" "$FILE_PATTERN" "$MAX_AGE_DAYS"
    check_small_files "$TARGET_DIR" "$FILE_PATTERN" "1000k"
fi

# EOS
