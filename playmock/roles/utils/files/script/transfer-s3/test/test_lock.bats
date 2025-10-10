#!/usr/bin/env bats

# test_lock.bats

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # make executables in src/ visible to PATH
    PATH="$DIR/../src:$PATH"

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"
}

teardown() {
    # 作成した一時ディレクトリを削除する
    temp_del "$TEST_TEMP_DIR"
}

@test "[001][ normal ] lock and unlock" {
    WORK_PATH=$TEST_TEMP_DIR
    export WORK_PATH
    # 1st
    run lock.sh
    assert_success
    assert_file_not_exists $WORK_PATH/lock.lock

    # 2nd - 1st が終了した時点でUnlockされているはず
    run lock.sh
    assert_success
    assert_file_not_exists $WORK_PATH/lock.lock
}

@test "[002][abnormal] multiple start failed" {
    WORK_PATH=$TEST_TEMP_DIR
    export WORK_PATH
    # 1st run as background.
    lock.sh &
    sleep 1
    assert_file_exists $WORK_PATH/lock.lock

    # 2nd - ロックに失敗するはず
    run lock.sh
    assert_failure 1
    assert_output --partial "lock is already running."
}

#EOS
