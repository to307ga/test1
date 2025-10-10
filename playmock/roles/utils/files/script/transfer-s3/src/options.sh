#!/usr/bin/env bash
# options.sh
# transfer-s3: Analyse and validate options and arguments.

#######################################
# options()
#--------------------------------------
# オプションの解析と設定値反映
#
# GLOBALS:
#   COMMAND_NAME
# ARGUMENTS:
#   $@: 引数列
# OUTPUTS:
#   AWS_PROFILE
#   AWS_S3_BUCKET
#   MOVE_OLDER_THAN
#   DRYRUN
#   GZIP_OLDER_THAN
#   INCLUDE_PATTERNS
#   JOURNAL_ID
#   NON_RECURSIVE
#   S3_UPLOAD_PATH
#   SOURCE_DIRS
#   VERBOSE
# RETURN:
#   正常時 0
#   ヘルプ、バージョン表示時 1 で終了
#   不正オプション時 2 で終了
#######################################
function options() {
    local parsed
    parsed=$(getopt -o p:g:m:i:j:hRn1vV -n "$COMMAND_NAME" -l 'profile:,gzip-older-than:,move-older-than:,include:,journal-id:,help,dry-run,non-recursive,one-by-one,verbose,version' -- "$@")
    local valid=$?
    if [ $valid -ne 0 ]; then
        usage
        exit 1
    fi

    eval set -- "$parsed"
    while :; do
        case "$1" in
        -p | --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -g | --gzip-older-than)
            GZIP_OLDER_THAN="$2"
            shift 2
            ;;
        -m | --move-older-than)
            MOVE_OLDER_THAN="$2"
            shift 2
            ;;
        -R | --dry-run)
            DRYRUN=1
            shift
            ;;
        -h | --help)
            help
            exit 1
            ;;
        -v | --verbose)
            VERBOSE=1
            shift
            ;;
        -V | --version)
            version
            exit 1
            ;;
        -i | --include)
            INCLUDE_PATTERNS="$2"
            shift 2
            ;;
        -n | --non-recursive)
            NON_RECURSIVE=1
            shift
            ;;
        -1 | --one-by-one)
            MOVE_ONE_BY_ONE=1
            shift
            ;;
        -j | --journal-id)
            JOURNAL_ID="$2"
            shift 2
            ;;
        # -- means the end of the arguments; drop this, and break out of the while loop
        --)
            shift
            break
            ;;
        # If invalid options were passed, then getopt should have reported an error,
        # which we checked as VALID_ARGUMENTS when getopt was called...
        *)
            echo "$COMMAND_NAME: Unexpected option: $1 - this should not happen."
            usage
            exit 1
            ;;
        esac
    done

    # arg 1 - s3_bucket_name
    AWS_S3_BUCKET=${1:-}
    if [[ -z "$AWS_S3_BUCKET" ]]; then
        echo "$COMMAND_NAME: No S3 bucket name specified." >&2
        usage
        exit 1
    fi
    shift
    S3_UPLOAD_PATH="s3://$AWS_S3_BUCKET/$MYHOSTNAME"
    readonly S3_UPLOAD_PATH

    # arg 2... - backup_source_directories
    IFS=" " read -ra SOURCE_DIRS <<< "${@}"

    if [[ 0 -eq ${#SOURCE_DIRS[@]} ]]; then
        echo "$COMMAND_NAME: No backup source directory specified." >&2
        usage
        exit 1
    fi

    # Parameter validation.
    local has_err=0

    # s3_bucket_name cannot contain the path separator '/'
    if [[ $AWS_S3_BUCKET = */* ]]; then
        echo "$COMMAND_NAME: s3_bucket_name cannot contain the path separator '/'" >&2
        has_err=1
    fi

    # source directories must exist.
    for dir in "${SOURCE_DIRS[@]}"; do
        if [[ ! -e $dir ]]; then
            echo "$COMMAND_NAME: backup source directory '$dir' is not exist." >&2
            has_err=1
        elif [[ ! -d $dir ]]; then
            echo "$COMMAND_NAME: backup source directory '$dir' is not a directory." >&2
            has_err=1
        fi
    done

    # AWS_PROFILE <name>: nullable | string | min:1
    if [[ -z $AWS_PROFILE ]]; then
        echo "$COMMAND_NAME: -p|--profile <name>: profile name does not specified." >&2
        has_err=1
    fi

    # GZIP_OLDER_THAN <days>: nullable | numeric | min:1
    # MOVE_OLDER_THAN <days>: nullable | numeric | min:$GZIP_OLDER_THAN
    local valid_days=1
    if [[ ! "$GZIP_OLDER_THAN" =~ ^[0-9]+$ ]]; then
        echo "$COMMAND_NAME: -g|--gzip-older-than <days>: specified days is not a number." >&2
        valid_days=0
        has_err=1
    fi
    if [[ ! "$MOVE_OLDER_THAN" =~ ^[0-9]+$ ]]; then
        echo "$COMMAND_NAME: -m|--move-older-than <days>: specified days is not a number." >&2
        valid_days=0
        has_err=1
    fi
    if [[ $valid_days -ne 0 ]]; then
        if ((GZIP_OLDER_THAN < 1)); then
            echo "$COMMAND_NAME: -g|--gzip-older-than <days>: days must be greater than or equals 1." >&2
            has_err=1
        fi
        if ((MOVE_OLDER_THAN < GZIP_OLDER_THAN)); then
            echo "$COMMAND_NAME: -m|--move-older-than <days>: days must be greater than or equals $GZIP_OLDER_THAN." >&2
            has_err=1
        fi
    fi

    # INCLUDE_PATTERNS must not include '/' as path separator character.
    if [[ "$INCLUDE_PATTERNS" = */* ]]; then
        echo "$COMMAND_NAME: -i|--include <patterns>: patterns cannnot contain the path separator '/'." >&2
        has_err=1
    fi
    

    if [[ $has_err -ne 0 ]]; then
        exit 2 # validation error has occured.
    fi
}

#######################################
# -- 開発時の簡易動作確認
#
#   1. options 関数の動作確認
#
# ARGUMENTS:
#   $@: transfer-s3.sh と同じ引数
#######################################
COMMAND_NAME=${COMMAND_NAME:-$(basename "$0")}
COMMAND_PATH=${COMMAND_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}
if [[ $COMMAND_NAME == "options.sh" ]]; then

    # Fail on unset variables and command errors
    set -ue -o pipefail
    # Prevent commands misbehaving due to locale differences
    export LC_ALL=C

    # Load constants
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/constants.sh"

    # Set up default values.
    AWS_PROFILE=${AWS_PROFILE:-"$DEF_AWS_PROFILE"}
    GZIP_OLDER_THAN=${GZIP_OLDER_THAN:-$DEF_GZIP_OLDER_THAN}
    MOVE_OLDER_THAN=${MOVE_OLDER_THAN:-$DEF_MOVE_OLDER_THAN}
    DRYRUN=${DRYRUN:-$DEF_DRYRUN}
    VERBOSE=${VERBOSE:-$DEF_VERBOSE}
    INCLUDE_PATTERNS=${INCLUDE_PATTERNS:-$DEF_INCLUDE_PATTERNS}
    NON_RECURSIVE=${NON_RECURSIVE:-$DEF_NON_RECURSIVE}
    MOVE_ONE_BY_ONE=${MOVE_ONE_BY_ONE:-$DEF_MOVE_ONE_BY_ONE}
    JOURNAL_ID=${JOURNAL_ID:-$DEF_JOURNAL_ID}

    # Load sub scripts.
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/help.sh"
    # shellcheck disable=SC1091
    . "$COMMAND_PATH/version.sh"
    
    # other variables setting
    MYHOSTNAME=$(hostname -s)

    options "$@"

    # echo "parameters -> '$*'"
    echo "AWS_PROFILE='$AWS_PROFILE'"
    echo "GZIP_OLDER_THAN=$GZIP_OLDER_THAN"
    echo "MOVE_OLDER_THAN=$MOVE_OLDER_THAN"
    echo "DRYRUN=$DRYRUN"
    echo "VERBOSE=$VERBOSE"
    echo "NON_RECURSIVE=$NON_RECURSIVE"
    echo "MOVE_ONE_BY_ONE=$MOVE_ONE_BY_ONE"
    echo "AWS_S3_BUCKET=$AWS_S3_BUCKET"
    echo "S3_UPLOAD_PATH='$S3_UPLOAD_PATH'"
    echo "JOURNAL_ID='$JOURNAL_ID'"

    echo "INCLUDE_PATTERNS='$INCLUDE_PATTERNS'"


    cnt=1
    for dir in "${SOURCE_DIRS[@]}"; do
        echo "SOURCE_DIRS[$cnt]='$dir'"
        cnt=$(( cnt + 1 ))
    done
fi

#EOS
