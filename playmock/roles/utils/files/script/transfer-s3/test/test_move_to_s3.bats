#!/usr/bin/env bats

# test_move_to_s3.bats

# bats --filter-tags オプションにタグを指定してテスト対象を絞り込むことができます(bats 1.8.0 以降が必要)
# タグには相互関連や階層構造など上下関係は無く、単に指定したタグに一致するテストが実施されます。
#
# コマンド例：
#   bats test/test_move_to_s3.bats --filter-tags main,args
#
# タグ一覧：
#   main     メイン関数 move_old_files のテスト
#   find     処理対象ファイル検索処理のテスト
#   crypt    暗号化処理のテスト
#   move     ファイル移動のテスト
#   args     引数テスト
#   proc     処理内容のテスト
#   file     ファイル操作関連のテスト
#   symlink  シンボリックリンク関連のテスト
#   onebyone １ファイルずつ移動するモードのテスト

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

    # 関数単位でテストしたいのでここで読み込む
    COMMAND_PATH=$(cd "$DIR/../src" && pwd)
    load "$COMMAND_PATH/crypt.sh"
    load "$COMMAND_PATH/move_to_s3.sh"
    COMMAND_NAME=$(basename $BATS_TEST_FILENAME .bats)

    # default settings link app.sh
    BEGIN_AT=$(date --iso-8601=ns)
    readonly FMT_FILE_UNIQUNIZE="%Y%m%d-%H%M%S-%N"
    FILE_UNIQUNIZE=$(date --date="$BEGIN_AT" "+$FMT_FILE_UNIQUNIZE")

    DRYRUN=0
    NON_RECURSIVE=0
    INCLUDE_PATTERNS=""
    FOLLOW_SYMLINK=1
    MOVE_ONE_BY_ONE=0

    DEBUG=1

    # 一時ディレクトリを作成する
    TEST_TEMP_DIR="$(temp_make)"
    WORK_PATH="$TEST_TEMP_DIR/.work"
    mkdir -p $WORK_PATH

    # 暗号化の準備
    CRYPT_PRIVATE_KEY="$WORK_PATH/id_rsa"
    CRYPT_CERTIFICATE="$WORK_PATH/id_rsa.crt"

    # 対象ファイルリストの一時保存ファイル GZIP_FILES_PATH は削除する
    KEEP_TEMP_FILES=0


    # stub for journal.sh
    function journal() {
        local dryrun=""
        if [[ $DRYRUN -ne 0 ]]; then
            dryrun="(Dry-Run)"
        fi
        # echo "# journal-stub: $dryrun$*" >&3
        echo "$dryrun$*"
    }
    function journal_err() {
        journal "$*"
    }
    # stub for raise function
    function raise() {
        echo "$1"
        # # bats console にも出力
        # echo "# $1" >&3
        set -e # force errexit to enable.
        local code=${2:-250}
        # return "$code"  # テストの場合は exit が必要。 set -e は効果なし
        exit "$code"
    }

    # 'aws s3' command stub: copy the file SRC to DST.
    function aws() {
        # 想定するコマンド行
        # bulk move:
        #   aws s3 sync <送信元Dir> <S3アップロード先Dir> ... 以降のオプションは無視
        # one by one move:
        #   aws s3 mv <送信元ファイル> <S3アップロード先ファイル> ... 以降のオプションは無理

        # コマンド行チェック
        if [[ "s3" != $1 ]]; then
            raise "aws-stub: コマンドが aws s3 から始まっていない"
        fi

        shift
        method=$1
        shift 
        # sync or move
        case $method in
            "sync")
                aws_s3_sync "${@}"
                return $?
                ;;
            "mv")
                aws_s3_move "${@}"
                return $?
                ;;
            *)
                raise "aws-stub: aws s3 コマンドのメソッド $method は無効(sync,mvのみ)"
                ;;
        esac
    }

    function aws_s3_sync () {
        echo "# aws-stub: aws s3 sync ${*}" >&3
        raise "aws_s3_sync stub: sync method is not implemented. args: $*"
    }

    function aws_s3_move () {
        # echo "# aws-stub: aws s3 mv ${*}" >&3
        mkdir -p $(dirname $2)
        mv -f $1 $2
    }

}

teardown() {
    # 作成した一時ディレクトリを削除する
    if [[ 0 -eq $KEEP_TEMP_FILES ]]; then
        temp_del "$TEST_TEMP_DIR"
    else
        echo "# $COMMAND_NAME: work file remains at $TEST_TEMP_DIR" >&3
    fi
}

# 鍵ファイルと暗号化用証明書を作成する
prepare_certificate() {
    ssh-keygen -t rsa -m pem -f "$CRYPT_PRIVATE_KEY" -N "" >/dev/null
    openssl req -x509 -new -key "$CRYPT_PRIVATE_KEY" -subj '/' -out "$CRYPT_CERTIFICATE"
}


# make_test_files(base_dir, base_date=today, days_old=10)
#
# base_dir に4階層のディレクトリ ./dir1/dir2/dir3/dir4 を作る
# base_dir も含め各ディレクトリに base_date 日も含め過去 days_old + 1日分のファイルを作る
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
    for d in {0..4}; do
        # d=0 は base_dir 直下を表す
        if [[ $d -ne 0 ]]; then
            dir=$dir/dir$d
        fi
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


# make_test_files_at_two_directories - ２つのディレクトリにテストデータを作成する
#
#   test1/dir1/dir2/dir3/dir4   YYYYMMDD.dat
#   test2/dir1/dir2/dir3/dir4   YYYYMMDD.dat
# dirN ディレクトリそれぞれに今日から10日古い日付までテストファイルを作る
#   dirN 各ディレクトリには 11本のファイルが作られることになる
# 複数ディレクトリ対応テスト：
#   dirN 各ディレクトリ内の2番目に古いファイルを転送対象として gzip 圧縮する

get_date_today() {
    echo $(date +%Y%m%d)
    return 0
}

get_date_n_days_ago() {
    format=${3:-"%Y%m%d"}
    echo $(date --date="$1 $2 days ago" "+$format")
}

get_date_oldest() {
    get_date_n_days_ago $1 10
    return 0
}

get_date_before_oldest() {
    get_date_n_days_ago $1 9 $2
}


make_test_files_at_two_directories() {
    src_path_1=$1
    src_path_2=$2
    WORK_PATH="$src_path_1/.work"
    mkdir -p $WORK_PATH

    # 今日から10日古い日付までテストファイルを作る
    local today=$(get_date_today)
    make_test_files $src_path_1 $today
    make_test_files $src_path_2 $today

    # 一番古いファイルの日付が想定通りか確認
    local oldest=$(get_date_oldest $today)
    # test1
    assert_file_exists $src_path_1/$oldest.dat
    assert_file_exists $src_path_1/dir1/$oldest.dat
    assert_file_exists $src_path_1/dir1/dir2/$oldest.dat
    assert_file_exists $src_path_1/dir1/dir2/dir3/$oldest.dat
    assert_file_exists $src_path_1/dir1/dir2/dir3/dir4/$oldest.dat
    # test2
    assert_file_exists $src_path_2/$oldest.dat
    assert_file_exists $src_path_2/dir1/$oldest.dat
    assert_file_exists $src_path_2/dir1/dir2/$oldest.dat
    assert_file_exists $src_path_2/dir1/dir2/dir3/$oldest.dat
    assert_file_exists $src_path_2/dir1/dir2/dir3/dir4/$oldest.dat

}

gzip_all_test_files() {
    find "$1" -type f -name "*.dat" -execdir gzip '{}' \;
    # 確認: 
    # find "$1" -type f -name "*.dat.gz" -exec echo "# {}" >&3 \;
}


# bats test_tags=abnormal, main, args
@test "[001][abnormal][ ---- ] no arguments specified." {
    run move_old_files
    assert_failure 250
    assert_line "$COMMAND_NAME: move_old_files(): a source directory must be specified as argument 1."
}

# bats test_tags=abnormal, main, args
@test "[002][abnormal][ ---- ] argument one is not a directory." {
    local src_path="$TEST_TEMP_DIR/file"
    touch $src_path
    run move_old_files $src_path
    assert_failure 250
    assert_line "$COMMAND_NAME: move_old_files(): specified source directory is not a directory. ($src_path)"
    assert_line "$COMMAND_NAME: move_old_files(): all specified paths must be directories."
}

# bats test_tags=abnormal, find, args
@test "[003][abnormal][ ---- ] _find_move_files(): no arguments specified." {
    run _find_move_files
    assert_failure 250
    assert_line "$COMMAND_NAME: _find_move_files(): a outfile path must be specified as argument 1."
}

# bats test_tags=abnormal, find, args
@test "[004][abnormal][ ---- ] _find_move_files(): argument one is not writable file." {
    local outfile_path="$TEST_TEMP_DIR"
    run _find_move_files $outfile_path
    assert_failure 250
    assert_line "$COMMAND_NAME: _find_move_files(): specified file path is not writable. might be a directory. ($outfile_path)"
}

# bats test_tags=abnormal, find, args
@test "[005][abnormal][ ---- ] _find_move_files(): argument two not specified." {
    local outfile_path="$TEST_TEMP_DIR/outfile"
    run _find_move_files $outfile_path
    assert_failure 250
    assert_line "$COMMAND_NAME: _find_move_files(): a source directory must be specified as argument 2."
}

# bats test_tags=abnormal, find, file
@test "[006][abnormal][ ---- ] _find_move_files(): specified outfile is not writable." {
    local src_path="$TEST_TEMP_DIR"
    local outfile="$src_path/outfile"
    chmod -w "$src_path"
    run _find_move_files $outfile $src_path
    chmod +w "$src_path"
    assert_failure 250
    assert_line "$COMMAND_NAME: _find_move_files(): specified file is not writable. ($outfile)"
}

# bats test_tags=normal, find, proc
@test "[007][ normal ][ ---- ] _find_move_files(): find move files." {
    # BATSLIB_TEMP_PRESERVE=1                      # テスト後にTEST_TEMP_DIR の中身を
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3  # 確認したいときはコメントを外す

    local src_path=$TEST_TEMP_DIR

    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $src_path $today
    # 一番古いファイルの日付が想定通りか確認
    local oldest=$(date --date="$today 10 days ago" +%Y%m%d)
    assert_file_exists $src_path/$oldest.dat
    assert_file_exists $src_path/dir1/$oldest.dat
    assert_file_exists $src_path/dir1/dir2/$oldest.dat
    assert_file_exists $src_path/dir1/dir2/dir3/$oldest.dat
    assert_file_exists $src_path/dir1/dir2/dir3/dir4/$oldest.dat

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(date --date="$today 9 days ago" +%Y-%m-%d)
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate="$(date --date="$MOVE_DATE_UNTIL" +%Y%m%d)"
    local fname="$fdate.dat"
    gzip "$src_path/$fname"
    gzip "$src_path/dir1/$fname"
    gzip "$src_path/dir1/dir2/$fname"
    gzip "$src_path/dir1/dir2/dir3/$fname"
    gzip "$src_path/dir1/dir2/dir3/dir4/$fname"

    # 圧縮されているはず
    local gzipped="$fname.gz"
    assert_file_exists "$src_path/$gzipped"
    assert_file_exists "$src_path/dir1/$gzipped"
    assert_file_exists "$src_path/dir1/dir2/$gzipped"
    assert_file_exists "$src_path/dir1/dir2/dir3/$gzipped"
    assert_file_exists "$src_path/dir1/dir2/dir3/dir4/$gzipped"
    # さらに圧縮元ファイルは残っていないはず
    assert_not_exists "$src_path/$fname"
    assert_not_exists "$src_path/dir1/$fname"
    assert_not_exists "$src_path/dir1/dir2/$fname"
    assert_not_exists "$src_path/dir1/dir2/dir3/$fname"
    assert_not_exists "$src_path/dir1/dir2/dir3/dir4/$fname"

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path"
    assert_success

    # 圧縮ファイルのみのリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "5 $move_files_path"

    run grep -x $src_path/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/dir2/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/dir2/dir3/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/dir2/dir3/dir4/$gzipped $move_files_path 2>&1

}

# bats test_tags=abnormal, crypt, args
@test "[008][abnormal][ ---- ] encrypt_file(): no arguments specified." {
    run encrypt_file
    assert_failure 250
    assert_line "$COMMAND_NAME: encrypt_file(): encrypt file path must be specified as argument 1"
}

# bats test_tags=normal, actual, crypt, proc
@test "[009][ normal ][actual] encrypt_file(): encrypt a specified file." {
    # BATSLIB_TEMP_PRESERVE=1                      # テスト後にTEST_TEMP_DIR の中身を
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3  # 確認したいときはコメントを外す

    local src_path="$TEST_TEMP_DIR"
    mkdir -p "$WORK_PATH"
    TX_BUFFER_PATH="$WORK_PATH/txbuffer"

    # 暗号化の準備
    prepare_certificate

    # prepare source file
    local source_file_1="$src_path/encfile-1.dat"
    local encrypted_file_1="$TX_BUFFER_PATH$source_file_1.enc"
    echo "this is a encrypted file-1." >"$source_file_1"

    local source_file_2="$src_path/dir1/encfile-2.dat"
    local encrypted_file_2="$TX_BUFFER_PATH$source_file_2.enc"
    mkdir -p "$src_path/dir1"
    echo "this is a encrypted file-2." >"$source_file_2"

    # do test
    run encrypt_file $source_file_1
    assert_success
    assert_file_exists "$encrypted_file_1"

    run encrypt_file $source_file_2
    assert_success
    assert_file_exists "$encrypted_file_2"

    # test decryption
    local decrypted_file_1="$TEST_TEMP_DIR/enc1"
    local decrypted_file_2="$TEST_TEMP_DIR/enc2"
    make_decrypt_commandline "$encrypted_file_1" "$decrypted_file_1"
    ("${CRYPT_CMD[@]}")
    diff "$source_file_1" "$decrypted_file_1"

    make_decrypt_commandline "$encrypted_file_2" "$decrypted_file_2"
    ("${CRYPT_CMD[@]}")
    diff "$source_file_2" "$decrypted_file_2"
}

# bats test_tags=normal, actual, crypt, proc
@test "[010][ normal ][actual] _encrypt_move_files(): encrypt move target files." {
    # BATSLIB_TEMP_PRESERVE=1                      # テスト後にTEST_TEMP_DIR の中身を
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3  # 確認したいときはコメントを外す

    local src_path="$TEST_TEMP_DIR"
    mkdir -p $WORK_PATH
    move_files_path="$WORK_PATH/move-files.txt"
    TX_BUFFER_PATH="$WORK_PATH/txbuffer"

    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $src_path $today

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(date --date="$today 9 days ago" +%Y-%m-%d)
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate="$(date --date="$MOVE_DATE_UNTIL" +%Y%m%d)"
    local fname="$fdate.dat"
    gzip "$src_path/$fname"
    gzip "$src_path/dir1/$fname"
    gzip "$src_path/dir1/dir2/$fname"
    gzip "$src_path/dir1/dir2/dir3/$fname"
    gzip "$src_path/dir1/dir2/dir3/dir4/$fname"

    local gzipped_file="$fname.gz"

    # 暗号化の準備
    prepare_certificate

    # gathering encrypt target files.
    _find_move_files "$move_files_path" "$src_path"

    # do test
    # output encrypt message by DEBUG option
    DEBUG=1
    run _encrypt_move_files "$move_files_path"

    assert_success
    local encrypted_file="$gzipped_file.enc"
    assert_file_exists "$TX_BUFFER_PATH$src_path/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/dir3/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/dir3/dir4/$encrypted_file"

    # test for DEBUG output only
    assert_line "encrypt '$src_path/$gzipped_file' ... done."
    assert_line "encrypt '$src_path/dir1/$gzipped_file' ... done."
    assert_line "encrypt '$src_path/dir1/dir2/$gzipped_file' ... done."
    assert_line "encrypt '$src_path/dir1/dir2/dir3/$gzipped_file' ... done."
    assert_line "encrypt '$src_path/dir1/dir2/dir3/dir4/$gzipped_file' ... done."

}

# bats test_tags=normal, actual, crypt, proc
@test "[011][ normal ][actual] _encrypt_move_files(): encrypt move target files with dry-run option." {
    # BATSLIB_TEMP_PRESERVE=1                      # テスト後にTEST_TEMP_DIR の中身を
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3  # 確認したいときはコメントを外す

    local src_path="$TEST_TEMP_DIR"
    move_files_path="$WORK_PATH/move-files.txt"
    TX_BUFFER_PATH="$WORK_PATH/txbuffer"

    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $src_path $today

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(date --date="$today 9 days ago" +%Y-%m-%d)
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate="$(date --date="$MOVE_DATE_UNTIL" +%Y%m%d)"
    local fname="$fdate.dat"
    gzip "$src_path/$fname"
    gzip "$src_path/dir1/$fname"
    gzip "$src_path/dir1/dir2/$fname"
    gzip "$src_path/dir1/dir2/dir3/$fname"
    gzip "$src_path/dir1/dir2/dir3/dir4/$fname"

    local gzipped_file="$fname.gz"

    # 暗号化の準備
    prepare_certificate

    # gathering encrypt target files.
    _find_move_files "$move_files_path" "$src_path"

    # do test
    # output encrypt message by DEBUG option
    DEBUG=1
    # Dry-Run mode.
    DRYRUN=1
    run _encrypt_move_files "$move_files_path"

    assert_success
    # files are not encrypted.
    local encrypted_file="$gzipped_file.enc"
    assert_not_exists "$TX_BUFFER_PATH$src_path/$encrypted_file"
    assert_not_exists "$TX_BUFFER_PATH$src_path/dir1/$encrypted_file"
    assert_not_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/$encrypted_file"
    assert_not_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/dir3/$encrypted_file"
    assert_not_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/dir3/dir4/$encrypted_file"

    # test for DEBUG output only
    assert_line "(Dry-Run)encrypt '$src_path/$gzipped_file' ... done."
    assert_line "(Dry-Run)encrypt '$src_path/dir1/$gzipped_file' ... done."
    assert_line "(Dry-Run)encrypt '$src_path/dir1/dir2/$gzipped_file' ... done."
    assert_line "(Dry-Run)encrypt '$src_path/dir1/dir2/dir3/$gzipped_file' ... done."
    assert_line "(Dry-Run)encrypt '$src_path/dir1/dir2/dir3/dir4/$gzipped_file' ... done."

}

# bats test_tags=normal, actual, crypt, proc
@test "[012][ normal ][actual] _encrypt_move_files(): encrypt move target files with no debug option." {
    # BATSLIB_TEMP_PRESERVE=1                      # テスト後にTEST_TEMP_DIR の中身を
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3  # 確認したいときはコメントを外す

    local src_path="$TEST_TEMP_DIR"
    move_files_path="$WORK_PATH/move-files.txt"
    TX_BUFFER_PATH="$WORK_PATH/txbuffer"

    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $src_path $today

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(date --date="$today 9 days ago" +%Y-%m-%d)
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate="$(date --date="$MOVE_DATE_UNTIL" +%Y%m%d)"
    local fname="$fdate.dat"
    gzip "$src_path/$fname"
    gzip "$src_path/dir1/$fname"
    gzip "$src_path/dir1/dir2/$fname"
    gzip "$src_path/dir1/dir2/dir3/$fname"
    gzip "$src_path/dir1/dir2/dir3/dir4/$fname"

    local gzipped_file="$fname.gz"

    # 暗号化の準備
    prepare_certificate
    
    # gathering encrypt target files.
    _find_move_files "$move_files_path" "$src_path"

    # do test
    # output encrypt message by DEBUG option
    DEBUG=0
    run _encrypt_move_files "$move_files_path"

    assert_success
    local encrypted_file="$gzipped_file.enc"
    assert_file_exists "$TX_BUFFER_PATH$src_path/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/dir3/$encrypted_file"
    assert_file_exists "$TX_BUFFER_PATH$src_path/dir1/dir2/dir3/dir4/$encrypted_file"

    # no DEBUG output
    # 出力が無い場合は refute_line はエラーとなり使えないようだ
    refute_output --partial "encrypt '$src_path/$gzipped_file' ... done."
    refute_output --partial "encrypt '$src_path/dir1/$gzipped_file' ... done."
    refute_output --partial "encrypt '$src_path/dir1/dir2/$gzipped_file' ... done."
    refute_output --partial "encrypt '$src_path/dir1/dir2/dir3/$gzipped_file' ... done."
    refute_output --partial "encrypt '$src_path/dir1/dir2/dir3/dir4/$gzipped_file' ... done."
}

# bats test_tags=abnormal, actual, crypt, proc
@test "[013][abnormal][actual] _encrypt_move_files(): encrypt move target files and some time failed." {
    # BATSLIB_TEMP_PRESERVE=1                      # テスト後にTEST_TEMP_DIR の中身を
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3  # 確認したいときはコメントを外す

    local src_path="$TEST_TEMP_DIR"
    move_files_path="$WORK_PATH/move-files.txt"
    TX_BUFFER_PATH="$WORK_PATH/txbuffer"

    # 今日から10日古い日付までテストファイルを作る
    local today=$(date +%Y%m%d)
    make_test_files $src_path $today

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(date --date="$today 9 days ago" +%Y-%m-%d)
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate="$(date --date="$MOVE_DATE_UNTIL" +%Y%m%d)"
    local fname="$fdate.dat"
    gzip "$src_path/$fname"
    gzip "$src_path/dir1/$fname"
    gzip "$src_path/dir1/dir2/$fname"
    gzip "$src_path/dir1/dir2/dir3/$fname"
    gzip "$src_path/dir1/dir2/dir3/dir4/$fname"

    local gzipped_file="$fname.gz"

    # 暗号化の準備
    prepare_certificate

    # gathering encrypt target files.
    _find_move_files "$move_files_path" "$src_path"

    # stub for encrypt_file
    ENCRYPT_COUNT=0
    function encrypt_file() {
        # 1st: 1, 2nd: 0, 3rd: 1,...
        ENCRYPT_COUNT=$((ENCRYPT_COUNT + 1))
        return $((ENCRYPT_COUNT % 2))
    }

    # do test
    # output encrypt message by DEBUG option
    DEBUG=1
    run _encrypt_move_files "$move_files_path"
    assert_success

    # done for odd times, failed for even times.
    assert_line "encrypt '$src_path/$gzipped_file' ... failed."
    assert_line "encrypt '$src_path/dir1/$gzipped_file' ... done."
    assert_line "encrypt '$src_path/dir1/dir2/$gzipped_file' ... failed."
    assert_line "encrypt '$src_path/dir1/dir2/dir3/$gzipped_file' ... done."
    assert_line "encrypt '$src_path/dir1/dir2/dir3/dir4/$gzipped_file' ... failed."
}

# bats test_tags=normal, find
@test "[014][ normal ][ ---- ] _find_move_files(): find from all specified directories." {
    # make test data at two directories.
    today=$(get_date_today)
    src_path_1=$TEST_TEMP_DIR/test1
    src_path_2=$TEST_TEMP_DIR/test2
    make_test_files_at_two_directories $src_path_1 $src_path_2

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(get_date_before_oldest $today '%Y-%m-%d')
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate=$(get_date_before_oldest $today '%Y%m%d')
    local fname="$fdate.dat"
    # test1
    gzip "$src_path_1/$fname"
    gzip "$src_path_1/dir1/$fname"
    gzip "$src_path_1/dir1/dir2/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/dir4/$fname"
    # test2
    gzip "$src_path_2/$fname"
    gzip "$src_path_2/dir1/$fname"
    gzip "$src_path_2/dir1/dir2/$fname"
    gzip "$src_path_2/dir1/dir2/dir3/$fname"
    gzip "$src_path_2/dir1/dir2/dir3/dir4/$fname"

    # 圧縮されているはず
    local gzipped="$fname.gz"
    # test1
    assert_file_exists "$src_path_1/$gzipped"
    assert_file_exists "$src_path_1/dir1/$gzipped"
    assert_file_exists "$src_path_1/dir1/dir2/$gzipped"
    assert_file_exists "$src_path_1/dir1/dir2/dir3/$gzipped"
    assert_file_exists "$src_path_1/dir1/dir2/dir3/dir4/$gzipped"
    # test2
    assert_file_exists "$src_path_2/$gzipped"
    assert_file_exists "$src_path_2/dir1/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/dir3/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/dir3/dir4/$gzipped"
    # さらに圧縮元ファイルは残っていないはず
    # test1
    assert_file_not_exist "$src_path_1/$fname"
    assert_file_not_exist "$src_path_1/dir1/$fname"
    assert_file_not_exist "$src_path_1/dir1/dir2/$fname"
    assert_file_not_exist "$src_path_1/dir1/dir2/dir3/$fname"
    assert_file_not_exist "$src_path_1/dir1/dir2/dir3/dir4/$fname"
    # test2
    assert_file_not_exist "$src_path_2/$fname"
    assert_file_not_exist "$src_path_2/dir1/$fname"
    assert_file_not_exist "$src_path_2/dir1/dir2/$fname"
    assert_file_not_exist "$src_path_2/dir1/dir2/dir3/$fname"
    assert_file_not_exist "$src_path_2/dir1/dir2/dir3/dir4/$fname"

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path_1" "$src_path_2"
    assert_success

    # 圧縮ファイルのみのリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "10 $move_files_path"
    # test1
    run grep -x $src_path_1/$gzipped $move_files_path 2>&1
    run grep -x $src_path_1/dir1/$gzipped $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/$gzipped $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/dir3/$gzipped $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/dir3/dir4/$gzipped $move_files_path 2>&1
    # test2
    run grep -x $src_path_2/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/dir4/$gzipped $move_files_path 2>&1

}

# bats test_tags=normal, find, patterns
@test "[015][ normal ][ ---- ] _find_move_files(): find matched file from all specified directories." {
    # make test data at two directories.
    today=$(get_date_today)
    src_path_1=$TEST_TEMP_DIR/test1
    src_path_2=$TEST_TEMP_DIR/test2
    make_test_files_at_two_directories $src_path_1 $src_path_2

    # テストファイルを全て圧縮する
    gzip_all_test_files $src_path_1
    gzip_all_test_files $src_path_2
    # 圧縮されているはず（とりあえず今日の日付）
    # test1
    assert_file_exists $src_path_1/$today.dat.gz
    assert_file_exists $src_path_1/dir1/$today.dat.gz
    assert_file_exists $src_path_1/dir1/dir2/$today.dat.gz
    assert_file_exists $src_path_1/dir1/dir2/dir3/$today.dat.gz
    assert_file_exists $src_path_1/dir1/dir2/dir3/dir4/$today.dat.gz
    # test2
    assert_file_exists $src_path_2/$today.dat.gz
    assert_file_exists $src_path_2/dir1/$today.dat.gz
    assert_file_exists $src_path_2/dir1/dir2/$today.dat.gz
    assert_file_exists $src_path_2/dir1/dir2/dir3/$today.dat.gz
    assert_file_exists $src_path_2/dir1/dir2/dir3/dir4/$today.dat.gz

    # 2日前と10日前の日付をパターンとして指定する
    date1=$(get_date_n_days_ago $today 2)
    pattern1="*${date1: -2}.dat" # ex) '*2.dat'
    date2=$(get_date_n_days_ago $today 10)
    pattern2="*${date2: -2}.*" # ex) '*2.*'
    INCLUDE_PATTERNS="$pattern1,$pattern2"
    MOVE_OLDER_THAN=1

    # echo "# date1: $date1, date2: $date2, pattern1: $pattern1, pattern2: $pattern2" >&3

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path_1" "$src_path_2"
    assert_success

    # 圧縮ファイルのみのリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "20 $move_files_path"
    # test1
    run grep -x $src_path_1/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/dir3/$date1.3.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/dir3/$date2.7.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/dir3/dir4/$date1.3.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/dir1/dir2/dir3/dir4/$date2.7.dat.gz $move_files_path 2>&1
    # test2
    run grep -x $src_path_2/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/$date2.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/dir4/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/dir4/$date2.dat.gz $move_files_path 2>&1

}

# bats test_tags=normal, find, patterns
@test "[016][ normal ][ ---- ] _find_move_files(): find matched file from all specified directories non recursively." {
    # make test data at two directories.
    today=$(get_date_today)
    src_path_1=$TEST_TEMP_DIR/test1
    src_path_2=$TEST_TEMP_DIR/test2
    make_test_files_at_two_directories $src_path_1 $src_path_2

    # テストファイルを全て圧縮する
    gzip_all_test_files $src_path_1
    gzip_all_test_files $src_path_2
    # 圧縮されているはず（とりあえず今日の日付）
    # test1
    assert_file_exists $src_path_1/$today.dat.gz
    assert_file_exists $src_path_1/dir1/$today.dat.gz
    assert_file_exists $src_path_1/dir1/dir2/$today.dat.gz
    assert_file_exists $src_path_1/dir1/dir2/dir3/$today.dat.gz
    assert_file_exists $src_path_1/dir1/dir2/dir3/dir4/$today.dat.gz
    # test2
    assert_file_exists $src_path_2/$today.dat.gz
    assert_file_exists $src_path_2/dir1/$today.dat.gz
    assert_file_exists $src_path_2/dir1/dir2/$today.dat.gz
    assert_file_exists $src_path_2/dir1/dir2/dir3/$today.dat.gz
    assert_file_exists $src_path_2/dir1/dir2/dir3/dir4/$today.dat.gz

    # 2日前と10日前の日付をパターンとして指定する
    date1=$(get_date_n_days_ago $today 2)
    pattern1="*${date1: -2}.dat" # ex) '*2.dat'
    date2=$(get_date_n_days_ago $today 10)
    pattern2="*${date2: -2}.*" # ex) '*2.*'
    INCLUDE_PATTERNS="$pattern1,$pattern2"
    MOVE_OLDER_THAN=1
    # これが肝
    NON_RECURSIVE=1

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path_1" "$src_path_2"
    assert_success

    # 圧縮ファイルのみのリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "4 $move_files_path"
    # test1
    run grep -x $src_path_1/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_1/$date2.dat.gz $move_files_path 2>&1
    # test2
    run grep -x $src_path_2/$date1.dat.gz $move_files_path 2>&1
    run grep -x $src_path_2/$date2.dat.gz $move_files_path 2>&1
}

# bats test_tags=normal, find, symlink
@test "[017][ normal ][ ---- ] _find_move_files(): find from specified symlinked directories." {
    # make test data at two directories.
    today=$(get_date_today)
    src_path_1=$TEST_TEMP_DIR/test1
    src_path_2=$TEST_TEMP_DIR/test2
    make_test_files $src_path_1
    WORK_PATH="$src_path_1/.work"
    mkdir -p $WORK_PATH

    # test1 へのシンボリックリンク test2 を作る
    ln -s $src_path_1 $src_path_2

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(get_date_before_oldest $today '%Y-%m-%d')
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate=$(get_date_before_oldest $today '%Y%m%d')
    local fname="$fdate.dat"
    # test1
    gzip "$src_path_1/$fname"
    gzip "$src_path_1/dir1/$fname"
    gzip "$src_path_1/dir1/dir2/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/dir4/$fname"

    # test2 でも圧縮されているはず
    local gzipped="$fname.gz"
    # test2
    assert_file_exists "$src_path_2/$gzipped"
    assert_file_exists "$src_path_2/dir1/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/dir3/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/dir3/dir4/$gzipped"

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path_2"
    assert_success

    # 圧縮ファイルのみのリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "5 $move_files_path"
    # test2
    run grep -x $src_path_2/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/$gzipped $move_files_path 2>&1
    run grep -x $src_path_2/dir1/dir2/dir3/dir4/$gzipped $move_files_path 2>&1

}

# bats test_tags=normal, find, symlink
@test "[018][ normal ][ ---- ] _find_move_files(): find from specified symlinked directories but disable to follow symlink." {
    # make test data at two directories.
    today=$(get_date_today)
    src_path_1=$TEST_TEMP_DIR/test1
    src_path_2=$TEST_TEMP_DIR/test2
    make_test_files $src_path_1
    WORK_PATH="$src_path_1/.work"
    mkdir -p $WORK_PATH

    # test1 へのシンボリックリンク test2 を作る
    ln -s $src_path_1 $src_path_2

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(get_date_before_oldest $today '%Y-%m-%d')
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate=$(get_date_before_oldest $today '%Y%m%d')
    local fname="$fdate.dat"
    # test1
    gzip "$src_path_1/$fname"
    gzip "$src_path_1/dir1/$fname"
    gzip "$src_path_1/dir1/dir2/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/dir4/$fname"

    # test2 でも圧縮されているはず
    local gzipped="$fname.gz"
    # test2
    assert_file_exists "$src_path_2/$gzipped"
    assert_file_exists "$src_path_2/dir1/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/dir3/$gzipped"
    assert_file_exists "$src_path_2/dir1/dir2/dir3/dir4/$gzipped"

    # シンボリックリンクを辿らない
    FOLLOW_SYMLINK=0

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path_2"
    assert_success

    # ファイルがリストされていないはず
    run wc -l $move_files_path 2>&1
    assert_output "0 $move_files_path"
}

# bats test_tags=normal, find, symlink
@test "[019][ normal ][ ---- ] _find_move_files(): directory tree looped by symlink." {
    # make test data at two directories.
    today=$(get_date_today)
    src_path_1=$TEST_TEMP_DIR/test1
    make_test_files $src_path_1
    WORK_PATH="$src_path_1/.work"
    mkdir -p $WORK_PATH

    # test1/dir1 へのシンボリックリンク test1/dir1/dir2/dir3/dir4/dir5 を作る
    ln -s $src_path_1/dir1 $src_path_1/dir1/dir2/dir3/dir4/dir5

    # 転送対象は各ディレクトリ階層の2番目に古い日付のファイル１つずつ
    # 一番古いファイルは未圧縮のままにして対象外とする
    MOVE_OLDER_THAN=8
    MOVE_DATE_UNTIL=$(get_date_before_oldest $today '%Y-%m-%d')
    export MOVE_OLDER_THAN
    export MOVE_DATE_UNTIL

    local fdate
    fdate=$(get_date_before_oldest $today '%Y%m%d')
    local fname="$fdate.dat"
    # test1
    gzip "$src_path_1/$fname"
    gzip "$src_path_1/dir1/$fname"
    gzip "$src_path_1/dir1/dir2/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/$fname"
    gzip "$src_path_1/dir1/dir2/dir3/dir4/$fname"

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path_1"
    assert_success

    # 対象ファイルがリストされているはず
    run wc -l $move_files_path 2>&1
    assert_output "5 $move_files_path"

    local gzipped="$fname.gz"
    run grep -x $src_path/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/dir2/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/dir2/dir3/$gzipped $move_files_path 2>&1
    run grep -x $src_path/dir1/dir2/dir3/dir4/$gzipped $move_files_path 2>&1
}

# bats test_tags=abnormal, find, patterns
@test "[020][abnormal][ ---- ] _find_move_files(): illegal pattern specified." {
    # make test data
    today=$(get_date_today)
    src_path=$TEST_TEMP_DIR
    make_test_files $src_path

    # テストファイルを全て圧縮する
    gzip_all_test_files $src_path

    # 圧縮されているはず（とりあえず今日の日付）
    # test1
    assert_file_exists $src_path/$today.dat.gz
    assert_file_exists $src_path/dir1/$today.dat.gz
    assert_file_exists $src_path/dir1/dir2/$today.dat.gz
    assert_file_exists $src_path/dir1/dir2/dir3/$today.dat.gz
    assert_file_exists $src_path/dir1/dir2/dir3/dir4/$today.dat.gz

    # カンマのみの不正なパターンを指定（指定無しと同義）
    INCLUDE_PATTERNS=","
    MOVE_OLDER_THAN=1
    NON_RECURSIVE=1

    # echo "# date1: $date1, date2: $date2, pattern1: $pattern1, pattern2: $pattern2" >&3

    # do test
    local move_files_path="$WORK_PATH/move-files.txt"
    run _find_move_files "$move_files_path" "$src_path"
    assert_success

    # 圧縮ファイルのみのリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "9 $move_files_path"

    # date=$(get_date_n_days_ago $today 1)
    # run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 2)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 3)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 4)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 5)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 6)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 7)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 8)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 9)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1
    date=$(get_date_n_days_ago $today 10)
    run grep -x $src_path/$date.dat.gz $move_files_path 2>&1

}

# bats test_tags=normal, mock, move, onebyone
@test "[021][ normal ][ mock ] _move_files_to_s3_one_by_one(): move all gzipped files." {
    # filelist, results, errors ファイルを消さずに残しておき
    # テスト後にTEST_TEMP_DIR の中身を確認したいときは以下のコメントを外す
    # BATSLIB_TEMP_PRESERVE=1
    # echo "# TEST_TEMP_DIR = $TEST_TEMP_DIR" >&3

    # 実行後にワークファイルに対してアサーション実施するための指示
    KEEP_TEMP_FILES=1

    local src_path="$TEST_TEMP_DIR/localsrc"
    mkdir -p $src_path

    S3_UPLOAD_PATH="$TEST_TEMP_DIR/s3dest"
    TX_BUFFER_PATH="$WORK_PATH/txbuffer"
    AWS_PROFILE="default"

    # 暗号化の準備
    prepare_certificate

    # 今日から3日古い日付までテストファイルを作る
    local today=$(date --date="$BEGIN_AT" "+%Y%m%d")
    make_test_files "$src_path" $today 3
    # 確認: find "$src_path" -exec echo "# {}" >&3 \;

    # 全て圧縮する
    gzip_all_test_files $src_path

    # 圧縮されているはず(とりあえず今日分のみチェック)
    local gzipped="$fname.gz"
    assert_file_exists "$src_path/$today.dat.gz"
    assert_file_exists "$src_path/dir1/$today.dat.gz"
    assert_file_exists "$src_path/dir1/dir2/$today.dat.gz"
    assert_file_exists "$src_path/dir1/dir2/dir3/$today.dat.gz"
    assert_file_exists "$src_path/dir1/dir2/dir3/dir4/$today.dat.gz"

    # _find_move_files のファイルリストを作る
    local move_files_path="$WORK_PATH/move-files.txt"
    find "$src_path" -type f -name "*.dat.gz" -fprint "$move_files_path"

    # 圧縮ファイルのみ 5x4日分のリストになっているはず
    run wc -l $move_files_path 2>&1
    assert_output "20 $move_files_path"

    # do test
    MOVE_ONE_BY_ONE=1
    MOVE_ERROR_LIMIT=3    # original defined at constants.sh

    run _move_files_to_s3_one_by_one "$move_files_path"
    assert_success

    # 出力の確認: with samples as follows
    #  encrypt '/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz' ... done.
    assert_line "encrypt '$src_path/$today.dat.gz' ... done."
    #  move '/tmp/test_move_to_s3.bats-1-MyuTtN/.work/txbuffer/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz.enc' to s3 ... done.
    assert_line "move '$TX_BUFFER_PATH$src_path/$today.dat.gz.enc' to s3 ... done."
    #  file moved from '/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz' to s3.
    assert_line "file moved from '$src_path/$today.dat.gz' to s3."
    #  restore from s3: $ aws s3 cp '/tmp/test_move_to_s3.bats-1-MyuTtN/s3dest/tmp/test_move_to_s3.bats-1-MyuTtN/.work/txbuffer/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz.enc' './tmp/test_move_to_s3.bats-1-MyuTtN/.work/txbuffer/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz.enc' && openssl smime -decrypt -in './tmp/test_move_to_s3.bats-1-MyuTtN/.work/txbuffer/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz.enc' -binary -inform DEM -inkey /.ssh/id_rsa -out './tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz' && rm './tmp/test_move_to_s3.bats-1-MyuTtN/.work/txbuffer/tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz.enc' && gunzip './tmp/test_move_to_s3.bats-1-MyuTtN/localsrc/20230908.dat.gz'
    assert_line "restore from s3: $ aws s3 cp '$S3_UPLOAD_PATH$src_path/$today.dat.gz.enc' '.$src_path/$today.dat.gz.enc' && openssl smime -decrypt -in '.$src_path/$today.dat.gz.enc' -binary -inform DEM -inkey /.ssh/id_rsa -out '.$src_path/$today.dat.gz' && rm -f '.$src_path/$today.dat.gz.enc' && gunzip '.$src_path/$today.dat.gz'"
 
    # 全て移動したはず
    # 送信バッファにファイルが残っていないはず
    local remaining_enc_files_path="$WORK_PATH/remaining-enc-files.txt"
    find "$TX_BUFFER_PATH" -type f -name "*.dat.gz.enc" -fprint "$remaining_enc_files_path"
    run wc -l $remaining_enc_files_path 2>&1
    assert_output "0 $remaining_enc_files_path"
    # src_path 以下にファイルが残っていないはず
    local remaining_src_files_path="$WORK_PATH/remaining-src-files.txt"
    find "$src_path" -type f -name "*.dat.gz" -fprint "$remaining_src_files_path"
    run wc -l $remaining_src_files_path 2>&1
    assert_output "0 $remaining_src_files_path"
    # 送信先にファイルが有るはず
    local moved_dst_files_path="$WORK_PATH/moved-dst-files.txt"
    find "$S3_UPLOAD_PATH" -type f -name "*.dat.gz.enc" -fprint "$moved_dst_files_path"
    run wc -l $moved_dst_files_path 2>&1
    assert_output "20 $moved_dst_files_path"
}

#EOS
