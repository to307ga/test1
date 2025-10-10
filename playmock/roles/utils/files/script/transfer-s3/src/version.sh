#!/usr/bin/env bash
# version.sh
# transfer-s3: Show a version number.

#######################################
# version()
#--------------------------------------
# バージョン番号の出力
#
# GLOBALS:
#   COMMAND_VERSION
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT に出力
# RETURN:
#   常に 0
#######################################
function version() {
    echo "$COMMAND_VERSION"
    return 0
}


#######################################
# -- 開発時の簡易動作確認
#
#   1. version 関数の動作確認
#
# ARGUMENTS:
#   なし
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "version.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"

    version

fi

#EOS
