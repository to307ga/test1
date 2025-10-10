#!/usr/bin/env bash
# error_trap.sh
# transfer-s3: Trap error and call the clean up process.

#######################################
# raise(message, code=EXIT_INTERNAL_ERR)
#--------------------------------------
# エラーを投げる
#
# GLOBALS:
#   EXIT_INTERNAL_ERR - 内部要因によるエラー
# ARGUMENTS:
#   message
#   code    - 終了コード(デフォルトはEXIT_INTERNAL_ERR)
# OUTPUTS:
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルに出力
# RETURN:
#   引数 code 値(または EXIT_INTERNAL_ERR)
# REMARKS:
#   組込setの errexit を有効にして使用すること
#   set -e または set -o errexit
#######################################
function raise() {
    DEBUG=${DEBUG:-0}

    journal_err "$1"
    if [[ $DEBUG -ne 0 ]]; then
        journal_err "Raised at ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]:-'-'}: ${FUNCNAME[1]:-main}()"
    fi

    set -e # force enable errexit.
    local code=${2:-$EXIT_INTERNAL_ERR}
    return "$code"
}

#######################################
# trycatch(line_no, func_name)
#--------------------------------------
# エラーをキャッチする
# 使い方:
#    trap trycatch ERR
#
# 標準ではデバッグ情報としてエラー発生位置を出力する
# 必要に応じて別途処理関数を定義し
# trap FUNC ERR
# として使用する
#######################################
function trycatch() {
    status=$?

    DEBUG=${DEBUG:-0}
    if [[ $DEBUG -ne 0 ]]; then
        journal_err "ERROR: ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]:-main}() returned ${status}."
    fi
}

#######################################
# finally()
#--------------------------------------
# 終了時ハンドラ
# 使い方:
#    trap finally EXIT
#
# 別途終了処理 cleanup 関数が必要
#######################################
function finally() {
    cleanup
}

# スクリプトを読み込むことによって
# 自動的にエラーハンドラが設定される
trap trycatch ERR
trap finally EXIT

#######################################
# cleanup()
#--------------------------------------
# 終了時の処理
# デフォルトは何もしない
#
# error_trap.sh より後に読み込むスクリプトにて
# cleanup 関数を再定義することで任意の終了処理を
# 実行できる
#######################################
function cleanup() {
    return 0 # NOP
}

#######################################
# -- 開発時の簡易動作確認
#
#   1. raise 関数の動作確認
#
# ARGUMENTS:
#   なし
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "error_trap.sh" ]]; then
    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"

    DEBUG=${DEBUG:-0}

    # stub for journal_err function
    function journal_err() {
        echo "$*"
    }

    # stub for unlock function
    function cleanup() {
        echo "Application terminated finally."
    }

    function func_raise_error() {
        raise "メッセージ" 123
    }

    function func_return_non_zero() {
        func_raise_error
    }

    # my_func
    func_return_non_zero  # raise error

    # this code should skip
    echo "This code should be skipped."

fi

#EOS
