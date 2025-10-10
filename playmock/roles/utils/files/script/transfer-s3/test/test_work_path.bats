#!/usr/bin/env bats

# test_work_path.bats

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


    # stub for raise function
    function raise() {
        echo "$1"

        set -e # force enable errexit.
        local code=${2:-250}
        return "$code"
    }

}

teardown() {
    # 作成した一時ディレクトリを削除する
    temp_del "$TEST_TEMP_DIR"
}

@test "[001][abnormal] no arguments specified" {
    run work_path.sh
    assert_failure 250
    assert_output --partial "work_path.sh: Missing parameter SOURCE_DIRS for function prepare_working_dir_and_path call."
}

@test "[002][ normal ] create working dir and paths" {
    today=$(date +%Y%m%d)

    run work_path.sh "$TEST_TEMP_DIR"

    assert_success
    assert_output --partial "SOURCE_PATHS: 1: $TEST_TEMP_DIR"
    assert_output --partial "WORK_PATH: $TEST_TEMP_DIR/.work_path"
    assert_output --partial "JOURNAL_PATH: $TEST_TEMP_DIR/.work_path/work_path-journal-$today.txt"

    assert_dir_exists "$TEST_TEMP_DIR/.work_path"

    assert_file_exists "$TEST_TEMP_DIR/.work_path/work_path-journal-$today.txt"
}

@test "[003][abnormal] failed to create working dir" {
    today=$(date +%Y%m%d)

    (chmod -w $TEST_TEMP_DIR)

    run work_path.sh "$TEST_TEMP_DIR"

    (chmod +w $TEST_TEMP_DIR)

    assert_failure
    assert_output --partial "Permission denied"
}

@test "[004][abnormal] failed to create journaling file" {
    today=$(date +%Y%m%d)
    work_path="$TEST_TEMP_DIR/.work_path"
    journal_path=$work_path/.work_path/journal-$today.txt
    (mkdir -p $work_path)
    (chmod -w $work_path)

    run work_path.sh "$TEST_TEMP_DIR"

    (chmod +w $work_path)

    assert_failure
    assert_output --partial "Permission denied"
}

@test "[005][ normal ] journal filename with journal id" {
    today=$(date +%Y%m%d)

    export JOURNAL_ID="TEST"

    run work_path.sh "$TEST_TEMP_DIR"

    assert_success
    assert_output --partial "JOURNAL_PATH: $TEST_TEMP_DIR/.work_path/work_path-journal-TEST-$today.txt"

    assert_file_exists "$TEST_TEMP_DIR/.work_path/work_path-journal-TEST-$today.txt"
}



#EOS
