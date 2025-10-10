#!/usr/bin/env bash
# -- maketestdat.sh
#
# テスト用のディレクトリ階層とファイルを作成する
# usage:
#   mktestdat.sh [テストディレクトリ名] [基準日] [過去日数]
#
# 指定したテストディレクトリ名で4階層のディレクトリを作成し、
# 各ディレクトリ内に基準日(デフォルトは今日)から過去日数(デフォルトは10日)
# 前から基準日までの日付のファイルを作成する
#（つまり過去日数＋１本のファイルが作成される）
#
make_test_files() {
    local today
    today="$(date +%Y%m%d)"
    local base_dir="$1"
    local base_date
    base_date=${2:-$today}
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
            local date
            date=$(date --date="$base_date $q" +%Y%m%d)
            local fname="$date$suffix.dat"
            echo "$date" >"$dir/$fname"
            touch --date="$date 12:34:56" "$dir/$fname"
        done
    done

    # find "$base_dir" | sort >&3
}

dir=${1:-testdata}

rm -rf "$dir"

make_test_files "$dir"

# EOS
