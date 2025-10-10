#!/usr/bin/env bats

# test_options.bats

# bats --filter-tags オプションにタグを指定してテスト対象を絞り込むことができます(bats 1.8.0 以降が必要)
# タグには相互関連や階層構造など上下関係は無く、単に指定したタグに一致するテストが実施されます。
#
# コマンド例：
#   bats test/test_options.bats --filter-tags main,args
#
# タグ一覧：
#   args      引数テスト
#   help      help オプションのテスト
#   version   version オプションのテスト
#   profile   profile オプションのテスト
#   gzip      gzip-older-than オプションのテスト
#   move      move-older-than オプションのテスト
#   dry       dry-run オプションのテスト
#   verbose   verbose オプションのテスト
#   nonrecurs non-recursive オプションのテスト
#   include   include オプションのテスト
#   bucket    s3_bucket_name パラメータのテスト
#   dirs      backup_source_directory パラメータのテスト
#

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/../src:$PATH"

    # 期待するバージョン番号
    EXPECTED_VERSION="0.1.3"

    # unset all variables
    unset AWS_PROFILE
    unset GZIP_OLDER_THAN
    unset DEELTE_OLDER_THAN
    unset DRYRUN
    unset VERBOSE
    unset AWS_S3_BUCKET
    unset SOURCE_DIR
    unset NON_RESURSIVE
    unset INCLUDE_PATTERNS
    unset MOVE_ONE_BY_ONE
    unset JOURNAL_ID

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"
}

teardown() {
    # 作成した一時ディレクトリを削除する
    temp_del "$TEST_TEMP_DIR"
}

# bats test_tags=abnormal, args
@test "[001][abnormal] no arguments specified" {
    run options.sh
    assert_failure 1
    assert_line "options.sh: No S3 bucket name specified."
    assert_output --partial "Usage:"
}

# bats test_tags=normal, args
@test "[002][ normal ] no options specified" {
    run options.sh "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "AWS_PROFILE='default'"
    assert_output --partial "GZIP_OLDER_THAN=30"
    assert_output --partial "MOVE_OLDER_THAN=90"
    assert_output --partial "DRYRUN=0"
    assert_output --partial "VERBOSE=0"
    assert_output --partial "NON_RECURSIVE=0"
    assert_output --partial "AWS_S3_BUCKET=bucket_name"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
    assert_output --partial "MOVE_ONE_BY_ONE=0"
    assert_output --partial "JOURNAL_ID=''"
}

# bats test_tags=normal, help
@test "[003][ normal ] specify --help option" {
    run options.sh --help
    assert_failure 1
    assert_output --partial "options.sh - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion."
}

# bats test_tags=normal, help
@test "[004][ normal ] specify -h option" {
    run options.sh -h
    assert_failure 1
    assert_output --partial "options.sh - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion."
}


# bats test_tags=normal, version
@test "[005][ normal ] specify --version option" {
    run options.sh --version
    assert_failure 1
    assert_output "Version $EXPECTED_VERSION"
}

# bats test_tags=normal, version
@test "[006][ normal ] specify -V option" {
    run options.sh -V
    assert_failure 1
    assert_output "Version $EXPECTED_VERSION"
}


# bats test_tags=normal, help
@test "[007][ normal ] options after the help option are ignored" {
    run options.sh -h --version "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 1
    assert_output --partial "options.sh - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion."
}

# bats test_tags=normal, help
@test "[008][ normal ] options after the help option are ignored 2" {
    run options.sh "bucket_name" "$TEST_TEMP_DIR" -h --version 
    assert_failure 1
    assert_output --partial "options.sh - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion."
}


# bats test_tags=normal, version
@test "[009][ normal ] options after the version option are ignored" {
    run options.sh -V -h "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 1
    assert_output "Version $EXPECTED_VERSION"
}

# bats test_tags=normal, version
@test "[010][ normal ] options after the version option are ignored 2" {
    run options.sh "bucket_name" "$TEST_TEMP_DIR" -V -h 
    assert_failure 1
    assert_output "Version $EXPECTED_VERSION"
}


# bats test_tags=normal, profile
@test "[011][ normal ] specify --profile option" {
    run options.sh --profile test-profile "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "AWS_PROFILE='test-profile'"
}

# bats test_tags=normal, profile
@test "[012][ normal ] specify -p option" {
    run options.sh -p test-profile "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "AWS_PROFILE='test-profile'"
}

# bats test_tags=abnormal, profile, args
@test "[013][abnormal] specify --profile without profile name" {
    run options.sh --profile
    assert_failure 1
    assert_output --partial "options.sh: option '--profile' requires an argument"
}

# bats test_tags=abnormal, profile, args
@test "[014][abnormal] specify profile option without profile name" {
    run options.sh -p
    assert_failure 1
    assert_output --partial "options.sh: option requires an argument -- 'p'"
}


# bats test_tags=normal, gzip
@test "[015][ normal ] specify --gzip-older-than option" {
    run options.sh --gzip-older-than 12 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "GZIP_OLDER_THAN=12"
}

# bats test_tags=normal, gzip
@test "[016][ normal ] specify -g option" {
    run options.sh -g 21 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "GZIP_OLDER_THAN=21"
}

# bats test_tags=abnormal, gzip, args
@test "[017][abnormal] specify --gzip-older-than option without days" {
    run options.sh --gzip-older-than
    assert_failure 1
    assert_output --partial "options.sh: option '--gzip-older-than' requires an argument"
}

# bats test_tags=abnormal, gzip, args
@test "[018][abnormal] specify -g option without days" {
    run options.sh -g
    assert_failure 1
    assert_output --partial "options.sh: option requires an argument -- 'g'"
}

# bats test_tags=abnormal, gzip, args
@test "[019][abnormal] specify --gzip-older-than option with not a number" {
    run options.sh --gzip-older-than 1ABC "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -g|--gzip-older-than <days>: specified days is not a number."
}

# bats test_tags=abnormal, gzip, args
@test "[020][abnormal] specify -g option with not a number" {
    run options.sh -g 1ABC "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -g|--gzip-older-than <days>: specified days is not a number."
}

# bats test_tags=abnormal, gzip, args
@test "[021][abnormal] specify --gzip-older-than option with 0" {
    run options.sh --gzip-older-than 0 "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -g|--gzip-older-than <days>: days must be greater than or equals 1."
}

# bats test_tags=abnormal, gzip, args
@test "[022][abnormal] specify -g option with 0" {
    run options.sh -g 0 "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -g|--gzip-older-than <days>: days must be greater than or equals 1."
}


# bats test_tags=normal, move
@test "[023][ normal ] specify --move-older-than option" {
    run options.sh --move-older-than 123 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "MOVE_OLDER_THAN=123"
}

# bats test_tags=normal, move
@test "[024][ normal ] specify -m option" {
    run options.sh -m 321 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "MOVE_OLDER_THAN=321"
}

# bats test_tags=abnormal, move, args
@test "[025][abnormal] specify --move-older-than option without days" {
    run options.sh --move-older-than
    assert_failure 1
    assert_output --partial "options.sh: option '--move-older-than' requires an argument"
}

# bats test_tags=abnormal, move, args
@test "[026][abnormal] specify -m option without days" {
    run options.sh -m
    assert_failure 1
    assert_output --partial "options.sh: option requires an argument -- 'm'"
}

# bats test_tags=abnormal, move, args
@test "[027][abnormal] specify -m with under 30 value" {
    run options.sh -m 29 "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -m|--move-older-than <days>: days must be greater than or equals 30."
}

# bats test_tags=abnormal, move, args
@test "[028][abnormal] specify -m option with not a number" {
    run options.sh -m 1ABC "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -m|--move-older-than <days>: specified days is not a number."
}


# bats test_tags=normal, gzip, move, args
@test "[029][ normal ] specify same days with -g and -m option" {
    run options.sh -g 10 -m 10 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, gzip, move, args
@test "[030][ normal ] specify days on normal order with -g and -m option" {
    run options.sh -g 10 -m 11 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=abnormal, gzip, move, args
@test "[031][abnormal] specify days on inverted order with -g and -m option" {
    run options.sh -g 11 -m 10 "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_output "options.sh: -m|--move-older-than <days>: days must be greater than or equals 11."
}


# bats test_tags=normal, dry
@test "[032][ normal ] specify --dry-run option" {
    run options.sh --dry-run "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "DRYRUN=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, dry
@test "[033][ normal ] specify -R option" {
    run options.sh -R "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "DRYRUN=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}


# bats test_tags=normal, verbose
@test "[034][ normal ] specify --verbose option" {
    run options.sh --verbose "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "VERBOSE=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, verbose
@test "[035][ normal ] specify -v option" {
    run options.sh -v "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "VERBOSE=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=abnormal, args
@test "[036][abnormal] no backup source directory specifyed" {
    run options.sh "bucket_name"
    assert_failure 1
    assert_line "options.sh: No backup source directory specified."
}


# bats test_tags=normal, nonrecurs, args
@test "[037][ normal ] specify --non-recursive option" {
    run options.sh --non-recursive "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "NON_RECURSIVE=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, nonrecurs, args
@test "[038][ normal ] specify -n option" {
    run options.sh -n "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "NON_RECURSIVE=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}


# bats test_tags=normal, include, args
@test "[039][ normal ] specify --include option" {
    run options.sh --include="pattern1*" "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "INCLUDE_PATTERNS='pattern1*'"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, include, args
@test "[040][ normal ] specify -i option" {
    run options.sh -i "pattern1*,pattern2*,pat*.dat" "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "INCLUDE_PATTERNS='pattern1*,pattern2*,pat*.dat'"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=abnormal, include, args
@test "[041][abnormal] specify --include option without parameters" {
    run options.sh --include "bucket_name" "$TEST_TEMP_DIR"
    assert_failure 
    assert_line "options.sh: No backup source directory specified."
}

# bats test_tags=normal, include, args
@test "[042][ normal ] specify --include option with two or more patterns" {
    run options.sh --include="pattern1*,pattern2*,pat*.dat" "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "INCLUDE_PATTERNS='pattern1*,pattern2*,pat*.dat'"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=abnormal, include, args
@test "[043][abnormal] specify --include option without parameters" {
    run options.sh --include "bucket_name" "$TEST_TEMP_DIR" "$TEST_TEMP_DIR"
    # getopt の仕様上、"bucket_name" を --incloude オプションパラメータとして
    # 取ってしまうため、次の backup_source_directory を s3_backet_name として
    # 取得してしまう。
    # バケット名に '/' は含められないのでエラーとなる。
    assert_failure 2
    assert_line "options.sh: s3_bucket_name cannot contain the path separator '/'"
    # が、これは完全な防御策ではない。
}

# bats test_tags=abnormal, include, args
@test "[044][abnormal] specify --include option with pattern starts path separator" {
    run options.sh --include "/pattern1*" "bucket_name" "$TEST_TEMP_DIR" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_line "options.sh: -i|--include <patterns>: patterns cannnot contain the path separator '/'."
}

# bats test_tags=abnormal, include, args
@test "[045][abnormal] specify --include option with pattern contains path separator" {
    run options.sh --include "pattern1*,dir/pattern2*" "bucket_name" "$TEST_TEMP_DIR" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_line "options.sh: -i|--include <patterns>: patterns cannnot contain the path separator '/'."
}

# bats test_tags=abnormal, include, args
@test "[046][abnormal] specify --include option with pattern ends path separator" {
    run options.sh --include "pattern1*,pattern2*,dir*/" "bucket_name" "$TEST_TEMP_DIR" "$TEST_TEMP_DIR"
    assert_failure 2
    assert_line "options.sh: -i|--include <patterns>: patterns cannnot contain the path separator '/'."
}


# bats test_tags=normal, dirs, args
@test "[047][ normal ] specify single backup_source_directory argument" {
    run options.sh "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
    refute_output --partial "SOURCE_DIRS[2]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, dirs, args
@test "[048][ normal ] specify two or more backup_source_directory arguments" {
    mkdir "$TEST_TEMP_DIR/dir1"
    mkdir "$TEST_TEMP_DIR/dir2"
    mkdir "$TEST_TEMP_DIR/dir3"

    run options.sh "bucket_name" "$TEST_TEMP_DIR/dir1" "$TEST_TEMP_DIR/dir2" "$TEST_TEMP_DIR/dir3"
    assert_success
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR/dir1'"
    assert_output --partial "SOURCE_DIRS[2]='$TEST_TEMP_DIR/dir2'"
    assert_output --partial "SOURCE_DIRS[3]='$TEST_TEMP_DIR/dir3'"
}

# bats test_tags=abnormal, dirs, args
@test "[049][abnormal] backup_source_directory arguments contains a directory that does not exist" {
    mkdir "$TEST_TEMP_DIR/dir1"
    mkdir "$TEST_TEMP_DIR/dir3"

    run options.sh "bucket_name" "$TEST_TEMP_DIR/dir1" "$TEST_TEMP_DIR/dir2" "$TEST_TEMP_DIR/dir3"
    assert_failure 2
    assert_line "options.sh: backup source directory '$TEST_TEMP_DIR/dir2' is not exist."
}

# bats test_tags=abnormal, dirs, args
@test "[049][abnormal] backup_source_directory arguments contains a directory that not a directory" {
    mkdir "$TEST_TEMP_DIR/dir1"
    touch "$TEST_TEMP_DIR/dir2"
    mkdir "$TEST_TEMP_DIR/dir3"

    run options.sh "bucket_name" "$TEST_TEMP_DIR/dir1" "$TEST_TEMP_DIR/dir2" "$TEST_TEMP_DIR/dir3"
    assert_failure 2
    assert_line "options.sh: backup source directory '$TEST_TEMP_DIR/dir2' is not a directory."
}


# bats test_tags=normal, onebyone, args
@test "[050][ normal ] specify --one-by-one option" {
    run options.sh --one-by-one "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "MOVE_ONE_BY_ONE=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}

# bats test_tags=normal, onebyone, args
@test "[051][ normal ] specify -1 option" {
    run options.sh -1 "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "MOVE_ONE_BY_ONE=1"
    assert_output --partial "SOURCE_DIRS[1]='$TEST_TEMP_DIR'"
}


# bats test_tags=normal, journalid, args
@test "[052][ normal ] specify --journal-id option with id string" {
    run options.sh --journal-id "test-052" "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "JOURNAL_ID='test-052'"
}

# bats test_tags=abnormal, journalid, args
@test "[053][abnormal] specify --journal-id option without value" {
    run options.sh --journal-id "bucket_name" "$TEST_TEMP_DIR"
    assert_failure
    assert_output --partial "No backup source directory specified."
}

# bats test_tags=normal, journalid, args
@test "[054][ normal ] specify -j option with id string" {
    run options.sh -j "test-054" "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "JOURNAL_ID='test-054'"
}

# bats test_tags=abnormal, journalid, args
@test "[055][abnormal] specify -j option without value" {
    run options.sh -j "bucket_name" "$TEST_TEMP_DIR"
    assert_failure
    assert_output --partial "No backup source directory specified."
}




###

# bats test_tags=aabnormal, rgs
@test "[101][abnormal behaviour of getopt] getopt fails to recognize missing option argument when another option is specified instead of the option argument" {
    run options.sh --profile --move-older-than "bucket_name" "$TEST_TEMP_DIR"
    assert_success
    assert_output --partial "AWS_PROFILE='--move-older-than'"
}


#EOS
