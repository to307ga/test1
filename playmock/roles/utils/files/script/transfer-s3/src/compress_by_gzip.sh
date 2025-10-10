#!/usr/bin/env bash
# compress_by_gzip.sh
# transfer-s3: Compress old files by gzip.

# variables
_COMPRESSED_COUNT=0
_COMPRESS_FAILED_COUNT=0

#######################################
# _find_compress_files(outfile, dirs)
#--------------------------------------
# 内部処理：圧縮対象のファイルを取得しファイルに保存する
#
# GLOBALS:
#   COMMAND_NAME
#   GZIP_OLDER_THAN
#   WORK_PATH
#   NON_RECURSIVE
# ARGUMENTS:
#   $1: outfile - ファイル一覧を出力するファイル
#   $2: dirs    - 処理対象ディレクトリ
# OUTPUTS:
#   $1: outfile が指すファイルに対象ファイルパスを出力
#   ファイルパスは1行1ファイルをフルパスで出力。行末は改行
# RETURN:
#   常に 0
#######################################
function _find_compress_files() {
    local old_flags="$-"
    set +e # disable errexit

    local outfile="${1:-}"
    shift
    if [[ -z $outfile ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): a outfile path must be specified as argument 1."
    elif ! touch "$outfile"; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): $outfile is not writable."
    fi

    local source_paths="$*"
    if [[ -z $source_paths ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): a source directory must be specified as argument 2."
    fi

    local has_err=0
    for path in "${@}"; do
        if [[ ! -d $path ]]; then
            journal_err "$COMMAND_NAME: ${FUNCNAME[0]}(): specified source directory is not a directory. ($path)"
            has_err=1
        fi
    done
    if [[ 0 -ne $has_err ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): all specified paths must be directories."
    fi


    set "-$old_flags"

    # starting points
    IFS=" " read -ra args <<< "$source_paths"

    # follow symlinks
    if [[ 0 -ne $FOLLOW_SYMLINK ]]; then
        args=( -L "${args[@]}" )
    fi

    # non recursive ?
    if [[ 0 -ne $NON_RECURSIVE ]]; then
        args+=( -maxdepth 1 )
    fi

    # exclude the work path
    args+=( -not -path "'*/$WORK_DIR_NAME/*'" )

    # file date to search
    args+=( -daystart -type f -mtime "+$GZIP_OLDER_THAN" )

    # exclude compressed file
    args+=( -not -iname '*.gz' -not -iname '*.zip' )

    # and include files matched specified patterns
    # patterns                result part of args
    # ----------------------  -------------------------------------
    # ( pat1* )               "-name pat1*"
    # ( pat1* pat2* )         "'('' -name pat1* -o -name pat2* ')'"
    # ( pat3*.dat )           "-name pat3*.dat"
    # ( pat4*.log.?)          "-name pat4*.log.?"
    if [[ -n $INCLUDE_PATTERNS ]]; then
        local cnt=0
        local patternArgs
        IFS="," read -ra patternArgs <<< "$INCLUDE_PATTERNS"
        local patternOpts=()

        for pattern in "${patternArgs[@]}"; do
            if [[ -n "$pattern" ]]; then
                if [[ $cnt -gt 0 ]]; then
                    patternOpts+=( -o )
                fi
                patternOpts+=( -name "$pattern" )
                cnt=$((cnt + 1))
            fi
        done

        if [[ $cnt -ge 2 ]]; then
            args+=( '(' "${patternOpts[@]}" ')' )
        else
            args+=( "${patternOpts[@]}" )
        fi
    fi
    # echo find "${args[@]}"

    # do find
    (find "${args[@]}" | sort >"$outfile")

    return 0
}

#######################################
# _compress_file(file)
#--------------------------------------
# 内部処理：ファイルを圧縮する
#
# GLOBALS:
#   COMMAND_NAME
#   DRYRUN
#   _COMPRESSED_COUNT
#   _COMPRESS_FAILED_COUNT
# ARGUMENTS:
#   $1: file - 圧縮対象ファイル
# OUTPUTS:
#   _COMPRESSED_COUNT
#   _COMPRESS_FAILED_COUNT
# RETURN:
#   常に 0
#######################################
function _compress_file() {
    local file=${1:-}
    if [[ ! -f "$file" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): compress file path must be specified as argument 1"
    fi

    if [[ $DRYRUN -eq 0 ]]; then
        # do compress and keep mtime.
        if gzip "$file"; then
            journal "gzip '$file' ... done."
            _COMPRESSED_COUNT=$((_COMPRESSED_COUNT + 1))
        else
            journal_err "ERROR: gzip '$file' ... failed."
            _COMPRESS_FAILED_COUNT=$((_COMPRESS_FAILED_COUNT + 1))
        fi
    else
        # dry-run
        journal "gzip '$file' ... done."
        _COMPRESSED_COUNT=$((_COMPRESSED_COUNT + 1))
    fi

    return 0
}

#######################################
# compress_old_files(dirs)
#--------------------------------------
# 指定日以前のファイルを圧縮する
#
# GLOBALS:
#   COMMAND_NAME
#   GZIP_OLDER_THAN
#   GZIP_DATE_UNTIL
#   WORK_PATH
#   FILE_UNIQUNIZE
# ARGUMENTS:
#   $@: dirs - 処理対象ディレクトリのリスト(フルパス)
# OUTPUTS:
#   GZIP_FILES_PATH
#   GZIP_FILES_PATH が指すファイルに圧縮対象ファイルのパスを出力
#     パスは1行1ファイルをフルパスで出力。末尾は改行
#     アルファベット順にソートされている。
# RETURN:
#   常に 0
# REMARKS:
#   KEEP_TEMP_FILES=1 で一時ファイルである圧縮対象ファイルリスト
#   を消さずに残すことができる
#######################################
function compress_old_files() {
    if [[ -z $* ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): a source directory must be specified as argument 1."
    fi
    local has_err=0
    for path in "${@}"; do
        if [[ ! -d $path ]]; then
            journal_err "$COMMAND_NAME: ${FUNCNAME[0]}(): specified source directory is not a directory. ($path)"
            has_err=1
        fi
    done
    if [[ 0 -ne $has_err ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): all specified paths must be directories."
    fi

    local old_flags="$-"
    set +e # disable errexit

    journal "## Start gzip files that older than $GZIP_OLDER_THAN days(until $GZIP_DATE_UNTIL)."

    GZIP_FILES_PATH="$WORK_PATH/gzip-files-$FILE_UNIQUNIZE.txt"
    _find_compress_files "$GZIP_FILES_PATH" "$@"

    _COMPRESSED_COUNT=0
    _COMPRESS_FAILED_COUNT=0

    while IFS= read -r line; do
        _compress_file "$line"
    done <"$GZIP_FILES_PATH"

    journal "## End of gzip files."
    if [[ $_COMPRESSED_COUNT -ne 0 ]]; then
        journal "Total $_COMPRESSED_COUNT file(s) gzipped successfully."
    else
        journal "No files gzipped."
    fi

    if [[ $_COMPRESS_FAILED_COUNT -ne 0 ]]; then
        jounral_err "ERROR: Total $_COMPRESS_FAILED_COUNT file(s) failed to gzip."
    fi

    set "-$old_flags"

    # 一時ファイルを削除する
    KEEP_TEMP_FILES=${KEEP_TEMP_FILES:-0}
    if [[ $KEEP_TEMP_FILES -eq 0 ]]; then
        rm "$GZIP_FILES_PATH"
    fi
    return 0
}

#######################################
# -- 開発時の簡易動作確認
#
#   1. compress_old_files 関数の動作確認
#
# ARGUMENTS:
#   $1: 処理対象ディレクトリ
#   $2: 対象ファイルパターン 'file1*,file2*' (オプション)
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "compress_by_gzip.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC2034 # because used for error_trap.sh
    DEBUG=${DEBUG:-0}

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/error_trap.sh"

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

    # set variables
    MYNAME=$(basename "$COMMAND_NAME" .sh)
    FILE_UNIQUNIZE=$(date +%Y%m%d-%H%M%S-%N)
    GZIP_OLDER_THAN=${GZIP_OLDER_THAN:-30}
    GZIP_DATE_UNTIL=$(date --date="$((GZIP_OLDER_THAN + 1)) days ago" +%Y-%m-%d)
    DRYRUN=${DRYRUN:-0}
    NON_RECURSIVE=${NON_RECURSIVE:-0}

    # target directory
    dir=${1:-}

    # include file patterns
    INCLUDE_PATTERNS=${2:-}
    IFS="," read -ra patternArgs <<< "$INCLUDE_PATTERNS"

    # do test

    if [[ -z $dir ]]; then
        # for empty path test.
        src_path=""
        WORK_PATH=""
    elif [[ -d $dir ]]; then
        # for normal test.
        src_path=$(cd "$(realpath "$dir")" && pwd)
        WORK_PATH="$src_path/.$MYNAME"
        mkdir -p "$WORK_PATH"
    else
        # for no-directory test
        src_path=$(realpath "$dir")
    fi

    compress_old_files "$src_path"

fi

#EOS
