#!/usr/bin/env bats

# test_compress_by_gzip.bats

# bats --filter-tags オプションにタグを指定してテスト対象を絞り込むことができます(bats 1.8.0 以降が必要)
# タグには相互関連や階層構造など上下関係は無く、単に指定したタグに一致するテストが実施されます。
#
# コマンド例：
#   bats test/test_compress_by_gzip.bats --filter-tags args
#
# タグ一覧：
#   args      引数テスト
#   proc      処理内容のテスト
#   include   --include オプションのテスト
#   nonrecurs --non-recursive オプションのテスト
#

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

    # 実コマンドをモックして関数をテストするためにここでロードする
    # 注意）関数以外の記述はここで実行されてしまうため、スクリプト
    #       自体のテストでモックすることはできないと考えた方が良い。
    COMMAND_PATH=$(cd "$DIR/../src" && pwd)
    load "$COMMAND_PATH/compress_by_gzip.sh"
    COMMAND_NAME=$(basename $BATS_TEST_FILENAME .bats)

    # テスト用定数定義
    # 注意）constants.sh にてデフォルト値が変更になった場合、
    #       この設定も変更すること。
    #       アプリケーションの定数定義を参照するために constants.sh 等をテストに
    #       load してはイケない。なぜなら不適切な変更をテストで見つけることができ
    #       なくなるからである。テストコード保守のめんどくささも時には役に立つ。
    MYNAME=$(basename "$COMMAND_NAME" .sh)

    BEGIN_AT=$(date --iso-8601=ns)
    readonly FMT_FILE_UNIQUNIZE="%Y%m%d-%H%M%S-%N"
    FILE_UNIQUNIZE=$(date --date="$BEGIN_AT" "+$FMT_FILE_UNIQUNIZE")

    GZIP_OLDER_THAN=${GZIP_OLDER_THAN:-30}
    GZIP_DATE_UNTIL=$(date --date="$((GZIP_OLDER_THAN + 1)) days ago" +%Y-%m-%d)

    # default settings link app.sh
    DRYRUN=0
    NON_RECURSIVE=0
    INCLUDE_PATTERNS=""
    FOLLOW_SYMLINK=1

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"

    # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH は削除する
    export KEEP_TEMP_FILES=0

    # stub for raise function
    function raise() {
        echo "$1"

        local code=${2:-250}
        exit $code
    }

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
   
}

teardown() {
    # 作成した一時ディレクトリを削除する
    if [[ 0 -eq $KEEP_TEMP_FILES ]]; then
        temp_del "$TEST_TEMP_DIR"
    else
        echo "# $TEST_TEMP_DIR remains." >&3
    fi
}

# make_test_files(base_dir, base_date=today, days_old=10)
#
# base_dir に4階層のディレクトリ dir1/dir2/dir3/dir4 を作る
# 各ディレクトリに base_date 日も含め過去 days_old + 1日分のファイルを作る
# ファイル名： YYYYMMDD.dat
# ファイルの内容： YYYYMMDD
make_test_files() {
    local today=$(date +%Y%m%d)
    local base_dir="$1"
    local base_date=${2:-$today}
    local days_old=${3:-10}

    local suffix=${TEST_FILE_SUFFIX:-}

    mkdir -p "$base_dir/dir1/dir2/dir3/dir4"

    dir="$base_dir"
    for d in {1..4}; do
        dir=$dir/dir$d
        for ((i = 0; i <= days_old; i++)); do
            if [[ $i -eq 0 ]]; then
                q=""
            else
                q="$i days ago"
            fi
            local date=$(date --date="$today $q" +%Y%m%d)
            local fname="$date$suffix.dat"
            echo "$date" >"$dir/$fname"
            touch --date="$date 12:34:56" "$dir/$fname"
        done
    done

    # find "$base_dir" | sort >&3
}

# bats test_tags=args
@test "[001][abnormal] no arguments specified." {
    run compress_old_files
    assert_failure 250
    assert_line "$COMMAND_NAME: compress_old_files(): a source directory must be specified as argument 1."
}

# bats test_tags=args
@test "[002][abnormal] argument one is a file." {
    local src_path="$TEST_TEMP_DIR/file"
    touch $src_path
    run compress_old_files $src_path
    assert_failure 250
    assert_line "$COMMAND_NAME: compress_old_files(): specified source directory is not a directory. ($src_path)"
    assert_line "$COMMAND_NAME: compress_old_files(): all specified paths must be directories."
}


# bats test_tags=proc
@test "[003][ normal ] compress by gzip all." {
    TEST_FILE_SUFFIX=""
    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $TEST_TEMP_DIR $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の一番古い日付のファイル１つずつ
    GZIP_OLDER_THAN=9
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにする
    run compress_old_files $TEST_TEMP_DIR
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は各ディレクトリ1本ずつ、最も古いファイルのはず
    local date=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    assert_line "gzip '$TEST_TEMP_DIR/dir1/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat' ... done."
    # そして圧縮されているはず
    assert_file_exists "$TEST_TEMP_DIR/dir1/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat.gz"
    # さらに圧縮元ファイルは残っていないはず
    assert_not_exists "$TEST_TEMP_DIR/dir1/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat"

    # それより1日新しいファイルは対象外のはず
    date=$(date --date="$today $GZIP_OLDER_THAN days ago" +%Y%m%d)
    refute_line "gzip '$TEST_TEMP_DIR/dir1/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat' ... done."
}

# bats test_tags=proc
@test "[004][ normal ] compress by gzip all except gz and zip file." {
    TEST_FILE_SUFFIX=""
    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $TEST_TEMP_DIR $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の一番古い日付のファイル１つずつ
    export GZIP_OLDER_THAN=9

    run compress_old_files $TEST_TEMP_DIR
    assert_success

    # 結果出力が想定通りか
    assert_line "Total 4 file(s) gzipped successfully."
    refute_line --partial "ERROR: Total"

    # 圧縮対象は各ディレクトリ1本ずつ、最も古いファイルのはず
    local date=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    assert_line "gzip '$TEST_TEMP_DIR/dir1/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat' ... done."
    # そして圧縮されているはず
    assert_file_exists "$TEST_TEMP_DIR/dir1/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat.gz"

    # もう一度同条件で実行すると、処理されるファイルは１つも無いはず
    run compress_old_files $TEST_TEMP_DIR
    assert_success

    # 結果出力が想定通りか
    assert_line "No files gzipped."
    refute_line --partial "ERROR: Total"

    refute_line "gzip '$TEST_TEMP_DIR/dir1/$date.dat.gz' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date.dat.gz' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat.gz' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat.gz' ... done."

}

# bats test_tags=proc
@test "[005][ normal ] compress by gzip name with blank." {
    # テスト用ファイル名にスペースを含ませる
    TEST_FILE_SUFFIX="-A B C D"
    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $TEST_TEMP_DIR $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の一番古い日付のファイル１つずつ
    export GZIP_OLDER_THAN=9
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにする
    run compress_old_files $TEST_TEMP_DIR
    assert_success

    # 圧縮対象は各ディレクトリ1本ずつ、最も古いファイルのはず
    local date=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    local fname="$date$TEST_FILE_SUFFIX.dat"
    assert_line "gzip '$TEST_TEMP_DIR/dir1/$fname' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$fname' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$fname' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$fname' ... done."
    # そして圧縮されているはず
    assert_file_exists "$TEST_TEMP_DIR/dir1/$fname.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$fname.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$fname.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$fname.gz"
    # さらに圧縮元ファイルは残っていないはず
    assert_not_exists "$TEST_TEMP_DIR/dir1/$fname"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/$fname"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$fname"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$fname"

}

# bats test_tags=proc
@test "[006][ normal ] compress by gzip name with multi-byte characters." {
    # テスト用ファイル名に多バイト文字を含ませる
    TEST_FILE_SUFFIX="-aあ表示Ａ ＜～＞"
    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $TEST_TEMP_DIR $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の一番古い日付のファイル１つずつ
    export GZIP_OLDER_THAN=9
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにする
    run compress_old_files $TEST_TEMP_DIR
    assert_success

    # 圧縮対象は各ディレクトリ1本ずつ、最も古いファイルのはず
    local date=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    local fname="$date$TEST_FILE_SUFFIX.dat"
    assert_line "gzip '$TEST_TEMP_DIR/dir1/$fname' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$fname' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$fname' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$fname' ... done."
    # そして圧縮されているはず
    assert_file_exists "$TEST_TEMP_DIR/dir1/$fname.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$fname.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$fname.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$fname.gz"
    # さらに圧縮元ファイルは残っていないはず
    assert_not_exists "$TEST_TEMP_DIR/dir1/$fname"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/$fname"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$fname"
    assert_not_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$fname"

}

# bats test_tags=proc
@test "[007][ normal ] compress by gzip all specified directories." {
    TEST_FILE_SUFFIX=""
    # ２つのディレクトリに今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR/path1" $today
    make_test_files "$TEST_TEMP_DIR/path2" $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/path1/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の一番古い日付のファイル１つずつ
    GZIP_OLDER_THAN=9
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにできる
    run compress_old_files "$TEST_TEMP_DIR/path1" "$TEST_TEMP_DIR/path2"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は各ディレクトリ1本ずつ、最も古いファイルのはず
    local date=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # /path1
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date.dat' ... done."
    # /path2
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date.dat' ... done."

    # そして圧縮されているはず
    # /path1
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date.dat.gz"
    # /path2
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date.dat.gz"

    # さらに圧縮元ファイルは残っていないはず
    # /path1
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date.dat"
    # /path2
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date.dat"

    # それより1日新しいファイルは対象外のはず
    date=$(date --date="$today $GZIP_OLDER_THAN days ago" +%Y%m%d)
    # /path1
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date.dat' ... done."
    # /path2
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date.dat' ... done."
}

# bats test_tags=normal, proc, patterns
@test "[008][ normal ] gzips the files matching the pattern in the specified directory." {
    TEST_FILE_SUFFIX=""
    # ２つのディレクトリに今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR/path1" $today
    make_test_files "$TEST_TEMP_DIR/path2" $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/path1/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の中で古い方から3つずつ
    GZIP_OLDER_THAN=7
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにできる

    # かつ、パターンにマッチするファイルのみ圧縮する
    # 一番古いファイルと3番目に古いファイルの日付のみをワイルドカード指定
    PATTERN1="*$(date --date="$today 10 days ago" +%d).dat"
    PATTERN2="*$(date --date="$today 8 days ago" +%d).dat"
    # echo "# PATTERN1='$PATTERN1'" >&3
    # echo "# PATTERN2='$PATTERN2'" >&3
    INCLUDE_PATTERNS="$PATTERN1,$PATTERN2"

    run compress_old_files "$TEST_TEMP_DIR/path1" "$TEST_TEMP_DIR/path2"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は各ディレクトリ2本ずつ、最も古いファイルと3番目に古いファイルのはず
    local date1=$(date --date="$today $((GZIP_OLDER_THAN + 3)) days ago" +%Y%m%d)
    local date2=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # echo "# test date1=$date1" >&3
    # echo "# test date2=$date2" >&3
    # /path1/**/$date1.dat
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    # /path1/**/$date2.dat
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat' ... done."
    # /path2/**/$date1.dat
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    # /path2/**/$date2.dat
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat' ... done."

    # そして圧縮されているはず
    # /path1/**/$date1.dat.gz
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat.gz"
    # /path1/**/$date2.dat.gz
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat.gz"
    # /path2/**/$date1.dat.gz
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat.gz"
    # /path2/**/$date2.dat.gz
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat.gz"

    # さらに圧縮元ファイルは残っていないはず
    # /path1/**/$date1.dat
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/$date1.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat"
    # /path1/**/$date2.dat
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/$date2.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat"
    assert_not_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat"
    # /path2/**/$date1.dat
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/$date1.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat"
    # /path2/**/$date2.dat
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/$date2.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat"
    assert_not_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat"

    # 4番目に古いファイルは対象外のはず
    local date3=$(date --date="$today $((GZIP_OLDER_THAN + 0)) days ago" +%Y%m%d)
    # /path1/**/$date3.dat
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date3.dat' ... done."
    # /path2/**/$date3.dat
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date.dat' ... done."
}


# bats test_tags=normal, nonrecurs
@test "[009][ normal ] compress by gzip only specified directories non recursively." {
    TEST_FILE_SUFFIX=""
    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR" $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の一番古い日付のファイル１つずつ
    GZIP_OLDER_THAN=9
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにできる

    # 非再帰的オプションを付け、dir1 と dir1/dir2/dir3 のファイルのみ圧縮する
    NON_RECURSIVE=1

    run compress_old_files "$TEST_TEMP_DIR/dir1" "$TEST_TEMP_DIR/dir1/dir2/dir3"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は dir1 と dir1/dir2/dir3 各ディレクトリ1本ずつ、最も古いファイルのはず
    # そして dir1/dir2 と dir1/dir2/dir3/dir4 各ディレクトリのもっとも古いファイルは圧縮されていないはず
    local date=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    assert_line "gzip '$TEST_TEMP_DIR/dir1/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat' ... done."

    # そして dir1 と dir1/dir2/dir3 各ディレクトリのファイルは圧縮されているはず
    # また dir1/dir2 と dir1/dir2/dir3/dir4 各ディレクトリのファイルは圧縮されていないはず
    assert_file_exists "$TEST_TEMP_DIR/dir1/$date.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/$date.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat.gz"

    # さらに dir1 と dir1/dir2/dir3 各ディレクトリに圧縮元ファイルは残っていないはず
    # また dir1/dir2 と dir1/dir2/dir3/dir4 各ディレクトリには圧縮元ファイルがそのままのはず
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/$date.dat"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/dir3/$date.dat"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/dir3/dir4/$date.dat"
}


# bats test_tags=normal, nonrecurs, patterns
@test "[010][ normal ] gzips the files matching the pattern in the specified directories with non recursively." {
    TEST_FILE_SUFFIX=""
    # ２つのディレクトリに今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR/path1" $today
    make_test_files "$TEST_TEMP_DIR/path2" $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/path1/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の中で古い方から3つずつ
    GZIP_OLDER_THAN=7
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにできる

    # かつ、パターンにマッチするファイルのみ圧縮する
    # 一番古いファイルと3番目に古いファイルの日付のみをワイルドカード指定
    PATTERN1="*$(date --date="$today 10 days ago" +%d).dat"
    PATTERN2="*$(date --date="$today 8 days ago" +%d).dat"
    # echo "# PATTERN1='$PATTERN1'" >&3
    # echo "# PATTERN2='$PATTERN2'" >&3
    INCLUDE_PATTERNS="$PATTERN1,$PATTERN2"

    # 加えて非再帰的オプションを付け、dir1/dir2 のファイルのみ圧縮する
    NON_RECURSIVE=1

    run compress_old_files "$TEST_TEMP_DIR/path2/dir1/dir2" "$TEST_TEMP_DIR/path1/dir1/dir2" 
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は /path1/dir1/dir2, /path2/dir1/dir2 各ディレクトリ2本ずつ、最も古いファイルと3番目に古いファイルのはず
    local date1=$(date --date="$today $((GZIP_OLDER_THAN + 3)) days ago" +%Y%m%d)
    local date2=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # echo "# test date1=$date1" >&3
    # echo "# test date2=$date2" >&3
    # /path1/dir1/dir2/$date1.dat
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    # /path1/dir1/dir2/$date2.dat
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat' ... done."
    # /path2/dir1/dir2/$date1.dat
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    # /path2/dir1/dir2/$date2.dat
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat' ... done."

    # そして圧縮されているはず
    # /path1/dir1/dir2/$date1.dat.gz
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat.gz"
    # /path1/dir1/dir2/$date2.dat.gz
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat.gz"
    # /path2/dir1/dir2/$date1.dat.gz
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat.gz"
    # /path2/dir1/dir2/$date2.dat.gz
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat.gz"

    # さらに圧縮元ファイルは残っていないはず
    # /path1/dir1/dir2/$date1.dat
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/$date1.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat"
    # /path1/dir1/dir2/$date2.dat
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/$date2.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat"
    assert_file_exists "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat"
    # /path2/dir1/dir2/$date1.dat
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/$date1.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat"
    # /path2/dir1/dir2/$date2.dat
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/$date2.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat"
    assert_file_exists "$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat"
}


# bats test_tags=symlink
@test "[011][ normal ] The setting to search the target file from the symbolic link directory is enabled." {
    TEST_FILE_SUFFIX=""
    # １つのディレクトリに今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR/path1" $today
    # path1 のシンボリックリンク path2 を作る
    ln -s "$TEST_TEMP_DIR/path1" "$TEST_TEMP_DIR/path2"

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/path1/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象はディレクトリ階層の中で古い方から3つずつ
    GZIP_OLDER_THAN=7
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようする
    # export KEEP_TEMP_FILES=1

    # do test
    # シンボリックリンク ディレクトリを指定
    run compress_old_files "$TEST_TEMP_DIR/path2"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は /path1, /path2 ディレクトリ下にある、古いほうファイルから3日分のはず
    local date1=$(date --date="$today $((GZIP_OLDER_THAN + 3)) days ago" +%Y%m%d)
    local date2=$(date --date="$today $((GZIP_OLDER_THAN + 2)) days ago" +%Y%m%d)
    local date3=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # echo "# test date1=$date1" >&3
    # echo "# test date2=$date2" >&3
    # echo "# test date3=$date3" >&3
    # /path2/dir1
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date2.dat' ... done."
    # /path2/dir1/dir2
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date3.dat' ... done."
    # /path2/dir1/dir2/dir3
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date3.dat' ... done."
    # /path2/dir1/dir2/dir3/dir4
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date3.dat' ... done."

}

# bats test_tags=symlink
@test "[012][ normal ] The setting to search the target file from the symbolic link directory is disabled." {
    TEST_FILE_SUFFIX=""
    # １つのディレクトリに今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR/path1" $today
    # path1 のシンボリックリンク path2 を作る
    ln -s "$TEST_TEMP_DIR/path1" "$TEST_TEMP_DIR/path2"

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/path1/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象はディレクトリ階層の中で古い方から3つずつ
    GZIP_OLDER_THAN=7
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようする
    # export KEEP_TEMP_FILES=1

    # シンボリックリンクを辿らない
    FOLLOW_SYMLINK=0

    # do test
    # シンボリックリンク ディレクトリを指定
    run compress_old_files "$TEST_TEMP_DIR/path2"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は /path1, /path2 ディレクトリ下にある、古いほうファイルから3日分のはず
    local date1=$(date --date="$today $((GZIP_OLDER_THAN + 3)) days ago" +%Y%m%d)
    local date2=$(date --date="$today $((GZIP_OLDER_THAN + 2)) days ago" +%Y%m%d)
    local date3=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # echo "# test date1=$date1" >&3
    # echo "# test date2=$date2" >&3
    # echo "# test date3=$date3" >&3
    # /path2/dir1
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/$date2.dat' ... done."
    # /path2/dir1/dir2
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/$date3.dat' ... done."
    # /path2/dir1/dir2/dir3
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/$date3.dat' ... done."
    # /path2/dir1/dir2/dir3/dir4
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path2/dir1/dir2/dir3/dir4/$date3.dat' ... done."

}

# bats test_tags=symlink
@test "[013][abnormal] Directory tree looped by symlinks." {
    TEST_FILE_SUFFIX=""
    # １つのディレクトリに今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR/path1" $today
    # dir4 ディレクトリに dir1 にループするシンボリックリンク dir5 を作る
    ln -s "$TEST_TEMP_DIR/path1/dir1" "$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/dir5"

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/path1/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象はディレクトリ階層の中で古い方から3つずつ
    GZIP_OLDER_THAN=7
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようする
    # export KEEP_TEMP_FILES=1

    # do test
    run compress_old_files "$TEST_TEMP_DIR/path1"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は /path1, /path2 ディレクトリ下にある、古いほうファイルから3日分のはず
    local date1=$(date --date="$today $((GZIP_OLDER_THAN + 3)) days ago" +%Y%m%d)
    local date2=$(date --date="$today $((GZIP_OLDER_THAN + 2)) days ago" +%Y%m%d)
    local date3=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # echo "# test date1=$date1" >&3
    # echo "# test date2=$date2" >&3
    # echo "# test date3=$date3" >&3
    # /path1/dir1
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/$date2.dat' ... done."
    # /path1/dir1/dir2
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/$date3.dat' ... done."
    # /path1/dir1/dir2/dir3
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/$date3.dat' ... done."
    # /path1/dir1/dir2/dir3/dir4
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/$date3.dat' ... done."
    # /path1/dir1/dir2/dir3/dir4/dir5 これは含まれない
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/dir5/$date1.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/dir5/$date2.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/dir5/$date3.dat' ... done."

    # find のエラーメッセージ
    # assert_line "find: File system loop detected; '$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/dir5' is part of the same file system loop as '$TEST_TEMP_DIR/path1/dir1'."
    # ↑
    # 失敗するようになった
    # find のバージョンによるのか、パスを囲むクォート文字が '' だったり ‘’ だったりするので困る
    # 今回の出力: find (GNU findutils) 4.8.0) の場合： 
    # find: File system loop detected; ‘/tmp/test_compress_by_gzip.bats-13-QP0h14/path1/dir1/dir2/dir3/dir4/dir5’ is part of the same file system loop as ‘/tmp/test_compress_by_gzip.bats-13-QP0h14/path1/dir1’.
    # ↓ 
    assert_line --regexp "^find: File system loop detected; ['‘]$TEST_TEMP_DIR/path1/dir1/dir2/dir3/dir4/dir5['’] is part of the same file system loop as ['‘]$TEST_TEMP_DIR/path1/dir1['’]\.$"
}



# bats test_tags=abnormal, patterns
@test "[014][abnormal] illegal pattern specified." {
    TEST_FILE_SUFFIX=""
    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files "$TEST_TEMP_DIR" $today

    # WORK_PATH 設定
    WORK_PATH="$TEST_TEMP_DIR/.$MYNAME"
    mkdir -p "$WORK_PATH"

    # 圧縮対象は各ディレクトリ階層の中で古い方から3つずつ
    GZIP_OLDER_THAN=7
    GZIP_DATE_UNTIL=$(date --date="$today 10 days ago" +%Y-%m-%d)
    export GZIP_OLDER_THAN
    export GZIP_DATE_UNRIL
    # export KEEP_TEMP_FILES=1 # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH を削除しないようにできる

    # かつ、パターンにマッチするファイルのみ圧縮する
    # が、
    # カンマのみの誤ったパターン（指定無しと同義）
    INCLUDE_PATTERNS=","

    # 加えて非再帰的オプションを付け、dir1/dir2 のファイルのみ対象とする
    NON_RECURSIVE=1

    run compress_old_files "$TEST_TEMP_DIR/dir1/dir2"
    assert_success

    # 開始-終了メッセージの確認
    assert_line "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."
    assert_line "## End of gzip files."

    # 圧縮対象は /path1/dir1/dir2 の最も古いファイル３つのはず
    local date1=$(date --date="$today $((GZIP_OLDER_THAN + 3)) days ago" +%Y%m%d)
    local date2=$(date --date="$today $((GZIP_OLDER_THAN + 2)) days ago" +%Y%m%d)
    local date3=$(date --date="$today $((GZIP_OLDER_THAN + 1)) days ago" +%Y%m%d)
    # echo "# test date1=$date1" >&3
    # echo "# test date2=$date2" >&3
    # echo "# test date3=$date3" >&3
    # date4 のファイルは圧縮されていないはず
    local date4=$(date --date="$today $((GZIP_OLDER_THAN + 0)) days ago" +%Y%m%d)

    # ログ出力を確認
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date1.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date2.dat' ... done."
    assert_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date3.dat' ... done."
    refute_line "gzip '$TEST_TEMP_DIR/dir1/dir2/$date4.dat' ... done."

    # 圧縮ファイルを確認
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date1.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date2.dat.gz"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date3.dat.gz"
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/$date4.dat.gz"

    # 圧縮元ファイルを確認
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/$date1.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/$date2.dat"
    assert_file_not_exist "$TEST_TEMP_DIR/dir1/dir2/$date3.dat"
    assert_file_exists "$TEST_TEMP_DIR/dir1/dir2/$date4.dat"
}

#EOS
