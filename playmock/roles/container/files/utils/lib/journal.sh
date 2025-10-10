#!/usr/bin/env bash
# -- journal.sh
#    処理時のログを journald 経由で出力する
#
#    LOG_OUTPUT_MODE 環境変数で journald 出力(デフォルト)か stdout/stderr 出力かを切り替え可能
#    LOG_OUTPUT_MODE='journald'|'std'
#    ※'std' は主に開発時の動作確認用です。本番運用では 'journald' を推奨します。
#    ※'std' 指定時はログレベルによって stdout または stderr に出力します。
#    ※'journald' 指定時は systemd-cat コマンドを利用して journald にログを送ります。
#
#    ログレベルは LOG_LEVEL 環境変数で指定可能（デフォルトは 'info'）
#                low < --------------------------------- > high
#    LOG_LEVEL = debug|info|notice|warning|err|crit|alert|emerg
#
#    ※運用時は LOG_TAGNAME 環境変数で journald のタグ名を適宜指定してください。
#
set -u

# guard: prevent multiple sourcing
if [ -n "${__MY_JOURNAL_LOADED+x}" ]; then
    return 0
fi
__MY_JOURNAL_LOADED=1

# ログの出力先 journald or stdout/stderr
: "${LOG_OUTPUT_MODE:=journald}" # journald or std

# デフォルト設定(source 側スクリプトで適切に上書きしてください)
: "${LOG_TAGNAME:=my-journal}"
: "${LOG_LEVEL:=info}"

# ログ出力関数（メッセージと任意のレベル指定）
log_msg() {
    local message="$1"
    local level="${2:-info}"
    local mode="${LOG_OUTPUT_MODE:-journald}"  # 'journald' or 'std'
    local tag="${LOG_TAGNAME:-my-journal}"
    local current_level="${LOG_LEVEL:-info}"

    # ログレベルの優先度定義（低→高）
    declare -A LOG_LEVELS=(
        [debug]=0
        [info]=1
        [notice]=2
        [warning]=3
        [err]=4
        [crit]=5
        [alert]=6
        [emerg]=7
    )
    # 不正なレベルは info とみなす
    local level_priority="${LOG_LEVELS[$level]:-1}"
    local current_priority="${LOG_LEVELS[$current_level]:-1}"

    if (( level_priority < current_priority )); then
        return 0
    fi

    case "$mode" in
        journald)
            systemd-cat -t "$tag" -p "$level" <<< "$message"
            ;;
        std)
            if [[ "$level" == "info" ]]; then
                echo "$tag [$level]: $message"
            else
                echo "$tag [$level]: $message" >&2
            fi
            ;;
        *)
            echo "Invalid LOG_OUTPUT_MODE: '$mode'. Allowed values are 'journald' or 'std'." >&2
            return 1
            ;;
    esac
}

# ログレベル別ショートカット関数
log_info()    { log_msg "$1" info; }
log_warn()    { log_msg "$1" warning; }
log_error()   { log_msg "$1" err; }
log_debug()   { log_msg "$1" debug; }

# STDOUT/STDERR stream 版
# usage:
#   some_command 1> >(log_info_stream) 2> >(log_error_stream)
#
log_info_stream() {
    while IFS= read -r line; do
        log_info "$line"
    done
}
log_error_stream() {
    while IFS= read -r line; do
        log_error "$line"
    done
}

# 処理開始・終了ログ（監査性向上）
log_start()   { log_info "[$(basename "$0")] START at $(date '+%Y-%m-%d %H:%M:%S')"; }
log_end()     { log_info "[$(basename "$0")] END at $(date '+%Y-%m-%d %H:%M:%S')"; }

#
# Main: for testing directly via console.
#
if [[ "$(basename "$0")" == "journal.sh" ]]; then

    LOG_OUTPUT_MODE='std'

    log_start

    LOG_LEVEL=info log_msg "TEST: log_msg" info
    LOG_LEVEL=info log_info "TEST: log_info"
    LOG_LEVEL=info log_warn "TEST: log_warn"
    LOG_LEVEL=info log_error "TEST: log_error"
    LOG_LEVEL=info log_debug "TEST: log_debug"

    log_end
fi

# EOS
