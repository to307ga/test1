#!/usr/bin/env bats

# test_main.bats
# as test transfer-s3.sh

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

    # 期待するバージョン番号
    EXPECTED_VERSION="0.1.3"

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"
}

teardown() {
    # 作成した一時ディレクトリを削除する
    temp_del "$TEST_TEMP_DIR"
}

# bats test_tags=normal, args
@test "[001][ normal ] version option" {
    export TRANSFER_S3_ENV=testing # skip running user confirmation.

    run transfer-s3.sh --version
    assert_failure 1
    assert_output "Version $EXPECTED_VERSION"
}

# bats test_tags=normal, args
@test "[002][ normal ] help option" {
    export TRANSFER_S3_ENV=testing # skip running user confirmation.

    run transfer-s3.sh --help
    assert_failure 1
    assert_line "transfer-s3.sh - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion."
}

# bats test_tags=abnormal, args
@test "[003][abnormal] no argument specified" {
    export TRANSFER_S3_ENV=testing # skip running user confirmation.

    run transfer-s3.sh
    assert_failure 1
    assert_line "transfer-s3.sh: No S3 bucket name specified."
}

# bats test_tags=abnormal, args
@test "[004][abnormal] no source directory specified" {
    export TRANSFER_S3_ENV=testing # skip running user confirmation.

    run transfer-s3.sh bucket_name
    assert_failure 1
    assert_line "transfer-s3.sh: No backup source directory specified."
}

# bats test_tags=abnormal, root
@test "[005][abnormal] no root user execution" {
    export TRANSFER_S3_ENV=production

    run transfer-s3.sh bucket_name directory_name
    assert_failure 2
    assert_line "transfer-s3.sh: You must be run as root, not $USER."
}

# bats test_tags=normal, journal
@test "[006][ normal ] command line journaling" {
    # BATSLIB_TEMP_PRESERVE=1
    
    export TRANSFER_S3_ENV=testing # skip running user confirmation.

    source_dir="$TEST_TEMP_DIR/test"
    mkdir -p $source_dir

    # echo "# src_dir: $source_dir" >&3

    run transfer-s3.sh --dry-run --verbose bucket_name "$source_dir"
    assert_success
    assert_line --regexp "transfer-s3 begins with command line: '.*transfer-s3.sh --dry-run --verbose bucket_name $source_dir'"
}


#EOS
