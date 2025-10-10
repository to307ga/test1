#!/usr/bin/env bash
# crypt.sh
# transfer-s3: encrypt/decrypt a file.

# encrypt/decrypt command line as a array
CRYPT_CMD=(openssl version)

#######################################
# make_encrypt_commandline(from, to)
#--------------------------------------
# 指定ファイルを暗号化するコマンド行を作成する
# to は省略できない
# to に指定したファイルはディレクトリ構造を含め書き込み可能でなければならない
#
# GLOBALS:
#   CRYPT_CERTIFICATE - 暗号化用証明書のパス
#                       証明書は以下のコマンドで作成できる
#                       $ openssl req -x509 -new -key "$HOME/.ssh/id_rsa" \
#                         -subj '/' -out "$HOME/.ssh/id_rsa.crt"
#                       $ export CRYPT_CERTIFICATE="$HOME/.ssh/id_rsa.crt"
# ARGUMENTS:
#   $1: from  - 暗号元ファイルパス
#   $2: to    - 暗号化ファイルパス
# OUTPUTS:
#   CRYPT_CMD 配列
# RETURN:
#   常に 0
# REMARKS:
#   エラーチェックを行っていないため、引数は正しく与えること。
#   作成されたコマンド CRYPT_CMD は以下の様に実行できる
#   ("${CRYPT_CMD[@]}")
#######################################
function make_encrypt_commandline() {
    local from=${1:-}
    local to=${2:-}

    CRYPT_CMD=(openssl smime -encrypt -aes256 -in "$from" -binary -outform DEM -out "$to" "$CRYPT_CERTIFICATE")
    return 0
}

#######################################
# encrypt(from, to=null)
#--------------------------------------
# 指定ファイルを暗号化する
# to を省略した場合、from と同じディレクトリに拡張子 .enc が付いた
# 暗号化ファイルを作成する
# 暗号化ファイルが作成されるディレクトリ構造は必要があれば作成される
#
# GLOBALS:
#   COMMAND_NAME
# ARGUMENTS:
#   $1: from  - 暗号元ファイルパス
#   $2: to    - 暗号化ファイルパス(オプション)
# OUTPUTS:
#   to に指定した暗号化ファイル
# RETURN:
#   成功時 0
#   0 以外はエラー発生を表す
# REMARKS:
#   引数にエラーが発生した場合、raise 関数により処理が中断する
#######################################
function encrypt() {
    local from=${1:-}
    if [[ ! -f "$from" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): '$from' is not a regular file."
    fi

    local to=${2:-}
    if [[ -z "$to" ]]; then
        to="$from.enc"
    fi

    # make a directory for encrypted file if not exists.
    local dir_to
    dir_to=$(dirname "$to")
    if [[ ! -d "dir_to" ]]; then
        mkdir -p "$dir_to"
    fi

    make_encrypt_commandline "$from" "$to"

    ("${CRYPT_CMD[@]}")
    return "$?"
}

#######################################
# make_decrypt_commandline(from, to)
#--------------------------------------
# 指定ファイルを復号化するコマンド行を作成する
# to は省略できない
# to に指定したファイルはディレクトリ構造を含め書き込み可能でなければならない
#
# GLOBALS:
#   CRYPT_PRIVATE_KEY - 復号化するためのプライベートキーのパス
#                       暗号化用証明書を作成したキーでなければならない
#                       通常これは $HOME/.ssh/id_rsa
# ARGUMENTS:
#   $1: from - 暗号化ファイルパス
#   $2: to   - 復号化ファイルパス
# OUTPUTS:
#   CRYPT_CMD 配列
# RETURN:
#   エラーチェックを行っていないため、引数は正しく与えること。
#   作成されたコマンド CRYPT_CMD は以下の様に実行できる
#   ("${CRYPT_CMD[@]}")
#######################################
function make_decrypt_commandline() {
    local from=${1:-}
    local to=${2:-}

    CRYPT_CMD=(openssl smime -decrypt -in "$from" -binary -inform DEM -inkey "$CRYPT_PRIVATE_KEY" -out "$to")
    return 0
}

#######################################
# decrypt(from, to)
#--------------------------------------
# 指定ファイルを復号化する
# to は省略できない
# 復号化ファイルが作成されるディレクトリ構造は必要があれば作成される
#
# GLOBALS:
#   COMMAND_NAME
# ARGUMENTS:
#   $1: from - 暗号化ファイルパス
#   $2: to   - 復号化ファイルパス
# OUTPUTS:
#   to に指定した復号化ファイル
# RETURN:
#   成功時 0
#   0 以外はエラー発生を表す
#######################################
function decrypt() {
    local from=${1:-}
    local to=${2:-}
    if [[ ! -f "$from" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): '$from' is not a regular file."
    fi
    if [[ -z "$to" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): decrypted file path is not specified as argument 2."
    fi

    # make a directory for decrypted file if not exists.
    local dir_to
    dir_to=$(dirname "$to")
    if [[ ! -d "dir_to" ]]; then
        mkdir -p "$dir_to"
    fi

    make_decrypt_commandline "$from" "$to"

    ("${CRYPT_CMD[@]}")
    return "$?"
}



#######################################
# -- 開発時の簡易動作確認
#
#   1. encrypt 関数の動作確認
#   2. decrypt 関数の動作確認
#
# ARGUMENTS:
#   $1: ファイル
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "crypt.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # load for raise()
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/error_trap.sh"
    # stub for journal.sh
    function journal() {
        echo "$*"
    }
    function journal_err() {
        echo "$*"
    }

    # encrypt/decrypt key
    CRYPT_PRIVATE_KEY="$HOME/.ssh/id_rsa"
    CRYPT_CERTIFICATE="$HOME/.ssh/id_rsa.crt"

    if [[ ! -f "$CRYPT_CERTIFICATE" ]]; then
        echo "暗号化用の証明書 $CRYPT_CERTIFICATE が必要"
        exit 1
    fi

    # encrypt source file
    FILE=${1:-}
    if [[ -z $FILE ]]; then
        echo "Usage: crypt.sh <testfile>"
        exit 1
    fi

    encrypt "$FILE"

    decrypt "$FILE.enc" "$FILE.dec"

    diff "$FILE" "$FILE.dec"
fi

#EOS
