#!/usr/bin/env bash
# app.sh
# transfer-s3: Application common setting and variables.

# Fail on unset variables and command errors
set -ue -o pipefail
# Prevent commands misbehaving due to locale differences
export LC_ALL=C

# date and time at starting.
BEGIN_AT=$(date --iso-8601=ns)
readonly BEGIN_AT

# running environment: production, development or testing.
readonly TRANSFER_S3_ENV=${TRANSFER_S3_ENV:-production}

# set to 1 enabled for debug output.
DEBUG=${DEBUG:-0}
# set to 1 enabled keep temporally files for testing.
KEEP_TEMP_FILES=${KEEP_TEMP_FILES:-0}

# System values.
COMMAND_LINE="$0 $*"
readonly COMMAND_LINE
COMMAND_NAME=$(basename "$0")
COMMAND_PATH=$(cd "$(dirname "$(realpath "$0")")" && pwd)
MYNAME=$(basename "$0" .sh)
readonly MYNAME
MYHOSTNAME=$(hostname -s)
readonly MYHOSTNAME

# Load constants
# shellcheck disable=SC1091
. "$COMMAND_PATH/constants.sh" # COMMAND_VERSION defined at 'constants.sh'.

# Encryption keys paths
if [[ $TRANSFER_S3_ENV == "production" ]]; then
    keyowner=$CRYPT_KEY_OWNER
else
    # for testing
    keyowner=$USER
fi
CRYPT_OWNERS_HOME=$(eval echo "~$keyowner")
readonly CRYPT_OWNERS_HOME
CRYPT_PRIVATE_KEY="$CRYPT_OWNERS_HOME/.ssh/id_rsa"
readonly CRYPT_PRIVATE_KEY
CRYPT_PUBLIC_KEY="$CRYPT_OWNERS_HOME/.ssh/id_rsa.pub"
readonly CRYPT_PUBLIC_KEY
CRYPT_CERTIFICATE="$CRYPT_OWNERS_HOME/.ssh/id_rsa.crt"
readonly CRYPT_CERTIFICATE

# s3 upload path
S3_UPLOAD_PATH="s3://" #"s3://$AWS_S3_BUCKET/$MYHOSTNAME"

# date of today
TODAY=$(date --date="$BEGIN_AT" "+$FMT_DATE")
readonly TODAY
# date suffix for journal file
FILE_DATE=$(date --date="$BEGIN_AT" "+$FMT_FILE_DATE")
readonly FILE_DATE
# date suffix for journal file
FILE_UNIQUNIZE=$(date --date="$BEGIN_AT" "+$FMT_FILE_UNIQUNIZE")
readonly FILE_UNIQUNIZE

#
## Default values (overwritable).
#

# aws-cli s3 コマンドで使用するバケット名（必須:第1パラメータ）
AWS_S3_BUCKET=""

# aws-cli コマンドで使用するプロファイル名
AWS_PROFILE=$DEF_AWS_PROFILE

# gzip 対象のファイルを何日以上古いものとするか
GZIP_OLDER_THAN=$DEF_GZIP_OLDER_THAN

# S3への移動後に削除するファイルを何日以上古いものとするか
MOVE_OLDER_THAN=$DEF_MOVE_OLDER_THAN

# Dry-Run モード(1:有効, 0:無効)
DRYRUN=$DEF_DRYRUN

# 冗長なメッセージ出力(1:有効, 0:無効)
VERBOSE=$DEF_VERBOSE

# バックアップ対象とするファイル名パターンリスト(カンマ区切り文字列)
INCLUDE_PATTERNS=$DEF_INCLUDE_PATTERNS

# 指定ディレクトリ直下のアイルのみをバックアップ対象とする
NON_RECURSIVE=$DEF_NON_RECURSIVE

# シンボリックリンクを辿ってバックアップ対象ファイルを検索するかどうか
FOLLOW_SYMLINK=$DEF_FOLLOW_SYMLINK

# バックアップ対象ファイルを１つずつ移動するかどうか
MOVE_ONE_BY_ONE=$DEF_MOVE_ONE_BY_ONE

# ジャーナルファイル名をユニークにしたい場合に付けるID
JOURNAL_ID=$DEF_JOURNAL_ID


#######################################
# show_variables()
#--------------------------------------
# 変数値をジャーナルファイルに書き込む。
# 主にデバッグ用途
#
# GLOBALS:
#   各設定変数
# ARGUMENTS:
#   無し
# OUTPUTS:
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイル
# RETURN:
#   常に 0
#######################################
function show_variables() {
    journal_raw "------ APPLICATION VARIABLES ------"    # defined file are as belows.
    journal_raw "  TRANSFER_S3_ENV: $TRANSFER_S3_ENV"    # app.sh
    journal_raw "  COMMAND_VERSION: $COMMAND_VERSION"    # constants.sh
    journal_raw "    RUNNABLE_USER: $RUNNABLE_USER"      # constants.sh
    journal_raw "     COMMAND_PATH: $COMMAND_PATH"       # app.sh
    journal_raw "     COMMAND_NAME: $COMMAND_NAME"       # app.sh
    journal_raw "           MYNAME: $MYNAME"             # app.sh
    journal_raw "       MYHOSTNAME: $MYHOSTNAME"         # app.sh
    journal_raw "            DEBUG: $DEBUG"              # app.sh
    
    journal_raw ""
    journal_raw "------ CONFIGURATION VARIABLES ------"
    journal_raw "    AWS_S3_BUCKET: $AWS_S3_BUCKET"      # options.sh
    journal_raw "      AWS_PROFILE: $AWS_PROFILE"        # options.sh, app.sh with default value defined at constnts.sh
    journal_raw "  GZIP_OLDER_THAN: $GZIP_OLDER_THAN"    # options.sh, app.sh with default value defined at constnts.sh
    journal_raw " INCLUDE_PATTERNS: $INCLUDE_PATTERNS"   # options.sh, app.sh with default value defined at constnts.sh
    journal_raw "  MOVE_OLDER_THAN: $MOVE_OLDER_THAN"    # options.sh, app.sh with default value defined at constnts.sh
    journal_raw "    NON_RECURSIVE: $NON_RECURSIVE"      # options.sh, app.sh with default value defined at constnts.sh
    journal_raw "           DRYRUN: $DRYRUN"             # options.sh, app.sh with default value defined at constnts.sh
    journal_raw "          VERBOSE: $VERBOSE"            # options.sh, app.sh with default value defined at constnts.sh
    journal_raw "      SOURCE_DIRS: ${SOURCE_DIRS[*]}"   # options.sh
    journal_raw "   S3_UPLOAD_PATH: $S3_UPLOAD_PATH"     # options.sh
    journal_raw "   FOLLOW_SYMLINK: $FOLLOW_SYMLINK"     # app.sh with default value defined at constants.sh
    journal_raw "  MOVE_ONE_BY_ONE: $MOVE_ONE_BY_ONE"    # app.sh with default value defined at constants.sh
    journal_raw "       JOURNAL_ID: $JOURNAL_ID"         # app.sh with default value defined at constants.sh
    
    journal_raw ""
    journal_raw "------ DIRECTORY AND FILES ------"
    journal_raw "     SOURCE_PATHS: ${SOURCE_PATHS[*]}"  # work_path.sh
    journal_raw "        WORK_PATH: $WORK_PATH"          # work_path.sh
    journal_raw "     JOURNAL_PATH: $JOURNAL_PATH"       # work_path.sh
    journal_raw "        LOCK_PATH: $LOCK_PATH"          # work_path.sh
    
    journal_raw ""
    journal_raw "------ DATE AND TIMES ------"
    journal_raw "         BEGIN_AT: $BEGIN_AT"           # app.sh
    journal_raw "   FILE_UNIQUNIZE: $FILE_UNIQUNIZE"     # app.sh
    journal_raw "            TODAY: $TODAY"              # app.sh
    journal_raw "        FILE_DATE: $FILE_DATE"          # app.sh
    journal_raw "  GZIP_DATE_UNTIL: $GZIP_DATE_UNTIL"    # app.sh
    journal_raw "  MOVE_DATE_UNTIL: $MOVE_DATE_UNTIL"    # app.sh
    
    journal_raw ""
    journal_raw "------ ENCRYPT AND DECRYPT ------"
    if [[ $TRANSFER_S3_ENV == "production" ]]; then
        journal_raw "  CRYPT_KEY_OWNER: $CRYPT_KEY_OWNER" # constants.sh
    else
        journal_raw "  CRYPT_KEY_OWNER: $keyowner"       # app.sh
    fi
    journal_raw "CRYPT_OWNERS_HOME: $CRYPT_OWNERS_HOME"  # app.sh
    journal_raw "CRYPT_PRIVATE_KEY: $CRYPT_PRIVATE_KEY"  # app.sh
    journal_raw " CRYPT_PUBLIC_KEY: $CRYPT_PUBLIC_KEY"   # app.sh
    journal_raw "CRYPT_CERTIFICATE: $CRYPT_CERTIFICATE"  # app.sh
    journal_raw ""

    journal_raw "------ COMMAND LINE ------"
    journal_raw "'$COMMAND_LINE'"
    journal_raw ""
    
    return 0
}

#######################################
# calc_process_dates()
#--------------------------------------
# 圧縮、移動対象ファイルを特定するための日付を計算する
# ※過去から計算結果日までのファイルが対象
#
# GLOBALS:
#   GZIP_OLDER_THAN
#   MOVE_OLDER_THAN
#   FMT_DATE - 日付書式
#   TODAY    - 実行日
# ARGUMENTS:
#   無し
# OUTPUTS:
#   GZIP_DATE_UNTIL
#   MOVE_DATE_UNTIL
# RETURN:
#   常に 0
#######################################
function calc_process_dates() {
    local date_str
    date_str="$TODAY $((GZIP_OLDER_THAN + 1)) days ago"
    GZIP_DATE_UNTIL=$(date --date="$date_str" "+$FMT_DATE")

    date_str="$TODAY $((MOVE_OLDER_THAN + 1)) days ago"
    MOVE_DATE_UNTIL=$(date --date="$date_str" "+$FMT_DATE")

    return 0
}

#######################################
# journal_beginning()
#--------------------------------------
# 処理開始メッセージをジャーナルに出力する
#
# GLOBALS:
#   MYNAME
#   COMMAND_LINE
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイル
# RETURN:
#   常に 0
#######################################
function journal_beginning() {
    journal "$MYNAME begins with command line: '$COMMAND_LINE'"
    return 0
}

#######################################
# dryrun_notice(dryrun)
#--------------------------------------
# Dry-Run モード時に注意メッセージを出力する。
# 通常時は何も出力しない。
#
# GLOBALS:
#   無し
# ARGUMENTS:
#   dryrun - 1:Dry-Run, 0:通常
# OUTPUTS:
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイル
# RETURN:
#   常に 0
#######################################
function dryrun_notice() {
    if [[ $DRYRUN -ne 0 ]]; then
        journal_raw "************************************************************************"
        journal_raw "Dry run mode is enabled. That means no files are gzipped or moved to S3."
        journal_raw "************************************************************************"
    fi
    return 0
}

#######################################
# journal_time_status()
#--------------------------------------
# 開始、終了日時をジャーナルに出力する
#
# GLOBALS:
#   BEGIN_AT
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT,STDERR 及び JOURNAL_PATH が示すジャーナルファイルに出力
# RETURN:
#   常に 0
#
# 出力書式は RFC-3339
# 例: '2023-05-18 11:28:45.019295358+09:00'
#######################################
function journal_time_status() {
    END_AT=$(date --rfc-3339=ns)
    local begin
    begin=$(date --date="$BEGIN_AT" --rfc-3339=ns)

    journal "## Time status"
    journal "  Start: $begin"
    journal "    End: $END_AT"
    # journal "Elapsed: $ELAPSED"

    return 0
}

#######################################
# upload_journal(journal_path)
#--------------------------------------
# ジャーナルファイルをアップロードする
#
# GLOBALS:
#   S3_UPLOAD_PATH
# ARGUMENTS:
#   $1: journal_path - ジャーナルファイルのフルパス
# OUTPUTS:
#   なし
# RETURN:
#   常に 0
#######################################
function upload_journal() {
    journal_path=${1:-}
    if [[ -z $journal_path ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): a journal file path must be specified as argument 1."
    fi

    local aws_cmd
    aws_cmd=(aws s3 cp "$JOURNAL_PATH" "$S3_UPLOAD_PATH"/ --no-progress --profile="$AWS_PROFILE")
    if [[ $DRYRUN -ne 0 ]]; then
        aws_cmd+=(--dryrun)
    fi

    RESULT=$("${aws_cmd[@]}")
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        jounral_err "ERROR: failed to upload journal file: ${RESULT[:]}"
    else
        journal "${RESULT[@]}"
    fi

    # Delete journal files that are 7 days old.
    find "$(dirname "$JOURNAL_PATH")" -type f -daystart -mtime "+6" -iname "$MYNAME-journal-*.txt" -exec rm {} + 

    return 0
}


#######################################
# -- 開発時の簡易動作確認
#
#   1. show_variables 関数による変数の確認
#
# ARGUMENTS:
#   なし
#######################################
if [[ $COMMAND_NAME == "app.sh" ]]; then

    msg="[TEST] This variable is not set until analyzed command line at options.sh. [TEST]"

    SOURCE_DIRS=( path1 path2 )
    SOURCE_PATHS=( fullpath1 fullpath2 )
    WORK_PATH=$msg
    JOURNAL_PATH=$msg
    LOCK_PATH=$msg
    GZIP_DATE_UNTIL=$msg
    MOVE_DATE_UNTIL=$msg
    AWS_S3_BUCKET=$msg
    S3_UPLOAD_PATH=$msg
    INCLUDE_PATTERNS="patter1*,pattern2*"
    JOURNAL_ID=$msg
    
    # stub for journal function.
    function journal() {
        echo "$*"
    }

    # stub for journal_raw function.
    function journal_raw() {
        echo "$*"
    }

    journal_beginning

    show_variables

fi

#EOS
