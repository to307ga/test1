#!/usr/bin/env bash
# work_path.sh
# transfer-s3: Prepare working diretory and paths.

#######################################
# prepare_working_dir_and_path(source_dirs)
#--------------------------------------
# 各種パスの生成とワークディレクトリの準備
#
# GLOBALS:
#   MYNAME     - 自スクリプト名
#   FILE_DATE  - ジャーナルファイルに付ける日付文字列
# ARGUMENTS:
#   $@: source_dirs - 処理対象ファイルが格納されているディレクトリ(コマンド引数)
# OUTPUTS:
#   SOURCE_PATHS    - 処理対象ファイルが格納されているディレクトリのフルパス配列
#   WORK_PATH       - 作業ディレクトリのフルパス
#   TX_BUFFER_PATH  - 転送ファイルのバッファディレクトリのフルパス
#   LOCK_PATH       - ロックファイルのフルパス
#   JOURNAL_PATH    - ジャーナルファイルのフルパス
# RETURN:
#   常に 0
# REMARKS:
#   関数パラメータ source_dirs が指定されないか又は
#   ディレクトリではない場合は raise 関数で内部エラーとして終了する
#   ディレクトリが複数指定された場合、作業ディレクトリは最初のディレクトリ内とする
#######################################
function prepare_working_dir_and_path {
    local old_flags="$-"
    set +e # disable errexit

    local result=0

    if [[ -z $* ]]; then
        raise "$COMMAND_NAME: Missing parameter SOURCE_DIRS for function prepare_working_dir_and_path call."
    fi

    SOURCE_PATHS=()
    local has_direrr=0
    for dir in "${@}"; do
        if [[ -d $dir ]]; then
            SOURCE_PATHS+=( "$(cd "$(realpath "$dir")" && pwd)" )
        else
            journal_err "$COMMAND_NAME: '$dir' is not a directory."
            has_direrr=1
        fi
    done    
    if [[ 0 -ne $has_direrr ]]; then
        raise "$COMMAND_NAME: all specified directories must exist."
    fi
    readonly SOURCE_PATHS

    # make a working path and create a directory if not exists.
    WORK_DIR_NAME=.$MYNAME
    readonly WORK_DIR_NAME
    WORK_PATH=${SOURCE_PATHS[0]}/$WORK_DIR_NAME
    readonly WORK_PATH

    (mkdir -p "$WORK_PATH")
    local ret=$?
    if [[ $ret != 0 ]]; then
        if [[ ! -d $WORK_PATH ]]; then
            echo "$COMMAND_NAME: Could not create a working directory. you must have read/write permission on '${SOURCE_PATHS[0]}'."
            exit 2
        else
            echo "$COMMAND_NAME: Unexpected error occured. please check the following command line and exit code($ret)."
            echo "'mkdir -p \"$WORK_PATH\"'"
            exit $ret
        fi
    fi
    # make a transfer buffer directory path
    TX_BUFFER_PATH=$WORK_PATH/$MYHOSTNAME
    readonly TX_BUFFER_PATH

    # make a lock file path.
    LOCK_PATH=$WORK_PATH/$MYNAME.lock

    # make a journaling file path and create the file if not exists.
    local jfname
    if [[ -z $JOURNAL_ID ]]; then
        jfname="$MYNAME-journal-$FILE_DATE.txt"
    else
        jfname="$MYNAME-journal-$JOURNAL_ID-$FILE_DATE.txt"
    fi
    JOURNAL_PATH="$WORK_PATH/$jfname"
    readonly JOURNAL_PATH
    if [[ ! -e $JOURNAL_PATH ]]; then
        (touch "$JOURNAL_PATH")
        local ret=$?
        if [[ $ret -ne 0 ]]; then
            echo "$COMMAND_NAME: Failed to create a journal file. you must have read/write permission on '$WORK_PATH'."
            echo "or check the following command line and exit code($ret)."
            echo "'touch \"$JOURNAL_PATH\"'"
            result=255
        fi
    fi

    set "-$old_flags"
    return $result
}

#######################################
# -- 開発時の簡易動作確認
#
# 1. prepare_working_dir_and_path 関数の動作確認
#
# ARGUMENTS:
#   $1: source_dir  - 処理ディレクトリ
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "work_path.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/error_trap.sh"

    # stub for journal_err
    function journal_err() {
        echo "$*"
    }

    # absolute paths of source directories.
    SOURCE_PATHS=()
    # absolute path of working directory.
    WORK_PATH=""
    # absolute path of transfer buffer directory.
    TX_BUFFER_PATH=""
    # absolute path of lock file.
    LOCK_PATH=""
    # absolute path of journaling file.
    JOURNAL_ID=${JOURNAL_ID:-}
    JOURNAL_PATH=""
    MYNAME=$(basename "$0" .sh)
    FILE_DATE=$(date +%Y%m%d)
    MYHOSTNAME=$(hostname -s)


    IFS=" " read -ra SOURCE_DIRS <<< "$@"
    prepare_working_dir_and_path "${SOURCE_DIRS[@]}"

    echo "------ DIRECTORY AND FILES ------"

    cnt=1
    for dir in "${SOURCE_DIRS[@]}"; do
        echo "      SOURCE_DIRS: $cnt: $dir"
        cnt=$(( cnt + 1 ))
    done

    cnt=1
    for dir in "${SOURCE_PATHS[@]}"; do
        echo "     SOURCE_PATHS: $cnt: $dir"
        cnt=$(( cnt + 1 ))
    done

    echo "        WORK_PATH: $WORK_PATH"
    echo "   TX_BUFFER_PATH: $TX_BUFFER_PATH"
    echo "        LOCK_PATH: $LOCK_PATH"
    echo "     JOURNAL_PATH: $JOURNAL_PATH"
    echo "------ DIRECTORY AND FILES ------"

fi

#EOS
