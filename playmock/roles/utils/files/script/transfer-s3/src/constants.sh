#!/usr/bin/env bash
# constants.sh
# transfer-s3: Constant value definitions.

__CONSTANTS_SH=${__CONSTANTS_SH:-0}
if [[ $__CONSTANTS_SH -eq 0 ]]; then
    export __CONSTANTS_SH=1

    # version number
    readonly COMMAND_VERSION="Version 0.1.3"
    export COMMAND_VERSION

    # runnable user
    # バックアップ元ディレクトリに対する読み書き権限を持つユーザを指定してください。
    # 適切な権限を持つバックアップユーザが存在しない環境では root を指定してください。
    # 実行ユーザで aws コマンドを実行しファイルを S3 に転送する仕組みであるため、
    # 認証情報等は事前に実行ユーザの `default` プロファイルに設定する必要があります。
    # （`aws configure` 実行時にプロファイル名を指定しなければ default プロファイルが
    # 作成されます。 登録済みプロファイル名は `aws configure list-profiles` で確認
    # できます）
    readonly RUNNABLE_USER="root"
    export RUNNABLE_USER

    # crypt key owner.
    # 暗号化に使用するSSH鍵を持つユーザを指定してください。
    # 例えば $USER とすると実行時ユーザの鍵を使用します。
    readonly CRYPT_KEY_OWNER="gooscp"
    export CRYPT_KEY_OWNER

    #
    ## default value definitions.
    #

    # aws-cli tools profile name
    readonly DEF_AWS_PROFILE="default"
    export DEF_AWS_PROFILE

    # Number of days since the last update date of the file to be gzip compressed.
    readonly DEF_GZIP_OLDER_THAN=30
    export DEF_GZIP_OLDER_THAN

    # Number of days since the last update date of the file to be move to S3 and deleted.
    readonly DEF_MOVE_OLDER_THAN=90
    export DEF_MOVE_OLDER_THAN

    # Dry Running(1) or not(0).
    readonly DEF_DRYRUN=0
    export DEF_DRYRUN

    # Console output verbosity
    readonly DEF_VERBOSE=0
    export DEF_VERBOSE

    # S3 traffic bandwidth
    readonly DEF_S3_BANDWIDTH="1Mb/s"
    export DEF_S3_BANDWIDTH

    # Patterns for backup target file name.
    readonly DEF_INCLUDE_PATTERNS=""
    export DEF_INCLUDE_PATTERNS

    # Find the backup target files from directory non recursively.
    readonly DEF_NON_RECURSIVE=0
    export DEF_NON_RECURSIVE

    # Find the backup target files from symlinked directory or not.
    readonly DEF_FOLLOW_SYMLINK=1
    export DEF_FOLLOW_SYMLINK

    # Move the backup target files one by one.
    readonly DEF_MOVE_ONE_BY_ONE=0
    export DEF_MOVE_ONE_BY_ONE

    # Journal id allows the filenames to be unique.
    readonly DEF_JOURNAL_ID=""
    export DEF_JOURNAL_ID

    #
    ## constant values.
    #

    # date format - "2023-05-10"
    readonly FMT_DATE="%Y-%m-%d"
    export FMT_DATE

    # date format for file - "20230510"
    readonly FMT_FILE_DATE="%Y%m%d"
    export FMT_FILE_DATE

    # datetime format for file uniqunize - "20230510-123456-123456789"
    readonly FMT_FILE_UNIQUNIZE="%Y%m%d-%H%M%S-%N"
    export FMT_FILE_UNIQUNIZE

    # datetime format - "2023-05-10 12:34:56"
    readonly FMT_DATETIME="%Y-%m-%d %H:%M:%S"
    export FMT_DATETIME

    # datetime format for journal - "2023-05-10 12:34:56.123456789"
    readonly FMT_JNL_DATETIME="%Y-%m-%d %H:%M:%S.%N"
    export FMT_JNL_DATETIME

    # ONE-BY-ONE ファイル移動処理中に処理を中断するエラー発生上限値
    readonly MOVE_ERROR_LIMIT=10
    export MOVE_ERROR_LIMIT

    #
    ## exit(error) code
    #

    readonly EXIT_UNEXPECTED_ERR=255
    export EXIT_UNEXPECTED_ERR

    readonly EXIT_INTERNAL_ERR=250
    export EXIT_INTERNAL_ERR

    readonly EXIT_BAD_ENVIRONMENT=2
    export EXIT_BAD_ENVIRONMENT

    readonly EXIT_UNPROCESSED=1
    export EXIT_UNPROCESSED

fi

#EOS
