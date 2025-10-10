#!/usr/bin/env bash
# move_to_s3.sh
# transfer-s3: Encrypt and move old files to S3.

# require crypt.sh    # main でロードすること

# variables
_SOURCE_COUNT=0         # 移動対象ファイル数
_ENCRYPTED_COUNT=0      # 暗号化済みファイル数
_ENCRYPT_FAILED_COUNT=0 # 暗号化失敗ファイル数
_MOVED_COUNT=0          # 移動完了ファイル数
_MOVE_FAILED_COUNT=0    # 移動失敗ファイル数

_TX_RESULTS_PATH="" # 転送結果保持ファイルのパス
_TX_ERRORS_PATH=""  # 転送時エラー保持ファイルのパス

_MOVE_ERROR_COUNT=0 # one by one 転送時のエラー発生回数
                    # 規定回数(MOVE_ERROR_LIMIT)以上のエラー発生で処理を中断する

#######################################
# _find_move_files(outfile, dirs)
#--------------------------------------
# 内部処理：移動対象のファイルを取得しファイルに保存する
#
# GLOBALS:
#   COMMAND_NAME
#   MOVE_OLDER_THAN
#   NON_RECURSIVE
#   WORK_PATH
# ARGUMENTS:
#   $1: outfile - ファイル一覧を出力するファイル
#   $2: dirs    - 処理対象ディレクトリのリスト
# OUTPUTS:
#   _SOURCE_COUNT - 対象ファイル数
#   $2: outfile が指すファイルに対象ファイルパスを出力
#   ファイルパスは1行1ファイルをフルパスで出力。行末は改行
# RETURN:
#   常に 0
# REMARKS
#   致命的なエラーは raise で終了する
#######################################
function _find_move_files() {
    local old_flags="$-"
    set +e # disable errexit

    local outfile="${1:-}"
    shift
    if [[ -z $outfile ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): a outfile path must be specified as argument 1."
    fi
    if [[ -e "$outfile" ]] && [[ ! -f "$outfile" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): specified file path is not writable. might be a directory. ($outfile)"
    fi
    if ! touch "$outfile"; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): specified file is not writable. ($outfile)"
    fi

    local source_paths="$*"
    if [[ -z $source_paths ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): a source directory must be specified as argument 2."
    fi
    local has_err=0
    for path in "${@}"; do
        if [[ ! -d $path ]]; then
            raise "$COMMAND_NAME: ${FUNCNAME[0]}(): specified source directory is not a directory. ($path)"
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
    args+=( -daystart -type f -mtime "+$MOVE_OLDER_THAN" )

    # include compressed file only
    args+=( '(' -iname '*.gz' -o -iname '*.zip' ')' )

    # and include files matched specified patterns
    # patterns                result part of args
    # ----------------------  -------------------------------------
    # ( pat1* )               "-name pat1*"
    # ( pat1* pat2* )         "'('' -name pat1* -o -name pat2* ')'"
    # ( pat3*.dat )           "-name pat3*.dat.*"   --> matching for *.gz|*.zip
    # ( pat4*.log.?)          "-name pat4*.log.?.*" --> matching for *.gz|*.zip too
    if [[ -n $INCLUDE_PATTERNS ]]; then
        local cnt=0
        local patternOpts=()
        IFS="," read -ra patternArgs <<< "$INCLUDE_PATTERNS"

        for pattern in "${patternArgs[@]}"; do
            if [[ -n "$pattern" ]]; then
                if [[ $cnt -gt 0 ]]; then
                    patternOpts+=( -o )
                fi
                # append '.*' if pattern ending without '*'
                if [[ "$pattern" == *[^\*] ]]; then
                    pattern="$pattern.*"
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

    _SOURCE_COUNT=$(wc -l <"$outfile")

    return 0
}

#######################################
# encrypt_file(file, no_encryption)
#--------------------------------------
# ファイルを暗号化する
# ファイルは TX_BUFFER_PATH が指すディレクトリ下に暗号化される
#
# GLOBALS:
#   COMMAND_NAME
#   TX_BUFFER_PATH
# ARGUMENTS:
#   $1: file - 暗号化対象ファイル
#   $2: no_encryption - 暗号化ファイルを作成するかどうか
#                           0: 作成する
#                       0以外: 作成しない(ディレクトリ構造も作らない)
# OUTPUTS:
#   stdout - 暗号化済みファイルパス
# RETURN:
#       0: 成功
#   0以外: 失敗
#   致命的なエラーは raise で終了する
# REMARKS
# ・暗号化対象ファイルのルートパスからのディレクトリ構造が TX_BUFFER_PATH 下に作成される
#   例：
#     file=/var/log/httpd/access_log.1.gz の場合
#     $TX_BUFFER_PATH/var/log/httpd/access_log.1.gz.enc が作成される
#######################################
function encrypt_file() {
    local file

    # to full path
    if [[ ${1:0:1} != "/" ]]; then
        file=$(cd "$(dirname "$(realpath "$1")")" && pwd)/$(basename "$1")
    else
        file="$1"
    fi

    if [[ ! -f "$file" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): encrypt file path must be specified as argument 1"
    fi

    local no_encryption=${2:-0}

    # make a encrypted file path
    local outfile="$TX_BUFFER_PATH$file.enc"
    echo "$outfile"

    if [[ $no_encryption -ne 0 ]]; then
        # skip encryption.
        return 0
    fi

    # make a directory structures if any
    local dir_outfile
    dir_outfile=$(dirname "$outfile")
    mkdir -p "$dir_outfile"
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        raise "Failed to create a directory for encrypted file at '$dir_outfile'."
    fi

    encrypt "$file" "$outfile"
    return $?
}

#######################################
# _encrypt_move_files(listfile)
#--------------------------------------
# 内部処理：移動対象ファイルを暗号化する
#
# GLOBALS:
#   COMMAND_NAME
#   DRYRUN
#   DEBUG
#   _ENCRYPTED_COUNT
#   _ENCRYPT_FAILED_COUNT
# ARGUMENTS:
#   $1: listfile - 移動対象一覧ファイル
# OUTPUTS:
#   _ENCRYPTED_COUNT
#   _ENCRYPT_FAILED_COUNT
# RETURN:
#   常に 0
#######################################
function _encrypt_move_files() {
    local listfile=${1:-}
    if [[ ! -f "$listfile" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): list file path must be specified as argument 1"
    fi

    local old_flags="$-"
    set +e # disable errexit

    while IFS= read -r line; do
        if encrypt_file "$line" "$DRYRUN"; then
            _ENCRYPTED_COUNT=$((_ENCRYPTED_COUNT + 1))
            if [[ $DEBUG -ne 0 ]]; then
                journal_err "encrypt '$line' ... done."
            fi
        else
            _ENCRYPT_FAILED_COUNT=$((_ENCRYPT_FAILED_COUNT + 1))
            if [[ $DEBUG -ne 0 ]]; then
                journal_err "encrypt '$line' ... failed."
            fi
        fi
    done <"$listfile"

    set "-$old_flags"
    return 0
}

#######################################
# _s3_sync_post_process(s3_results)
#--------------------------------------
# 内部処理：aws s3 sync コマンド出力に従って後処理を行う
#          ※転送に成功した暗号化ファイルに相当するバックアップ対象ファイルを削除する
#
# 前提条件：aws s3 sync コマンドの出力が以下の書式であることを想定している
#
#   upload: <local-source> to <remote-destination>
#
#   local-source - 送信元ファイルのパス
#                  ただし aws s3 sync コマンドに送信元として指定したパスの
#                  末端ディレクトリ名(つまりホスト名)以降の相対パスである事に注意
#     例： 送信元パス： /var/log/httpd/.transfer-s3/idhub-30-pro-web-001
#                                                   ^^^^^^^^^^^^^^^^^^^^
#        送信ファイル： ./var/log/httpd/access_log.1.gz.enc
#                        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#          送信先パス： s3://backup-idhub/idhub-30-pro-web-001
#     のとのき
#          コマンド行： aws s3 sync <送信元パス> <送信先パス> --no-progress
#        による結果行： upload: idhub-30-pro-web-001/var/log/httpd/access_log.1.gz.enc to s3://backup-idhub/idhub-30-pro-web-001/var/log/httpd/access_log.1.gz.enc
#                               ^^^^^^^^^^^^^^^^^^^^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#          また、DRYRUN=1 のときは
#          コマンド行： aws s3 sync <送信元パス> <送信先パス> --no-progress --dryrun
#        による結果行： (dryrun) upload: idhub-30-pro-web-001/var/log/httpd/access_log.1.gz.enc to s3://backup-idhub/idhub-30-pro-web-001/var/log/httpd/access_log.1.gz.enc
#          となる。
#
#   remote-destination - 送信先ファイルのパス
#                        アップロードに成功したファイルをローカルから削除する際のファイルのパスをこれから抽出する
#     書式： S3_UPLOAD_PATH<削除対象ファイルパス>.enc
#
#               S3_UPLOAD_PATH: s3://<バケット名>/<バックアップ対象ホスト名>
#        <削除対象ファイルパス>: 削除対象ファイルのフルパス
#                         .enc: アップロードした暗号化ファイルの拡張子
# GLOBALS:
#   COMMAND_NAME
#   DRYRUN
# ARGUMENTS:
#   $1: s3_results - aws s3 sync コマンドの結果出力ファイル
# OUTPUTS:
#   _MOVED_COUNT
#   _MOVE_FAILED_COUNT
# RETURN:
#   常に 0
# REMARKS:
#   アップロードに成功した場合暗号化前のファイルは
#   ローカルストレージから削除する
#
#######################################
function _s3_sync_post_process() {
    local s3_results=${1:-}

    local dryrun=""
    if [[ $DRYRUN -ne 0 ]]; then
        dryrun="(dryrun) "
    fi

    _MOVED_COUNT=0
    _MOVE_FAILED_COUNT=0

    while IFS= read -r line; do
        case $line in
        "(dryrun)"*)
            # (dryrun) ...
            journal "$line"
            ;;
        "upload:"*)
            # upload: <local-source> to <remote-destination>
            # 転送に成功した暗号化ファイルに相当するバックアップ対象ファイルを削除する
            #（DRYRUN時は "(dryrun)"* ケースで処理されるためここでは考慮しない）

            # 1. 削除対象パスの抽出
            #    削除対象パスは remote-destination の先頭から S3_UPLOAD_PATHを、
            #    また拡張子 .enc を削除したものとなる
            local dest
            dest=$(echo "$line" | sed -n 's@.* to \(s3://.*\)$@\1@p')
            if [[ -z $dest ]]; then
                journal_err "Unexpected result line of aws s3 sync. : '$line'"
                continue
            fi
            local uploaded_file=${dest#"$S3_UPLOAD_PATH"}
            local backup_source="${uploaded_file%.enc}"

            # 2. 削除
            if ! rm "$backup_source" 1>&2; then
                journal_err "failed to delete the backup source file: '$backup_source'. code: $?"
                _MOVE_FAILED_COUNT=$((_MOVE_FAILED_COUNT + 1))
            else
                # journaling the restore command line.
                local cmd_download="aws s3 cp '$dest' '.$uploaded_file'"
                local cmd_decrypt="openssl smime -decrypt -in '.$uploaded_file' -binary -inform DEM -inkey $CRYPT_OWNERS_HOME/.ssh/id_rsa -out '.$backup_source'"
                local cmd_rm_downloaded="rm -f '.$uploaded_file'"
                local cmd_ungzip="gunzip '.$backup_source'"

                journal "file moved from '$backup_source' to s3."
                journal "restore from s3: $ $cmd_download && $cmd_decrypt && $cmd_rm_downloaded && $cmd_ungzip"
                _MOVED_COUNT=$((_MOVED_COUNT + 1))
            fi
            ;;
        "delete:"*)
            # あり得ないが、処理としては無視する
            journal_err "WARNING: Unexpected delete operation on s3, but ignored: $s3_results"
            return 0
            ;;
        "copy:"*)
            # あり得ないが、処理としては無視する
            journal_err "WARNING: Unexpected copy operation on s3, but ignored: $s3_results"
            return 0
            ;;
        "download:"*)
            # あり得ないが、処理としては無視する
            journal_err "WARNING: Unexpected download operation on s3, but ignored: $s3_results."
            return 0
            ;;
        *)
            # 上記以外はエラーとして扱う
            # 正しいエラーメッセージ書式が手に入ったら調整が必要かもしれない
            journal_err "ERROR: Failed to upload: $line"
            _MOVE_FAILED_COUNT=$((_MOVE_FAILED_COUNT + 1))
            ;;
        esac
    done <"$s3_results"

    return 0
}

#######################################
# _move_encrypted_files_to_s3(listfile)
#--------------------------------------
# 内部処理：ファイルリストの全ファイルをS3に移動（転送に成功した
#           暗号化ファイルに相当するバックアップ対象ファイルを削除）する
#           aws s3 sync コマンドによるディレクトリの同期を行うが
#           転送先に対して常に追加更新処理を行い転送先のファイル削除は行わない
# GLOBALS:
#   COMMAND_NAME
#   DRYRUN
#   AWS_PROFILE
#   BEGIN_AT
#   TX_BUFFER_PATH
#   S3_UPLOAD_PATH
#   JOURNAL_PATH
# ARGUMENTS:
#   $1: listfile - 移動対象一覧ファイル
# OUTPUTS:
#   _TX_RESULTS_PATH - aws s3 sync コマンドの stdout を格納したファイル
#   _TX_ERRORS_PATH - aws s3 sync コマンドの stderr を格納したファイル
# RETURN:
#   正常時常に 0 を返す
#   致命的なエラーは raise で終了する
# REMARKS:
#   アップロードに成功した場合暗号化前のファイルは
#   ローカルストレージから削除する
#######################################
function _move_encrypted_files_to_s3() {
    local listfile=${1:-}

    _TX_RESULTS_PATH="$WORK_PATH/aws_s3_sync_results-$FILE_UNIQUNIZE.txt"
    _TX_ERRORS_PATH="$WORK_PATH/aws_s3_sync_errors-$FILE_UNIQUNIZE.txt"

    local aws_cmd
    aws_cmd=(aws s3 sync "$TX_BUFFER_PATH" "$S3_UPLOAD_PATH" --no-progress --page-size=1 --profile="$AWS_PROFILE")

    if [[ $DRYRUN -ne 0 ]]; then
        aws_cmd+=(--dryrun)
    fi

    # do sync local to s3
    if ! ("${aws_cmd[@]}" >"$_TX_RESULTS_PATH" 2>"$_TX_ERRORS_PATH"); then
        journal_err "ERROR: failed to upload on aws s3 sync command."
        journal_err "ERROR: check '$_TX_RESULTS_PATH' and '$_TX_ERRORS_PATH' for details of upload command as follows."
        journal_err "ERROR: '${aws_cmd[*]}'"
        _results_to_journal "$listfile" "$_TX_RESULTS_PATH" "$_TX_ERRORS_PATH" "sync"
        raise "File move aborted by error. check the journal file for details: $JOURNAL_PATH"
    fi

    _s3_sync_post_process "$_TX_RESULTS_PATH"

    return 0
}

#######################################
# _results_to_journal(filelist, results, errors, method='sync')
#--------------------------------------
# 内部処理：移動ファイルリストとaws s3 sync|move コマンドの結果を
# ジャーナルに出力する
# ただし、指定ファイルが存在する時のみ出力する
#
# GLOBALS:
#   COMMAND_NAME
#   MOVE_OLDER_THAN
#   MOVE_DATE_UNTIL
#   WORK_PATH
#   FILE_UNIQUNIZE
# ARGUMENTS:
#   $1: filelist - 移動対象ファイル一覧
#   $2: results  - aws s3 コマンドの結果出力
#   $3: errors   - aws s3 コマンドのエラー出力
#   $4: method   - 'sync' (default) または 'move'
# OUTPUTS:
#   JOURNAL_PATH が示すファイルに出力
# RETURN:
#   常に 0
# REMARKS:
#######################################
function _results_to_journal() {
    local filelist=${1:-}
    local results=${2:-}
    local errors=${3:-}
    local method=${4:-'sync'}

    if [[ -f $filelist ]]; then
        {
            echo "------ BEGIN: move file list ------"
            cat "$filelist"
            echo "------   END: move file list ------"
            echo ""
        } >>"$JOURNAL_PATH"
    else
        {
            echo "No move file list."
            echo ""
        } >>"$JOURNAL_PATH"
    fi

    if [[ -f $results ]]; then
        {
            echo "------ BEGIN: 'aws s3 $method' results ------"
            cat "$results"
            echo "------   END: 'aws s3 $method' results ------"
            echo ""
        } >>"$JOURNAL_PATH"
    else
        {
            echo "No results of 'aws s3 $method' command."
            echo ""
        } >>"$JOURNAL_PATH"
    fi

    if [[ -f $errors ]]; then
        {
            echo "------ BEGIN: 'aws s3 $method' errors ------"
            cat "$errors"
            echo "------   END: 'aws s3 $method' errors ------"
            echo ""
        } >>"$JOURNAL_PATH"
    else
        {
            echo "No errors of 'aws s3 $method' command."
            echo ""
        } >>"$JOURNAL_PATH"
    fi
}

#######################################
# _move_files_to_s3_one_by_one(listfile)
#--------------------------------------
# 内部処理：移動対象ファイルの暗号化とS3への移動を1ファイルずつ行う
#
# GLOBALS:
#   COMMAND_NAME
#   DEBUG
# ARGUMENTS:
#   $1: listfile - 移動対象一覧ファイル
# OUTPUTS:
#   _TX_RESULTS_PATH
#   _TX_ERRORS_PATH
#   _ENCRYPTED_COUNT
#   _ENCRYPT_FAILED_COUNT
#   _MOVED_COUNT
#   _MOVE_FAILED_COUNT
# RETURN:
#   常に 0
# REMARKS
#   致命的なエラーは raise で終了する
#######################################
function _move_files_to_s3_one_by_one ()
{
    local listfile=${1:-}
    if [[ ! -f "$listfile" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): list file path must be specified as argument 1"
    fi

    # reset error count
    _MOVE_ERROR_COUNT=0

    # result file paths.
    _TX_RESULTS_PATH="$WORK_PATH/aws_s3_move_results-$FILE_UNIQUNIZE.txt"
    _TX_ERRORS_PATH="$WORK_PATH/aws_s3_move_errors-$FILE_UNIQUNIZE.txt"

    local old_flags="$-"
    set +e # disable errexit

    # Abort processing if an error occurs more than the MOVE_ERROR_LIMIT times.
    local abortedByMoveError=0

    # encrypt and move all files in the listfile
    while IFS= read -r backup_source; do
        # 1. 暗号化
        local encrypted_path
        encrypted_path="$(encrypt_file "$backup_source" "$DRYRUN")"
        local ret=$?
        if [[ $ret -eq 0 ]]; then
            # success encryption
            _ENCRYPTED_COUNT=$((_ENCRYPTED_COUNT + 1))
            if [[ $DEBUG -ne 0 ]]; then
                journal_err "encrypt '$backup_source' ... done."
            fi
        else
            _ENCRYPT_FAILED_COUNT=$((_ENCRYPT_FAILED_COUNT + 1))
            if [[ $DEBUG -ne 0 ]]; then
                journal_err "encrypt '$backup_source' ... failed."
            fi
            continue
        fi

        # 2. ファイル移動
        dest=$(_move_one_encrypted_file_to_s3 "$encrypted_path" "$backup_source")
        ret=$?
        if [[ $ret -eq 0 ]]; then
            # success to move
            if [[ $DEBUG -ne 0 ]]; then
                journal_err "move '$encrypted_path' to s3 ... done."
            fi
        else
            _MOVE_FAILED_COUNT=$((_MOVE_FAILED_COUNT + 1))
            if [[ $DEBUG -ne 0 ]]; then
                journal_err "move '$encrypted_path' to s3 ... failed."
            fi
            # 規定回数以上のエラー発生で処理中断
            _MOVE_ERROR_COUNT=$((_MOVE_ERROR_COUNT + 1))
            if [[ $_MOVE_ERROR_COUNT -gt $MOVE_ERROR_LIMIT ]]; then
                abortedByMoveError=1
                break
            else
                continue
            fi
        fi
        
        # 3. バックアップ元ファイル削除
        if [[ $DRYRUN -ne 0 ]]; then
            # no remove the file on Dry-Run mode.
            _MOVED_COUNT=$((_MOVED_COUNT + 1))
        else
            if ! rm "$backup_source" 1>&2; then
                journal_err "failed to delete the backup source file: '$backup_source'. code: $?"
                _MOVE_FAILED_COUNT=$((_MOVE_FAILED_COUNT + 1))
            else
                # journaling the restore command line.
                local uploaded_file=${dest#"$S3_UPLOAD_PATH"}
                local cmd_download="aws s3 cp '$dest' '.$uploaded_file'"
                local cmd_decrypt="openssl smime -decrypt -in '.$uploaded_file' -binary -inform DEM -inkey $CRYPT_OWNERS_HOME/.ssh/id_rsa -out '.$backup_source'"
                local cmd_rm_downloaded="rm -f '.$uploaded_file'"
                local cmd_ungzip="gunzip '.$backup_source'"

                journal "file moved from '$backup_source' to s3."
                journal "restore from s3: $ $cmd_download && $cmd_decrypt && $cmd_rm_downloaded && $cmd_ungzip"
                _MOVED_COUNT=$((_MOVED_COUNT + 1))
            fi
        fi

    done <"$listfile"

    # dump intermediate files to journal when aborted by move error occurs many times.
    if [[ $abortedByMoveError -ne 0 ]]; then
        journal_err "ERROR: failed to upload over $MOVE_ERROR_LIMIT times on aws s3 mv command."
        journal_err "ERROR: check '$_TX_RESULTS_PATH' and '$_TX_ERRORS_PATH' for details of upload command as follows."
        _results_to_journal "$listfile" "$_TX_RESULTS_PATH" "$_TX_ERRORS_PATH" "move"
        raise "File move aborted by error. check the journal file for details: $JOURNAL_PATH"
    fi

    set "-$old_flags"
    return 0
}

#######################################
# _move_one_encrypted_file_to_s3(file)
#--------------------------------------
# 内部処理：暗号化ファイルをS3に移動する
# aws s3 mv コマンドを利用
#
# GLOBALS:
#   COMMAND_NAME
#   DRYRUN
#   S3_UPLOAD_PATH
#   AWS_PROFILE
# ARGUMENTS:
#   $1: enc_file - アップロードする暗号化ファイルのフルパス
#   $2: src_file - バックアップ対象ファイルのフルパス
# OUTPUTS:
#   stdout - 送信先 S3 パス
#   _TX_RESULTS_PATH - aws s3 mv コマンドの stdout 出力
#   _TX_ERRORS_PATH - aws s3 mv コマンドの stderr 出力
# RETURN:
#   成功時 0
#   失敗時 0以外
#   致命的なエラーは raise で終了する
# REMARKS:
#   成功時、暗号化ファイルは(aws s3 mv コマンドにより)削除される
#######################################
function _move_one_encrypted_file_to_s3() {
    local enc_file=${1:-}
    if [[ ! -f "$enc_file" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): upload encrypted file path must be specified as argument 1"
    fi
    local src_file=${2:-}
    if [[ ! -f "$src_file" ]]; then
        raise "$COMMAND_NAME: ${FUNCNAME[0]}(): backup source file path must be specified as argument 2"
    fi
    
    local s3_dst_path
    s3_dst_path=$(dirname "$S3_UPLOAD_PATH$src_file")/$(basename "$enc_file")
    echo "$s3_dst_path"
    # echo "# $s3_dst_path" >&3

    local aws_cmd
    aws_cmd=(aws s3 mv "$enc_file" "$s3_dst_path" --no-progress --page-size=1 --profile="$AWS_PROFILE")

    if [[ $DRYRUN -ne 0 ]]; then
        aws_cmd+=(--dryrun)
    fi

    # move the file from local to s3
    "${aws_cmd[@]}" >>"$_TX_RESULTS_PATH" 2>>"$_TX_ERRORS_PATH"
    return $?
}


#######################################
# move_old_files(dirs)
#--------------------------------------
# 指定日以前のファイルを暗号化しS3に移動する
#
# GLOBALS:
#   COMMAND_NAME
#   MOVE_OLDER_THAN
#   MOVE_DATE_UNTIL
#   WORK_PATH
#   FILE_UNIQUNIZE
#   MOVE_ONE_BY_ONE
# ARGUMENTS:
#   $@: dirs - 処理対象ディレクトリのリスト(フルパス)
# OUTPUTS:
#   $WORK_PATH/move-files-$FILE_UNIQUNIZE.txt
#   に移動対象ファイルのパスを出力
#     パスは1行1ファイルをフルパスで出力。末尾は改行
#     アルファベット順にソートされている。
# RETURN:
#   常に 0
# REMARKS:
#   MOVE_ONE_BY_ONE の値でファイル移動方法を切り替える
#          0: 暗号済みファイルを一括でアップロード後、ローカルから一括削除する
#      0以外: 1ファイルずつ、暗号化-アップロード-ローカルから削除、を行う
#   ファイル移動処理で作成された中間ファイルは、処理終了時に削除する
#######################################
function move_old_files() {
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

    journal "## Start move files older than $MOVE_OLDER_THAN days(until $MOVE_DATE_UNTIL) to S3."

    # initialize stats.
    _SOURCE_COUNT=0
    _ENCRYPTED_COUNT=0
    _ENCRYPT_FAILED_COUNT=0
    _MOVED_COUNT=0
    _MOVE_FAILED_COUNT=0

    # 処理開始
    local move_list_file="$WORK_PATH/move-files-$FILE_UNIQUNIZE.txt"
    _find_move_files "$move_list_file" "$@"

    local method
	if [[ $MOVE_ONE_BY_ONE -ne 0 ]]; then
        # one by one move
        method="move"
		_move_files_to_s3_one_by_one "$move_list_file"
	else 
        # bulk move
        method="sync"
	    _encrypt_move_files "$move_list_file"
	    if [[ $_ENCRYPTED_COUNT -ne 0 ]]; then
	        _move_encrypted_files_to_s3 "$move_list_file"
	    fi
        # 送信元ファイル(暗号化ファイル)をすべて削除する
        # 誤ってルートパス '/' から削除されることが無いように、
        # シェル変数の展開を強制するために :? を付与する。
        rm -rf "${TX_BUFFER_PATH:?}/"*
	fi

    journal "## End of move files to S3."

    # 結果出力
    journal "target source files: $_SOURCE_COUNT"
    journal "moved files: $_MOVED_COUNT"
    journal "move failed: $_MOVE_FAILED_COUNT"
    local remaining_files=$((_SOURCE_COUNT - _MOVED_COUNT - _MOVE_FAILED_COUNT))
    journal "remaining: $remaining_files"

    if [[ $remaining_files -eq 0 ]]; then
        # 移動対象ファイルは全て処理された
        if [[ $_MOVED_COUNT -eq $_SOURCE_COUNT ]]; then
            if [[ $_MOVED_COUNT -eq 0 ]]; then
                journal "no files moved."
            else
                journal "all files moved successfully."
            fi
        else
            journal_err "ERROR: failed to move $_MOVE_FAILED_COUNT files."
            journal_err "ERROR: check results on journal for error details: $JOURNAL_PATH"
            _results_to_journal "$move_list_file" "$_TX_RESULTS_PATH" "$_TX_ERRORS_PATH" "$method"
        fi
    else
        # ファイル数が合わない： 対象ファイルすべてが処理されなかった可能性
        journal_err "ERROR: something wrong happened for moving files to s3." journal_err "ERROR: check results on journal for error details: $JOURNAL_PATH"
        _results_to_journal "$move_list_file" "$_TX_RESULTS_PATH" "$_TX_ERRORS_PATH" "$method"
    fi
    
    # 一時ファイルを削除する
    KEEP_TEMP_FILES=${KEEP_TEMP_FILES:-0}
    if [[ $KEEP_TEMP_FILES -eq 0 ]]; then
        if [[ -f $move_list_file ]]; then
            rm "$move_list_file" 1>&2
        fi
        if [[ -f $_TX_RESULTS_PATH ]]; then
            rm "$_TX_RESULTS_PATH" 1>&2
        fi
        if [[ -f $_TX_ERRORS_PATH ]]; then
            rm "$_TX_ERRORS_PATH" 1>&2
        fi
    fi

    return 0
}

#######################################
# -- 開発時の簡易動作確認
#
#   1. move_old_files 関数の動作確認
#
# ARGUMENTS:
#   $1: 処理対象ディレクトリ
#   $2: 対象ファイルパターン 'file1*,file2*'
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "move_to_s3.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/error_trap.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/app.sh"

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
    function journal_raw() {
        journal "$*"
    }

    # set variables
    MOVE_OLDER_THAN=${MOVE_OLDER_THAN:-30}
    MOVE_DATE_UNTIL=$(date --date="$((MOVE_OLDER_THAN + 1)) days ago" +%Y-%m-%d)
    NON_RECURSIVE=${NON_RECURSIVE:-0}
    DRYRUN=${DRYRUN:-0}

    # target directory
    dir=${1:-}

    # include file patterns
    INCLUDE_PATTERNS=${2:-}
    if [[ -n $ptns ]]; then
        # shellcheck disable=SC2206
        IFS="," read -ra ptns <<< "$INCLUDE_PATTERNS"
    fi

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
    fi

    TX_BUFFER_PATH=$WORK_PATH/$MYHOSTNAME
    readonly TX_BUFFER_PATH

    move_old_files "$src_path"

fi

#EOS
