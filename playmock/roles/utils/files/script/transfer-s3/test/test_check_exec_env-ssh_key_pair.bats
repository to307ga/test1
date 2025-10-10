#!/usr/bin/env bats

# test_check_exec_env-ssh_key_pair.bats
#
# target functions
#   exists_ssh_key_pair()
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
    load 'test_helper/bats-file/load'

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

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"

    # stub for journal.sh
    function journal() {
        echo "$*"
    }
    function journal_err() {
        echo "$*"
    }
}

teardown() {
    # 作成した一時ディレクトリを削除する
    temp_del "$TEST_TEMP_DIR"
}

@test "[001][ normal ][------] exists_ssh_key_pair there is key-pair and crt file" {
    # key owner for testing
    CRYPT_KEY_OWNER=testuser
    CRYPT_OWNERS_HOME=$TEST_TEMP_DIR

    # make dummy key-pair and pem file
    CRYPT_PRIVATE_KEY=$TEST_TEMP_DIR/.ssh/id_rsa
    CRYPT_PUBLIC_KEY=$TEST_TEMP_DIR/.ssh/id_rsa.pub
    CRYPT_CERTIFICATE=$TEST_TEMP_DIR/.ssh/id_rsa.crt

    mkdir $TEST_TEMP_DIR/.ssh
    echo "id_rsa for testing." >$CRYPT_PRIVATE_KEY
    echo "id_rsa.pub for testing." >$CRYPT_PUBLIC_KEY
    echo "id_rsa.crt for testing." >$CRYPT_CERTIFICATE

    # do the test
    run exists_ssh_key_pair
    assert_success
    assert_output "use $CRYPT_CERTIFICATE as a certificate for encryption."
}

@test "[002][abnormal][------] exists_ssh_key_pair there is no key-pair file" {
    # key owner for testing
    CRYPT_KEY_OWNER='testuser'
    CRYPT_OWNERS_HOME=$TEST_TEMP_DIR

    # make dummy .ssh directory only
    CRYPT_PRIVATE_KEY=$TEST_TEMP_DIR/.ssh/id_rsa
    CRYPT_PUBLIC_KEY=$TEST_TEMP_DIR/.ssh/id_rsa.pub
    CRYPT_CERTIFICATE=$TEST_TEMP_DIR/.ssh/id_rsa.crt

    mkdir $TEST_TEMP_DIR/.ssh

    # do the test
    run exists_ssh_key_pair
    assert_success
    # assert_equal $HAS_ERRORS 1 # <-- 関数で設定した変数がテストからは読めない
    assert_output --partial "$COMMAND_NAME: An SSH key pair file is required; create a key pair file for user testuser using the command 'ssh-keygen -t rsa -m pem'."
}

@test "[003][ normal ][ mock ] exists_ssh_key_pair there is key-pair file and no crt file, certificate created successfully" {
    # key owner for testing
    CRYPT_KEY_OWNER='testuser'
    CRYPT_OWNERS_HOME=$TEST_TEMP_DIR

    # make dummy key-pair
    CRYPT_PRIVATE_KEY=$CRYPT_OWNERS_HOME/.ssh/id_rsa
    CRYPT_PUBLIC_KEY=$CRYPT_OWNERS_HOME/.ssh/id_rsa.pub
    CRYPT_CERTIFICATE=$CRYPT_OWNERS_HOME/.ssh/id_rsa.crt

    mkdir $CRYPT_OWNERS_HOME/.ssh
    echo "id_rsa for testing." >$CRYPT_PRIVATE_KEY
    echo "id_rsa.pub for testing." >$CRYPT_PUBLIC_KEY

    # mock the openssl
    openssl() {
        local args
        args="req -x509 -new -key $CRYPT_PRIVATE_KEY -subj / -out $CRYPT_CERTIFICATE"
        if [[ ${*} == $args ]]; then
            return 0 # success
        else
            echo "# openssl コマンド行が期待値と異なる。" >&3
            echo "#   期待値：'$args'" >&3
            echo "# 実際の値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_ssh_key_pair
    assert_success
    assert_output --partial "WARNING: SSH certificate file is not found. Now creating certificate from private key."
    assert_output --partial "$CRYPT_CERTIFICATE is created and used for encryption."
}

@test "[004][abnormal][ mock ] exists_ssh_key_pair there is key-pair file and no crt file, certificate created failure" {
    # key owner for testing
    CRYPT_KEY_OWNER='testuser'
    CRYPT_OWNERS_HOME=$TEST_TEMP_DIR

    # make dummy key-pair
    CRYPT_PRIVATE_KEY=$TEST_TEMP_DIR/.ssh/id_rsa
    CRYPT_PUBLIC_KEY=$TEST_TEMP_DIR/.ssh/id_rsa.pub
    CRYPT_CERTIFICATE=$TEST_TEMP_DIR/.ssh/id_rsa.crt

    mkdir $TEST_TEMP_DIR/.ssh
    echo "id_rsa for testing." >$CRYPT_PRIVATE_KEY
    echo "id_rsa.pub for testing." >$CRYPT_PUBLIC_KEY

    # mock the openssl
    ARGS="req -x509 -new -key $CRYPT_PRIVATE_KEY -subj / -out $CRYPT_CERTIFICATE"
    openssl() {
        if [[ ${*} == $ARGS ]]; then
            return 1 # failed
        else
            echo "# openssl コマンド行が期待値と異なる。" >&3
            echo "#   期待値：'$ARGS'" >&3
            echo "# 実際の値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_ssh_key_pair
    assert_failure 1
    assert_output --partial "WARNING: SSH certificate file is not found. Now creating certificate from private key."
    assert_output --partial "$COMMAND_NAME: Failed to create certificate file. Please check the following openssl command line and exit code(1)."
    assert_output --partial "'openssl $ARGS'"
}

@test "[005][ normal ][actual] exists_ssh_key_pair there is key-pair file and no crt file, certificate created successfully" {
    # key owner for testing
    CRYPT_KEY_OWNER='testuser'
    CRYPT_OWNERS_HOME=$TEST_TEMP_DIR

    if ! openssl version ; then
        skip "because the test depends on the actual command."
    fi

    CRYPT_PRIVATE_KEY=$TEST_TEMP_DIR/.ssh/id_rsa
    CRYPT_PUBLIC_KEY=$TEST_TEMP_DIR/.ssh/id_rsa.pub
    CRYPT_CERTIFICATE=$TEST_TEMP_DIR/.ssh/id_rsa.crt

    # 鍵ペアが無ければテスト失敗
    assert_file_exists $HOME/.ssh/id_rsa
    assert_file_exists $HOME/.ssh/id_rsa.pub

    # 鍵ペアを一時ディレクトリにコピー
    mkdir $TEST_TEMP_DIR/.ssh
    cp $HOME/.ssh/id_rsa $CRYPT_PRIVATE_KEY
    cp $HOME/.ssh/id_rsa.pub $CRYPT_PUBLIC_KEY

    # do the test
    run exists_ssh_key_pair
    assert_success
    assert_output --partial "WARNING: SSH certificate file is not found. Now creating certificate from private key."
    assert_output --partial "$CRYPT_CERTIFICATE is created and used for encryption."
}

@test "[006][abnormal][------] exists_ssh_key_pair CRYPT_OWNERS_HOME is not exist." {
    # key owner for testing
    CRYPT_KEY_OWNER='testuser'
    CRYPT_OWNERS_HOME='/home/testuser'

    # do the test
    run exists_ssh_key_pair
    assert_success
    assert_output "$COMMAND_NAME: The user $CRYPT_KEY_OWNER who owns the SSH key pair for encryption does not exist."
}


#EOS
