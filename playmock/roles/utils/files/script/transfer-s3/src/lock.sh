#!/usr/bin/env bash
# lock.sh
# transfer-s3: lock/unlock for exclusive processing.

#######################################
# lock()
#--------------------------------------
# flock による排他ロック
# 同一サーバ上で同一ディレクトリを処理対象とするコマンドの多重実行を
# ブロックするのが目的
# プロセスの終了と共にロックが解除されるため明示的なアンロックは不要
# ただしロックファイルは削除できてしまうため強固な排他制御ではない
# ロックファイルを誤って削除してしまうとロック状態が破綻するので注意
#
# GLOBALS:
#   LOCK_PATH
#   MYNAME
# ARGUMENTS:
#   なし
# OUTPUTS:
#   なし
# RETURN:
#   ロックが取得できた場合 0
#   ロックを取得できなかった場合 1 で終了
#######################################
function lock() {
    local old_flags="$-"
    set +e

    exec 9>"$LOCK_PATH" # 慣例に従ってファイルディスクリプタ 9 を使う
    flock -n 9
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        journal_err "$MYNAME is already running."
        exit 1
    fi

    if [[ $DEBUG -ne 0 ]]; then
        journal "Locked exclusively at $LOCK_PATH"
    fi

    set "-$old_flags"
}

#######################################
# unlock()
#--------------------------------------
# 内部関数：ロックファイルを削除する
# 厳密な意味でのアンロックではないが名称の対称性からこう呼ぶことにする
#
# GLOBALS:
#   LOCK_PATH
# ARGUMENTS:
#   なし
# OUTPUTS:
#   なし
# RETURN:
#   常に 0
#######################################
function unlock() {
    local old_flags="$-"
    set +e

    LOCK_PATH=${LOCK_PATH:-}
    if [[ -z $LOCK_PATH ]]; then
        # 初期化前なので単に終了する
        return 0
    fi
    # 自ロックであれば ロックファイルを削除する
    exec 9>"$LOCK_PATH"
    flock -n 9
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        rm "$LOCK_PATH"
        if [[ $DEBUG -ne 0 ]]; then
            journal "Unlocked successfully. $LOCK_PATH was removed."
        fi
    fi

    set "-$old_flags"
    return 0
}

#######################################
# _signal_handler(signal)
#--------------------------------------
# 内部関数：シグナルハンドラ
# _cleanup を実行する
#
# GLOBALS:
#   なし
# ARGUMENTS:
#   $1: signal
# OUTPUTS:
#   なし
# RETURN:
#   常に 0
#######################################
function _signal_handler() {
    msg="!!! $1 received ."
    journal "$msg"
    echo "" 1>&2
    echo "$msg" 1>&2

    raise "Terminated by signal '$1'."
}

#######################################
# _set_signal_handler()
#--------------------------------------
# 内部関数：シグナルハンドラの設定
# SIGINT, SIGTERM をトラップする。
# 主に CTRL+C による中断用
#
# GLOBALS:
#   なし
# ARGUMENTS:
#   なし
# OUTPUTS:
#   なし
# RETURN:
#   常に 0
#######################################
function _set_signal_handler() {
    for s in SIGINT SIGTERM ; do
        trap '_signal_handler '$s "$s"
    done
}

# スクリプトを読み込むことによって
# 自動的にシグナルハンドラが設定される
_set_signal_handler

#######################################
# -- 開発時の簡易動作確認
#
#   1. lock 関数の動作確認
#   2. Ctrl+C による中断の確認
#
# ARGUMENTS:
#   なし
#
# 実行するとロックを取得した後3秒待つので、その間に
# 1. 別途 lock.sh を実行してロック確認
# 2. Ctrl+C による中断確認
# が行える
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "lock.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # clear the terminate request.
    # APP_TERMINATE_REQUIRED=0

    # make a lock file path.
    MYNAME=$(basename "$COMMAND_NAME" .sh)
    WORK_PATH=${WORK_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
    LOCK_PATH=$WORK_PATH/$MYNAME.lock

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/error_trap.sh"

    DEBUG=${DEBUG:-0}

    # stub output for journaling.
    function journal() {
        echo "[$(date "+%Y-%m-%d %H:%I:%S.%N")] $*"
    }
    #stub for journal_err
    function journal_err() {
        echo "$*"
    }
    # override error_trap.sh:cleanup function
    function cleanup() {
        unlock # -> lock.sh:unlock()
    }

    # if ! lock; then
    #     echo "lock failed."
    #     exit 1
    # fi

    lock # exit if failed to lock.

    for i in $(seq 0 2); do
        echo "$i"
        sleep 1
        # if [[ $APP_TERMINATE_REQUIRED -ne 0 ]]; then
        #     echo "Terminate requested."
        #     break
        # fi
        # ↑
        # シグナルハンドラ内でフラグ設定してこの様に処理したい場合は
        # unset -e が必要
    done

    # unlock  # override した error_trap.sh:cleanup 関数で呼び出す

fi

#EOS
