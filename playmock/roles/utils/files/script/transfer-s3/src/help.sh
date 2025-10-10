#!/usr/bin/env bash
# help.sh
# transfer-s3: Show help text

#######################################
# help()
#--------------------------------------
# ヘルプを表示する
#
# GLOBALS:
#   COMMAND_NAME
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT に出力
# RETURN:
#   常に 0
#######################################
function help() {
    echo ""
    echo "$COMMAND_NAME - A tool that compresses files and moves them to S3 for backup to prevent storage exhaustion."
    echo ""
    echo "Usage: $COMMAND_NAME [OPTIONS...] <s3_bucket_name> <backup_source_directory> [backup_source_directory...]"
    echo ""
    echo "  This tool has two main functions."
    echo ""
    echo "  Compression - Compress old files under <backup_source_directory> recursively (this behavior "
    echo "                can be overridden with --non-recuresive option). Also you can specified two or "
    echo "                more backup_source_directories."
    echo "                Compressed file will have extension *.gz and the original file will be deleted."
    echo ""
    echo "   Move to S3 - Move the compressed old files to S3 storage and make a journal file each processed."
    echo "                You can easily restore the backup file from S3 storage with the aws-cli command line"
    echo "                recorded in the journal file."
    echo ""
    echo "OPTIONS:"
    echo "  -1 | --one-by-one               : Move files to S3 one by one. It consumes less storage but takes more time."
    echo "                                    This option helps you move old files to S3 to free up storage space prior to "
    echo "                                    regular backup operations. Regular backups usually work more efficiently "
    echo "                                    without this option."
    echo "  -g | --gzip-older-than <days>   : The target files to be compressed are based on the last modified date. Uses "
    echo "                                    30 days if not specified."
    echo "  -i | --include '<patterns>'     : Include only files that match the specified patterns for backup."
    echo "                                    you can specified multiple pattenrs separeted commas."
    echo "                                    ex) --include='source*,message*'"
    echo "                                    also you can include wildcard characters ('*' and '?') to patterns."
    echo "  -j | --journal-id '<journal_id>': Append journal_id to journal filename."
    echo "                                    This option is required to make journal filenames unique when performing"
    echo "                                    multiple backup operations on one host."
    echo "  -m | --move-older-than <days>   : The target files to move to S3 are based on the last modified date of the "
    echo "                                    files before compressed. Uses 90 days if not specified."
    echo "                                    The days value must always be greater than or equal to --gzip-older-than days."
    echo "  -n | --non-recursive            : The backed-up files are only the files directly under the specified backup "
    echo "                                    source directory. sub directories are not included."
    echo "  -p | --profile <profile_name>   : A profile name for aws-cli tool environment. Uses 'default' if not specified."
    echo "  -R | --dry-run                  : Dry run mode is enabled. It doesn't actually compress or move files."
    echo "  -v | --verbose                  : Increse verbosity of console output."
    echo "                                    If not specified, the processing information for each file will not be output"
    echo "                                    to the console. However, this option does not affect to the journal,"
    echo "                                    processing informations are output to journal always."
    echo "  -h | --help                     : Display this help."
    echo "  -V | --version                  : Display the version number."
    echo ""

    return 0
}

#######################################
# usage()
#--------------------------------------
# 使用方法(簡易ヘルプ)の出力
#
# GLOBALS:
#   COMMAND_NAME
# ARGUMENTS:
#   なし
# OUTPUTS:
#   STDOUT に出力
# RETURN:
#   常に 0
#######################################
function usage {
    echo ""
    echo "Usage: $COMMAND_NAME [OPTIONS...] <s3_bucket_name> <backup_source_directory> [backup_source_directory...]"
    echo ""
    echo "[OPTIONS...]"
    echo "-1 | --one-by-one"
    echo "-g | --gzip-older-than <days>"
    echo "-i | --include '<patterns>'"
    echo "-j | --journal-id '<journal_id>'"
    echo "-m | --move-older-than <days>"
    echo "-n | --non-recursive"
    echo "-p | --profile <profile_name>"
    echo "-R | --dry-run"
    echo "-v | --verbose"
    echo "-h | --help"
    echo "-V | --version"

    return 0
}


#######################################
# -- 開発時の簡易動作確認
#
#   1. help 関数の動作確認
#
# ARGUMENTS:
#   なし
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "help.sh" ]]; then
    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"

    echo "--------------- show help"
    help

    echo "--------------- show usage"
    usage
fi

#EOS
