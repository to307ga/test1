#!/usr/bin/env bats

# test_check_exec_env.bats
#
# target functions
#   check_exec_env()
#
# テスト環境に実コマンドがインストールされていない場合、
# 実コマンドに依存するテストはスキップする。
# なお、機能テストとして外部コマンドをモックしたテストも含んでいるため
# 実コマンドがなくとも機能的なテストは十分実施されるようテストケースを
# 作成した。
#

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    # load 'test_helper/bats-file/load'

    # テスト対象のパス '../src' を一時的に PATH に追加することで、
    # 'run テストスクリプト' でパス指定を不要にする。
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    PATH="$DIR/../src:$PATH"

    # 実コマンドをモックして関数をテストするためにここでロードする
    # 注意）関数以外の記述はここで実行されてしまうため、スクリプト
    #       自体のテストでモックすることはできないと考えた方が良い。
    COMMAND_PATH=$(cd "$DIR/../src" && pwd)
    load "$COMMAND_PATH/journal.sh"
    load "$COMMAND_PATH/check_exec_env.sh"
    COMMAND_NAME=$(basename $BATS_TEST_FILENAME .bats)

    # テスト用定数定義
    # 注意）constants.sh にてデフォルト値が変更になった場合、
    #       この設定も変更すること。
    #       アプリケーションの定数定義を参照するために constants.sh 等をテストに
    #       load してはイケない。なぜなら不適切な変更をテストで見つけることができ
    #       なくなるからである。テストコード保守のめんどくささも時には役に立つ。
    # ProfileName="test-transfer-s3"
    ProfileName="default"
    # その他テスト共通の初期値
    CryptKeyOwner="$USER"
    # 期待するバンド幅の値
    Bandwidth="1Mb/s"

    # constant 定義名にマップする
    DEF_S3_BANDWIDTH="$Bandwidth"

    # app.sh のように共通変数を設定する
    CRYPT_KEY_OWNER="$CryptKeyOwner"
    CRYPT_OWNERS_HOME=$(eval echo "~$CryptKeyOwner")
    CRYPT_PRIVATE_KEY="$CRYPT_OWNERS_HOME/.ssh/id_rsa"
    CRYPT_PUBLIC_KEY="$CRYPT_OWNERS_HOME/.ssh/id_rsa.pub"
    CRYPT_CERTIFICATE="$CRYPT_OWNERS_HOME/.ssh/id_rsa.crt"

    # option 変数にマップする
    AWS_PROFILE=$ProfileName

    # stub for journal.sh
    function journal() {
        local dryrun=""
        if [[ $DRYRUN -ne 0 ]]; then
            dryrun="(Dry-Run)"
        fi
        echo "$dryrun$*"
    }
    function journal_err() {
        journal "$*"
    }
    # stub for raise function
    function raise() {
        echo "$1"

        set -e # force errexit to enable.
        local code=${2:-250}
        # return "$code"  # テストの場合は exit が必要。 set -e は効果なし
        exit "$code"
    }
}

# exists_aws_cli 関数は正常時に以下の関数チェーンを実行するため、このテストでは
# 逆順に正常性を確認する。
#   exists_aws_cli -> exists_aws_profile -> exists_aws_bandwidth_restrictions
#

#
# function check_exec_env test
#

# bats test_tags=normal, mock
@test "[001][ normal ][ mock ] check_exec_env" {
    # mock the exists_aws_cli function.
    exists_aws_cli() {
        return 0
    }
    # mock the exists_openssl function.
    exists_openssl() {
        return 0
    }
    # mock the exists_ssh_key_pair function.
    exists_ssh_key_pair() {
        return 0
    }
    # mock the exists_gzip function.
    exists_gzip() {
        return 0
    }
    # mock the exists_find function.
    exists_find() {
        return 0
    }

    # do the test
    run check_exec_env
    assert_success
}

# bats test_tags=abnormal, mock
@test "[002][abnormal][ mock ] check_exec_env some command is not exists" {
    # mock the exists_aws_cli function.
    exists_aws_cli() {
        return 0
    }
    # mock the exists_openssl function.
    exists_openssl() {
        return 0
    }
    # mock the exists_ssh_key_pair function.
    exists_ssh_key_pair() {
        return 0
    }
    # mock the exists_gzip function.
    exists_gzip() {
        return 0
    }
    # mock the exists_find function.
    exists_find() {
        _HAS_ERRORS=1
        return 0
    }

    # do the test
    run check_exec_env
    assert_failure 2
}

# bats test_tags=normal, actual
@test "[003][ normal ][actual] check_exec_env" {
    # openssl
    if ! openssl version; then
        skip "because the test depends on the actual openssl command."
    fi

    # gzip
    if ! gzip --version; then
        skip "because the test depends on the actual gzip command."
    fi

    # find
    if ! find --version; then
        skip "because the test depends on the actual find command."
    fi

    # aws
    if ! aws --version; then
        skip "because the test depends on the actual aws command."
    fi

    echo "# ※事前に aws テスト用プロファイル '$AWS_PROFILE' が構成済みでなければテストは失敗します。" >&3
    echo "# ※事前にユーザ '$CRYPT_KEY_OWNER' がSSH用鍵ペアを持っていないとテストは失敗します。" >&3

    # do the test
    run check_exec_env
    assert_success
}

#EOS
