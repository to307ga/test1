#!/usr/bin/env bats

# test_check_exec_env-openssl.bats
#
# target functions
#   exists_openssl()
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
    load "$COMMAND_PATH/check_exec_env.sh"
    COMMAND_NAME=$(basename $BATS_TEST_FILENAME .bats)

    # stub for journal.sh
    function journal() {
        echo "$*"
    }
    function journal_err() {
        echo "$*"
    }
}

@test "[001][ normal ][ mock ] exists_openssl there is openssl" {
    # mock the openssl command
    openssl() {
        if [[ ${*} == "version" ]]; then
            echo "(Bats)OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)"
            return 0
        else
            echo "# openssl コマンド行が期待値と異なる。" >&3
            echo "# 期待値：'version'" >&3
            echo "# 実際の値： $*" >&3
            return 255
        fi
    }

    # do the test
    run exists_openssl
    assert_success
}

@test "[002][abnormal][ mock ] exists_openssl there is no openssl" {
    # mock the openssl command
    openssl() {
        if [[ ${*} == "version" ]]; then
            return 255
        else
            echo "# openssl コマンド行が期待値と異なる。" >&3
            echo "# 期待値：'version'" >&3
            echo "# 実際の値： $*" >&3
            return 255
        fi
    }

    # do the test
    run exists_openssl
    assert_success
    # assert_equal $HAS_ERRORS 1 # <-- 関数で設定した変数がテストからは読めない
    assert_output --partial "$COMMAND_NAME: openssl command is required."
}

@test "[003][ normal ][actual] exists_openssl there is openssl" {
    if ! openssl version ; then
        skip "because the test depends on the actual command."
    fi

    # do the test
    run exists_openssl
    assert_success
}

#EOS
