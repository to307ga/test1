#!/usr/bin/env bash
# check_exec_env.sh
# transfer-s3: Check execution environment.

# --- A NOTE FOR REVIEWERS AND MAINTAINERS ---
# 長いメッセージ文字列を読みやすくするためのバックスラッシュによる行連結は
# このスクリプトでは行っていません。
# bash ではダブルクォーテーションが文字列リテラルの範囲を表さないため、
# 改行前後の空白により想定外の空白が文字列に混ざってしまうためです。
# VSCode ではエディタ上で Alt+Z または [表示メニュー]＞[右端での折り返し]
# を選択すると見やすくなります。
# --- A NOTE FOR REVIEWERS AND MAINTAINERS ---

# _HAS_ERRORS:
# 実行環境チェック時にエラーが発生した場合に 1 を設定します。
# できるだけ多くのチェックを行い問題点を一覧にするのが目的ですが、
# コマンドが無かったり想定外のエラーが発生した場合は(現状)その時点で
# 処理が終了します。
_HAS_ERRORS=0

#######################################
# exists_aws_bandwidth_restrictions(profile)
#--------------------------------------
# S3の通信帯域制限設定があることを確認する。
# 設定が無ければデフォルトの帯域制限値を設定する。
#
# GLOBALS:
#   COMMAND_NAME
#   DEF_S3_BANDWIDTH
# ARGUMENTS:
#   profile
# OUTPUTS:
#   指定の AWSプロファイルのS3 config 設定
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
# REMARKS:
#   関数パラメータ profile が指定されないか又は空の場合は raise 関数で
#   内部エラーとして終了する
#######################################
function exists_aws_bandwidth_restrictions() {
    local profile_name="${1:-}"
    if [[ -z "$profile_name" ]]; then
        raise "$COMMAND_NAME: exists_aws_bandwidth_restrictions(): A profile name must be specified as argument 1"
    fi
    if [[ -z "$DEF_S3_BANDWIDTH" ]]; then
        raise "$COMMAND_NAME: exists_aws_bandwidth_restrictions(): DEF_S3_BANDWIDTH must not blank"
    fi

    local args
    local bw
    local no_bw=0

    args=(configure get "profile.$profile_name.s3.max_bandwidth")
    bw=$(aws "${args[@]}")
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        no_bw=1
    elif [[ -z $bw ]]; then
        no_bw=1
    fi
    if [[ $no_bw -ne 0 ]]; then
        journal_err "WARNING: a S3 max_bandwidth is not configured on your profile named '$profile_name'."
        args=(configure set "profile.$profile_name.s3.max_bandwidth" "$DEF_S3_BANDWIDTH")
        aws "${args[@]}"
        ret=$?
        if [[ $ret != 0 ]]; then
            raise "$COMMAND_NAME: aws S3 max_bandwidth configuration failed with code $ret. Please check the following aws command line and exit code. 'aws ${args[*]}'."
        else
            journal_err "You have successfully configured profile '$profile_name'."
            journal_err "Set S3 max_bandwidth to '$DEF_S3_BANDWIDTH'."
            return 0
        fi
    else
        journal "use S3 max_bandwidth: '$bw'"
        return 0
    fi
}

#######################################
# exists_aws_profile(profile)
#--------------------------------------
# aws-cli のプロファイル設定が存在することを確認する。
# 存在した場合、引き続き通信帯域制限設定の確認を行う。
#
# GLOBALS:
#   COMMAND_NAME
#   DEF_AWS_PROFILE
#   _HAS_ERRORS
# ARGUMENTS:
#   profile
# OUTPUTS:
#   _HAS_ERRORS
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
# REMARKS:
#   関数パラメータ profile が指定されないか又は空の場合は raise 関数で
#   内部エラーとして終了する
#######################################
function exists_aws_profile() {
    local profile_name="${1:-}"
    if [[ -z "$profile_name" ]]; then
        raise "$COMMAND_NAME: exists_aws_profile(): A profile name must be specified as argument 1"
    fi

    (aws configure list-profiles | grep "$profile_name" -q)
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        journal_err "$COMMAND_NAME: There is no profile for aws-cli named '$profile_name' owned by user $USER."
        _HAS_ERRORS=1
    else
        exists_aws_bandwidth_restrictions "$profile_name"
    fi

    return 0
}

#######################################
# exists_aws_cli()
#--------------------------------------
# aws コマンドが存在するかを確認する。
# またバージョンが 2.0 以上であることを確認する。
# コマンドが存在した場合引き続きプロファイルの確認を行う。
# プロファイルが存在した場合引き続きS3通信帯域制限設定の確認を行う。
#
# GLOBALS:
#   COMMAND_NAME
#   AWS_PROFILE
#   _HAS_ERRORS
# ARGUMENTS:
#   なし
# OUTPUTS:
#   _HAS_ERRORS
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
#######################################
function exists_aws_cli() {
    local version
    version=$(aws --version)
    ret=$?
    if [[ $ret -ne 0 ]]; then
        journal_err "$COMMAND_NAME: aws command is required."
        _HAS_ERRORS=1
        return 0
    fi

    # version string matching: "aws-cli/MAJOR.MINOR"
    if [[ ${version} =~ ^aws-cli/([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        all="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        major=${BASH_REMATCH[1]}
        if [[ $major -lt 2 ]]; then
            journal_err "$COMMAND_NAME: aws command is required version 2.0 or later. version ${all} found."
            _HAS_ERRORS=1
            return 0
        fi
    fi

    exists_aws_profile "$AWS_PROFILE"

    return 0
}

#######################################
# exists_openssl()
#--------------------------------------
# openssl コマンドが存在するかを確認する。
#
# GLOBALS:
#   COMMAND_NAME
#   _HAS_ERRORS
# ARGUMENTS:
#   なし
# OUTPUTS:
#   _HAS_ERRORS
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
#######################################
function exists_openssl() {
    if ! openssl version &>/dev/null; then
        journal_err "$COMMAND_NAME: openssl command is required."
        _HAS_ERRORS=1
    fi

    return 0
}

#######################################
# exists_gzip()
#--------------------------------------
# gzip コマンドが存在するかを確認する。
#
# GLOBALS:
#   COMMAND_NAME
#   _HAS_ERRORS
# ARGUMENTS:
#   なし
# OUTPUTS:
#   _HAS_ERRORS
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
#######################################
function exists_gzip() {
    if ! gzip --version &>/dev/null; then
        journal_err "$COMMAND_NAME: gzip command is required."
        _HAS_ERRORS=1
    fi

    return 0
}

#######################################
# exists_find()
#--------------------------------------
# find コマンドが存在するかを確認する。
#
# GLOBALS:
#   COMMAND_NAME
#   _HAS_ERRORS
# ARGUMENTS:
#   なし
# OUTPUTS:
#   _HAS_ERRORS
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
#######################################
function exists_find() {
    if ! find . --version &>/dev/null; then
        journal_err "$COMMAND_NAME: find command is required."
        _HAS_ERRORS=1
    fi

    return 0
}

#######################################
# exists_ssh_key_pair()
#--------------------------------------
# SSH鍵ペアが存在するか確認する。
# 鍵ペアが存在する場合、証明書ファイルの存在を確認する。
# 証明書ファイルが無い場合、秘密鍵から証明書ファイルを作成する。
#
# GLOBALS:
#   HOME
#   COMMAND_NAME
#   _HAS_ERRORS
# ARGUMENTS:
#   なし
# OUTPUTS:
#   _HAS_ERRORS
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   常に 0
#######################################
function exists_ssh_key_pair() {
    if [[ ! -d "$CRYPT_OWNERS_HOME" ]]; then
        journal_err "$COMMAND_NAME: The user $CRYPT_KEY_OWNER who owns the SSH key pair for encryption does not exist."
        _HAS_ERRORS=1
        return 0
    fi

    if [[ ! -f "$CRYPT_PRIVATE_KEY" ]] || [[ ! -f "$CRYPT_PUBLIC_KEY" ]]; then
        journal_err "$COMMAND_NAME: An SSH key pair file is required; create a key pair file for user $CRYPT_KEY_OWNER using the command 'ssh-keygen -t rsa -m pem'."
        _HAS_ERRORS=1
        return 0
    fi

    if [[ ! -f "$CRYPT_CERTIFICATE" ]]; then
        journal_err "WARNING: SSH certificate file is not found. Now creating certificate from private key."
        # コマンド行をエラーメッセージに出力したいので再利用できるようにする。
        # 但しコマンド行を文字列連結で作成してしまうとパス中の空白を正しくハ
        # ンドリングできないため配列を使用する。
        # @see https://www.shellcheck.net/wiki/SC2089
        local args=(req -x509 -new -key "$CRYPT_PRIVATE_KEY" -subj '/' -out "$CRYPT_CERTIFICATE")
        openssl "${args[@]}"
        local ret=$?
        if [[ $ret != 0 ]]; then
            journal_err "$COMMAND_NAME: Failed to create certificate file. Please check the following openssl command line and exit code($ret)."
            journal_err "'openssl ${args[*]}'"
            return $ret # unexpected error
        else
            journal_err "$CRYPT_CERTIFICATE is created and used for encryption."
        fi
    else
        journal "use $CRYPT_CERTIFICATE as a certificate for encryption."
    fi

    return 0
}

#######################################
# check_exec_env()
#--------------------------------------
# 実行環境の確認と設定
# ・必要なコマンドが存在することを確認する
# ・aws-cli に指定プロファイルが設定されていることを確認する
# ・aws-cli の指定プロファイルに S3 の転送帯域制限設定が設定されていいることを
#   確認する
# ・帯域制限設定が無ければデフォルト値を設定する
# ・鍵ペアが存在する場合、証明書ファイルの存在を確認する
# ・証明書ファイルが無い場合、秘密鍵から証明書ファイルを作成する
#
# GLOBALS:
#   _HAS_ERRORS
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   正常時 0
#   エラーが発生した場合 2
# REMARKS:
#   組込 set コマンドの errexit を一時的に無効にし、確認途中のエラーで
#   停止しないようにしている。
#######################################
function check_exec_env() {
    local old_flags="$-"
    set +e  # disable errexit

    _HAS_ERRORS=0
    # aws コマンドがあること
    # aws profile ('default' または --profile オプション指定値) が存在すること
    # aws profile ('default' または --profile オプション指定値) に帯域制限設定が存在すること
    exists_aws_cli
    # openssl コマンドがあること
    exists_openssl
    # $CRYPT_OWNERS_HOME/.ssh/id_rsa, id_rsa.pub 鍵ファイルペアが存在すること
    exists_ssh_key_pair
    # gzip コマンドがあること
    exists_gzip
    # find コマンドがあること
    exists_find

    set "-$old_flags"

    if [[ $_HAS_ERRORS -ne 0 ]]; then
        return 2 # environment error
    else
        return 0
    fi
}

#######################################
# check_running_user()
#--------------------------------------
# 実行ユーザが適切かどうかを確認する
#
# GLOBALS:
#   COMMAND_NAME
#   RUNNABLE_USER
#   TRANSFER_S3_ENV
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT 及び JOURNAL_PATH が示すジャーナルファイルへのメッセージ出力
# RETURN:
#   正常時 0
#   エラーが発生した場合 コード 2 で終了
# REMARKS:
#   TRANSFER_S3_ENV="production" 時に実行ユーザが制限される。
#   それ以外の場合は開発及びテスト時と見做しチェックは行わない。
#######################################
function check_running_user() {
    if [[ $TRANSFER_S3_ENV == "production" ]] && [[ $USER != "$RUNNABLE_USER" ]]; then
        echo "$COMMAND_NAME: You must be run as $RUNNABLE_USER, not $USER." 2>&1
        exit 2
    fi

    return 0
}


#######################################
# -- 開発時の簡易動作確認
#
#   1. check_exec_env 関数の動作確認
#
# ARGUMENTS:
#   なし
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "check_exec_env.sh" ]]; then
    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # 実行ユーザチェックを試す場合は "production" とする
    TRANSFER_S3_ENV="development"

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/error_trap.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/app.sh"

    # Set up default values.
    AWS_PROFILE=$DEF_AWS_PROFILE

    # stub functions for journal.sh
    function journal() {
        echo "$*"
    }
    function journal_err() {
        journal "$*"
    }

    # stub for aws command. all behaviors are normal.
    function aws() {
        if [[ $NO_AWS -ne 0 ]]; then
            return 127
        fi

        if [[ ${*} == "--version" ]]; then
            echo "Version 123"
            return 0
        elif [[ ${*} == "configure get profile.$DEF_AWS_PROFILE.s3.max_bandwidth" ]]; then
            echo "$DEF_S3_BANDWIDTH"
            return 0
        elif [[ ${*} == "configure list-profiles" ]]; then
            echo "profile-A"
            echo "default"
            echo "profile-C"
            return 0
        else
            echo "stub aws(): unexpected argument present($*)." >&2
            return 255
        fi
    }

    # do test
    # # 1st - aws command is exists.
    NO_AWS=0
    check_exec_env
    echo "$COMMAND_NAME: +++ Check passed expectedly."

    # # 2nd - Next function is expected to fail."
    # echo "[Next one should to be print 'aws command is required.']"
    # NO_AWS=1
    # check_exec_env
    # RESULT=$?
    # if [[ $RESULT -ne 0 ]]; then
    #     echo "Error: $RESULT"
    # else
    #     echo "$COMMAND_NAME: --- Sucessfully unexpectedly."
    # fi

    # # 3rd - Next function is expected to fail too.
    # NO_AWS=0
    # AWS_PROFILE=""
    # check_exec_env
    # RESULT=$?
    # if [[ $RESULT -ne 0 ]]; then
    #     echo "Error: $RESULT"
    # else
    #     echo "$COMMAND_NAME: --- Success unexpectedly."
    # fi
    
    # # 4th - Must be run with root.
    # check_running_user
    # # (sudo "$COMMAND_PATH/$COMMAND_NAME")

    # 5th - User CRYPT_KEY_OWNER must be exists.
    check_exec_env

fi

#EOS
