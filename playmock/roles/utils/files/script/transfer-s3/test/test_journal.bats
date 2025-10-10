#!/usr/bin/env bats

# test_journal.bats

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

    # 関数単位でテストするためロードする
    COMMAND_PATH=$(cd "$DIR/../src" && pwd)
    COMMAND_NAME=$(basename $BATS_TEST_FILENAME .bats)
    load "$COMMAND_PATH/constants.sh"
    load "$COMMAND_PATH/journal.sh"

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"

}

teardown() {
    # 作成した一時ディレクトリを削除する
    temp_del "$TEST_TEMP_DIR"
}

@test "[001][ normal ] journal with no dry-run and no verbose." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=0
    VERBOSE=0

    touch "$JOURNAL_PATH"

    # do test
    message="---journal message---"
    run journal "$message"

    assert_success

    # no verbose: コンソール出力無し、ジャーナルファイルのみ
    # no dry-run: (Dry-Run)マーク無し
    refute_output

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\] $message$"

}

@test "[002][ normal ] journal with verbose and no dry-run." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=0
    VERBOSE=1

    touch "$JOURNAL_PATH"

    # do test
    message="---journal message---"
    run journal "$message"

    assert_success

    # verbose: コンソール出力あり、ジャーナルファイル出力あり
    # no dry-run: (Dry-Run)マーク無し
    assert_output "$message"

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\] $message$"

}

@test "[003][ normal ] journal with dry-run and no verbose." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=1
    VERBOSE=0

    touch "$JOURNAL_PATH"

    # do test
    message="---journal message---"
    run journal "$message"

    assert_success

    # no verbose: コンソール出力無し、ジャーナルファイルのみ
    # dry-run: (Dry-Run)マーク有り
    refute_output

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\](Dry-Run) $message$"
    # hint: BRE(基本正規表現)では メタ文字 ?,+,{,|,(,) はただの文字
    #       -E オプションでERE(拡張正規表)を指定するかまたは、バックスラッシュ
    #       を付けることでメタ文字として使うことができる。

}

@test "[004][ normal ] journal with verbose and dry-run." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=1
    VERBOSE=1

    touch "$JOURNAL_PATH"

    # do test
    message="---journal message---"
    run journal "$message"

    assert_success

    # verbose: コンソール出力あり、ジャーナルファイル出力あり
    # dry-run: (Dry-Run)マーク有り
    assert_output "(Dry-Run)$message"

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\](Dry-Run) $message$"

}

@test "[005][ normal ] journal_err with no dry-run and no verbose." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal_err.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=0
    VERBOSE=0

    touch "$JOURNAL_PATH"

    # do test
    message="---journal error message---"
    run journal_err "$message"

    assert_success

    # no verbose: コンソール出力有り、ジャーナルファイル出力有り
    # no dry-run: (Dry-Run)マーク無し
    assert_output "$message"

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\] $message$"

}

@test "[006][ normal ] journal_err with verbose and no dry-run." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal_err.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=0
    VERBOSE=1

    touch "$JOURNAL_PATH"

    # do test
    message="---journal error message---"
    run journal_err "$message"

    assert_success

    # verbose: コンソール出力あり、ジャーナルファイル出力あり
    # no dry-run: (Dry-Run)マーク無し
    assert_output "$message"

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\] $message$"

}

@test "[007][ normal ] journal_err with dry-run and no verbose." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal_err.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=1
    VERBOSE=0

    touch "$JOURNAL_PATH"

    # do test
    message="---journal error message---"
    run journal_err "$message"

    assert_success

    # no verbose: コンソール出力有り、ジャーナルファイル出力有り
    # dry-run: (Dry-Run)マーク有り
    assert_output "(Dry-Run)$message"

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\](Dry-Run) $message$"
    # hint: BRE(基本正規表現)では メタ文字 ?,+,{,|,(,) はただの文字
    #       -E オプションでERE(拡張正規表)を指定するかまたは、バックスラッシュ
    #       を付けることでメタ文字として使うことができる。

}

@test "[008][ normal ] journal_err with verbose and dry-run." {

    BATSLIB_TEMP_PRESERVE=0
    JOURNAL_PATH="$TEST_TEMP_DIR/journal.txt"
    # echo "# JOURNAL_PATH: $JOURNAL_PATH" >&3

    DRYRUN=1
    VERBOSE=1

    touch "$JOURNAL_PATH"

    # do test
    message="---journal message---"
    run journal_err "$message"

    assert_success

    # verbose: コンソール出力あり、ジャーナルファイル出力あり
    # dry-run: (Dry-Run)マーク有り
    assert_output "(Dry-Run)$message"

    today=$(date +%Y-%m-%d)
    assert_file_contains "$JOURNAL_PATH" "^\[$today.*\](Dry-Run) $message$"

}

#EOS
