#!/usr/bin/env bash
# journal.sh
# transfer-s3: Journaling for process.

#######################################
# _journal_out(timestamp message)
#--------------------------------------
# 内部処理：message をジャーナルファイルに出力する
#
# GLOBALS:
#   JOURNAL_PATH
#   DRYRUN
#   VERBOSE
# ARGUMENTS:
#   $1: timestamp
#   $2: message
# OUTPUTS:
#   JOURNAL_PATH が示すジャーナルファイルへの出力
#   STDOUT,STDERR への出力(VERBOSE有効時のみ)
#
#   通常 JOURNAL_PATH が示すジャーナルファイルにタイムスタンプ付きメッセージを、
#   またタイムスタンプ無しメッセージを STDOUT,STDERR に出力する(VERBOSE有効時のみ)
#   ただし、ジャーナルファイルが存在しない場合は VERBOSE値に関わらず STDOUT,STDERR に
#   タイムスタンプ付きメッセージを出力する。
#
#   DRYRUN有効時はメッセージ先頭に(Dry-Run)マークを付けて出力する。
# RETURN:
#   常に 0
#######################################
function _journal_out() {
    # Dry-Run mark for the journal.
    local jnl_dryrun=""
    if [[ $DRYRUN -ne 0 ]]; then
        jnl_dryrun="(Dry-Run)"
    fi

    if [[ -f $JOURNAL_PATH ]]; then
        echo "[$1]$jnl_dryrun $2" >>"$JOURNAL_PATH"
        if [[ $VERBOSE -ne 0 ]]; then
            echo "$jnl_dryrun$2" 1>&2 # Console output without timestamp.
        fi
    else
        # console output with timestamp if journal file not exists.
        echo "[$1]$jnl_dryrun $2" 1>&2
    fi
    return 0
}

#######################################
# _journal_out_err(timestamp message)
#--------------------------------------
# 内部処理：message をジャーナルファイルに出力する
# _journal_out() とはVERBOSE値に関わらずコンソールへの出力も行う点が異なる
#
# GLOBALS:
#   JOURNAL_PATH
#   DRYRUN
# ARGUMENTS:
#   $1: timestamp
#   $2: message
# OUTPUTS:
#   JOURNAL_PATH が示すジャーナルファイルへの出力
#   STDOUT,STDERR への出力
#
#   通常 JOURNAL_PATH が示すジャーナルファイルにタイムスタンプ付きメッセージを、
#   またタイムスタンプ無しメッセージを STDOUT,STDERR に出力する(VERBOSE有効時のみ)
#   ただし、ジャーナルファイルが存在しない場合は STDOUT,STDERR に
#   タイムスタンプ付きメッセージを出力する。
#
#   DRYRUN有効時はメッセージ先頭に(Dry-Run)マークを付けて出力する。
# RETURN:
#   常に 0
#######################################
function _journal_out_err() {
    # Dry-Run mark for the journal.
    local jnl_dryrun=""
    if [[ $DRYRUN -ne 0 ]]; then
        jnl_dryrun="(Dry-Run)"
    fi

    if [[ -f $JOURNAL_PATH ]]; then
        echo "[$1]$jnl_dryrun $2" >>"$JOURNAL_PATH"
        echo "$jnl_dryrun$2" 1>&2 # Console output without timestamp.
    else
        # console output with timestamp if journal file not exists.
        echo "[$1]$jnl_dryrun $2" 1>&2
    fi
    return 0
}

#######################################
# journal_raw(message)
#--------------------------------------
# message を無加工でジャーナルファイルに出力する
#
# GLOBALS:
#   JOURNAL_PATH
#   VERBOSE
# ARGUMENTS:
#   message
# OUTPUTS:
#   JOURNAL_PATH が示すジャーナルファイルへの出力
#   STDOUT,STDERR への出力(VERBOSE有効時のみ)
# RETURN:
#   常に 0
#######################################
function journal_raw() {
    if [[ -f $JOURNAL_PATH ]]; then
        echo "$*" >>"$JOURNAL_PATH"
    fi
    if [[ $VERBOSE -ne 0 ]]; then
        echo "$*" 1>&2
    fi

    return 0
}

#######################################
# journal(message)
#--------------------------------------
# message をジャーナルファイルに出力する
#
# GLOBALS:
#   FMT_JNL_DATETIME - ジャーナル用タイムスタンプ書式
# ARGUMENTS:
#   message
# OUTPUTS:
#   JOURNAL_PATH が示すジャーナルファイルへの出力
#   STDOUT,STDERR への出力(VERBOSE有効時のみ)
#
#   通常 JOURNAL_PATH が示すジャーナルファイルにタイムスタンプ付きメッセージを、
#   またタイムスタンプ無しメッセージを STDOUT,STDERR に出力する(VERBOSE有効時のみ)
#   ただし、ジャーナルファイルが存在しない場合は VERBOSE値に関わらず STDOUT,STDERR に
#   タイムスタンプ付きメッセージを出力する。
#
#   DRYRUN有効時はメッセージ先頭に(Dry-Run)マークを付けて出力する。
# RETURN:
#   常に 0
#######################################
function journal() {
    local timestamp
    timestamp=$(date "+$FMT_JNL_DATETIME")
    _journal_out "$timestamp" "$*"

    return 0
}

#######################################
# journal_err(message)
#--------------------------------------
# message をジャーナルファイルに出力する
# journal() とはVERBOSE値に関わらずコンソールへの出力も行う点が異なる
#
# GLOBALS:
#   FMT_JNL_DATETIME - ジャーナル用タイムスタンプ書式
# ARGUMENTS:
#   message
# OUTPUTS:
#   JOURNAL_PATH が示すジャーナルファイルへの出力
#   STDOUT,STDERR への出力
#
#   通常 JOURNAL_PATH が示すジャーナルファイルにタイムスタンプ付きメッセージを、
#   またタイムスタンプ無しメッセージを STDOUT,STDERR に出力する
#   ただし、ジャーナルファイルが存在しない場合は STDOUT,STDERR に
#   タイムスタンプ付きメッセージを出力する。
#
#   DRYRUN有効時はメッセージ先頭に(Dry-Run)マークを付けて出力する。
# RETURN:
#   常に 0
#######################################
function journal_err() {
    local timestamp
    timestamp=$(date "+$FMT_JNL_DATETIME")
    _journal_out_err "$timestamp" "$*"

    return 0
}


#######################################
# -- 開発時の簡易動作確認
#
#   1. journal 関数の動作確認
#   2. journal_raw 関数の動作確認
#
# ARGUMENTS:
#   $1: ジャーナルファイルのパス
#       未指定時はジャーナル出力無し
#
# DRYRUN値による挙動確認は
# export DRYRUN=1
# で行う
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "journal.sh" ]]; then
    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"

    JOURNAL_PATH=${1:-}
    if [[ -z $JOURNAL_PATH ]]; then
        echo "Test usage: journal.sh <JOURNAL_PATH>"
        exit 255
    fi

    if [[ ! -e $JOURNAL_PATH ]] ; then
        touch "$JOURNAL_PATH"
        echo "journal file created($JOURNAL_PATH)"
    elif [[ -d $JOURNAL_PATH ]]; then
        echo "$JOURNAL_PATH is directory."
        exit 255
    fi
    DRYRUN=${DRYRUN:-0}
    VERBOSE=${VERBOSE:-0}

    journal "$COMMAND_NAME: journaling done."

    journal_raw "$COMMAND_NAME: raw journaling done."

    echo "Delete journal file($JOURNAL_PATH) yourself."
    echo "---- $JOURNAL_PATH begin"
    cat "$JOURNAL_PATH"
    echo "---- $JOURNAL_PATH end"

fi

#EOS
