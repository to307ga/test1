#!/usr/bin/env bash
# transfer-s3.sh - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion.
# --help option displays command usage.

# System values.
COMMAND_PATH=$(cd "$(dirname "$(realpath "$0")")" && pwd)

# Load sub scripts.
# Do not change the load order to resolve dependencies correctly.
# shellcheck disable=SC1091
. "$COMMAND_PATH/app.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/error_trap.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/help.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/version.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/options.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/check_exec_env.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/work_path.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/journal.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/lock.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/compress_by_gzip.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/crypt.sh"
# shellcheck disable=SC1091
. "$COMMAND_PATH/move_to_s3.sh"

#######################################
# [override] error_trap.sh:cleanup()
#--------------------------------------
# 終了時の処理
# 排他ロックの解除を行う
#######################################
function cleanup() {
    unlock # -> lock.sh:unlock()
}

#######################################
# verbose_show_variables()
#--------------------------------------
# 冗長メッセージ： 変数の表示
#######################################
function verbose_show_variables() {
    if [[ $DEBUG -ne 0 ]] || [[ $VERBOSE -ne 0 ]]; then
        show_variables  # app.sh:show_variables()
    fi
}


#######################################
# The main begins.
#######################################

check_running_user

options "$@"

prepare_working_dir_and_path "${SOURCE_DIRS[@]}"

dryrun_notice "$DRYRUN"

journal_beginning

lock

calc_process_dates

check_exec_env

verbose_show_variables

compress_old_files "${SOURCE_PATHS[@]}"

move_old_files "${SOURCE_PATHS[@]}"

journal_time_status

upload_journal "$JOURNAL_PATH"

# unlock  # 排他ロックは error_trap.sh により
#           プロセス終了時に暗黙的に解除される

#EOS
