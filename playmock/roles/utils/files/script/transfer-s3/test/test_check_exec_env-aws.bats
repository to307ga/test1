#!/usr/bin/env bats

# test_check_exec_env-aws.bats
#
# target functions
#   exists_aws_cli()
#   exists_aws_profile()
#   exists_aws_bandwidth_restrictions()
#
# テスト環境に実コマンドがインストールされていない場合、
# 実コマンドに依存するテストはスキップする。
# なお、機能テストとして外部コマンドをモックしたテストも含んでいるため
# 実コマンドがなくとも機能的なテストは十分実施されるようテストケースを
# 作成した。
#

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    # load 'test_helper/bats-file/load'

    # テスト対象のパス '../src' を一時的に PATH に追加することで、
    # 'run テストスクリプト' でパス指定を不要にする。
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    PATH="$DIR/../src:$PATH"

    # 実コマンドをモックして関数をテストするためにここでロードする
    # 注意）関数以外の記述はここで実行されてしまうため、スクリプト
    #       自体のテストでモックすることはできないと考えた方が良い。
    COMMAND_PATH=$(cd "$DIR/../src" && pwd)
    load "$COMMAND_PATH/check_exec_env.sh"
    COMMAND_NAME=$(basename $BATS_TEST_FILENAME .bats)

    # テスト用定数定義
    # 注意）constants.sh にてデフォルト値が変更になった場合、
    #       この設定も変更すること。
    #       アプリケーションの定数定義を参照するために constants.sh 等をテストに
    #       load してはイケない。なぜなら不適切な変更をテストで見つけることができ
    #       なくなるからである。テストコード保守のめんどくささも時には役に立つ。
    ProfileName="test-transfer-s3"
    # その他テスト共通の初期値
    CryptKeyOwner="$USER"
    # 期待するバンド幅の値
    Bandwidth="1Mb/s"

    # constant 定義名にマップする
    DEF_S3_BANDWIDTH=$Bandwidth
    CRYPT_KEY_OWNER="$CryptKeyOwner"

    # option 変数にマップする
    AWS_PROFILE=$ProfileName


    # stub for journal.sh
    function journal() {
        echo "$*"
    }
    function journal_err() {
        echo "$*"
    }
    # stub for error_trap.sh
    function raise() {
        journal_err "$1"

        set -e # force enable errexit.
        local code=${2:-250}
        # return "$code"  # なぜか set -e が効かず return 0以外 でも raise の次に
        exit 250          # ステップしてしまうので強制終了する
    }

    # #######################################
    # # aws()
    # #--------------------------------------
    # # aws コマンドのスタブ例
    # #
    # # GLOBALS:
    # #   DEF_AWS_PROFILE
    # #   DEF_S3_BANDWIDTH
    # # ARGUMENTS:
    # #   aws コマンド引数
    # # OUTPUTS:
    # #   aws コマンド引数に応じた出力を STDOUT に書き込む
    # # RETURN:
    # #   0: 想定したコマンド引数に対する出力を行った
    # # 255: 想定したコマンド引数を受け取らなかった
    # #######################################
    # aws() {
    #     if [[ ${*} == "--version" ]]; then
    #         echo "Version 123"
    #         return 0
    #     elif [[ ${*} == "configure get profile.$DEF_AWS_PROFILE.s3.max_bandwidth" ]]; then
    #         echo "$DEF_S3_BANDWIDTH"
    #         return 0
    #     elif [[ ${*} == "configure list-profiles" ]]; then
    #         echo "profile-A"
    #         echo "default"
    #         echo "profile-C"
    #         return 0
    #     else
    #         echo "stub aws(): unexpected argument present($*)." >&2
    #         return 255
    #     fi
    # }
    # #--------- mock the aws command

}

# exists_aws_cli 関数は正常時に以下の関数チェーンを実行するため、このテストでは
# 逆順に正常性を確認する。
#   exists_aws_cli -> exists_aws_profile -> exists_aws_bandwidth_restrictions

#
# function exists_aws_bandwidth_restrictions test
#

# bats test_tags=normal, bandwidth
@test "[001][abnormal][------] exists_aws_bandwidth_restrictions with no profile name" {
    # mock the aws command
    aws() {
        if [[ ${*} == "configure get profile.$ProfileName.s3.max_bandwidth" ]]; then
            echo "# TEST: プロファイル指定 '$ProfileName' が無いのにバンド幅設定値を取得しようとしている" >&3
            return 255
        elif [[ ${*} == "configure set profile.$ProfileName.s3.max_bandwidth $Bandwidth" ]]; then
            echo "# TEST: バンド幅設定値を取得できたのに更に設定しようとしている" >&3
            return 255
        else
            # Batsテスト中のコンソール出力は '"# メッセージ" >&3' で可能です。
            # @see https://bats-core.readthedocs.io/en/stable/writing-tests.html#printing-to-the-terminal
            echo "# TEST: aws configure command が期待値と異なる。" >&3
            echo "# 期待値：'configure get profile.default.s3.max_bandwidth'" >&3
            echo "# 実際の値： $*" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_bandwidth_restrictions
    assert_failure 250
    EXPECTED="$COMMAND_NAME: exists_aws_bandwidth_restrictions(): A profile name must be specified as argument 1"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, mock, bandwidth
@test "[002][ normal ][ mock ] exists_aws_bandwidth_restrictions configured with max_bandwidth" {
    # mock the aws command
    aws() {
        if [[ ${*} == "configure get profile.$ProfileName.s3.max_bandwidth" ]]; then
            echo "$Bandwidth"
            return 0
        elif [[ ${*} == "configure set profile.$ProfileName.s3.max_bandwidth 1Mb/s" ]]; then
            echo "# TEST: バンド幅設定値を取得できたのに更に設定しようとしている" >&3
            return 255
        else
            echo "# TEST: aws configure command が期待値と異なる。" >&3
            echo "# 期待値：'configure get profile.$ProfileName.s3.max_bandwidth' " >&3
            echo "# 　　　：'configure set profile.$ProfileName.s3.max_bandwidth 1Mb/s'" >&3
            echo "# 実際の値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_bandwidth_restrictions "$ProfileName"
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=abnormal, mock, bandwidth
@test "[003][abnormal][ mock ] exists_aws_bandwidth_restrictions configured with max_bandwidth but failed to set" {
    # mock the aws command
    aws() {
        if [[ ${*} == "configure get profile.$ProfileName.s3.max_bandwidth" ]]; then
            return 1 # バンド幅未設定
        elif [[ ${*} == "configure set profile.$ProfileName.s3.max_bandwidth 1Mb/s" ]]; then
            # バンド幅設定でエラー発生
            return 255
        else
            echo "# TEST: aws configure command が期待値と異なる。" >&3
            echo "# 期待値：'configure get profile.$ProfileName.s3.max_bandwidth' " >&3
            echo "# 　　　：'configure set profile.$ProfileName.s3.max_bandwidth 1Mb/s'" >&3
            echo "# 実際の値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_bandwidth_restrictions "$ProfileName"
    assert_failure 250
    EXPECTED_1="WARNING: a S3 max_bandwidth is not configured on your profile named '$ProfileName'."
    EXPECTED_2="$COMMAND_NAME: aws S3 max_bandwidth configuration failed with code 255. Please check the following aws command line and exit code. 'aws configure set profile.test-transfer-s3.s3.max_bandwidth 1Mb/s'."
    assert_output --partial "$EXPECTED_1"
    assert_output --partial "$EXPECTED_2"
}

# bats test_tags=normal, mock, bandwidth
@test "[004][ normal ][ mock ] exists_aws_bandwidth_restrictions configured with no max_bandwidth" {
    # mock the aws command
    aws() {
        if [[ ${*} == "configure get profile.$ProfileName.s3.max_bandwidth" ]]; then
            return 1 # not configured.
        elif [[ ${*} == "configure set profile.$ProfileName.s3.max_bandwidth 1Mb/s" ]]; then
            return 0 # configuration successful.
        else
            echo "# TEST: aws configure command が期待値と異なる。" >&3
            echo "# 期待値：'configure get profile.$ProfileName.s3.max_bandwidth'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_bandwidth_restrictions "$ProfileName"
    assert_success

    EXPECTED_1="WARNING: a S3 max_bandwidth is not configured on your profile named '$ProfileName'."
    EXPECTED_2="You have successfully configured profile '$ProfileName'."
    EXPECTED_3="Set S3 max_bandwidth to '$Bandwidth'."
    assert_output --partial "$EXPECTED_1"
    assert_output --partial "$EXPECTED_2"
    assert_output --partial "$EXPECTED_3"
}

# bats test_tags=normal, mock, bandwidth
@test "[005][ normal ][ mock ] exists_aws_bandwidth_restrictions configured with blank max_bandwidth" {
    # mock the aws command
    aws() {
        if [[ ${*} == "configure get profile.$ProfileName.s3.max_bandwidth" ]]; then
            echo "" # blank max_bandwidth
            return 0
        elif [[ ${*} == "configure set profile.$ProfileName.s3.max_bandwidth 1Mb/s" ]]; then
            return 0 # configuration successful.
        else
            echo "# aws configure command が期待値と異なる。" >&3
            echo "# 期待値：'configure get profile.$ProfileName.s3.max_bandwidth'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_bandwidth_restrictions "$ProfileName"
    assert_success

    EXPECTED_1="WARNING: a S3 max_bandwidth is not configured on your profile named '$ProfileName'."
    EXPECTED_2="You have successfully configured profile '$ProfileName'."
    EXPECTED_3="Set S3 max_bandwidth to '$Bandwidth'."
    assert_output --partial "$EXPECTED_1"
    assert_output --partial "$EXPECTED_2"
    assert_output --partial "$EXPECTED_3"
}

# bats test_tags=normal, actual
@test "[006][ normal ][actual] exists_aws_bandwidth_restrictions configured with max_bandwidth" {
    if ! aws --version ; then
        skip "because the test depends on the actual command."
    fi

    # setting max_bandwidth before testing.
    (aws configure set profile.$ProfileName.s3.max_bandwidth $Bandwidth)

    # do the test
    run exists_aws_bandwidth_restrictions "$ProfileName"
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, actual
@test "[007][ normal ][actual] exists_aws_bandwidth_restrictions configured with no max_bandwidth" {
    if ! aws --version ; then
        skip "because the test depends on the actual command."
    fi

    # clear max_bandwidth before testing.
    (aws configure set profile.$ProfileName.s3.max_bandwidth "")

    # do the test
    run exists_aws_bandwidth_restrictions "$ProfileName"
    assert_success

    EXPECTED_1="WARNING: a S3 max_bandwidth is not configured on your profile named '$ProfileName'."
    EXPECTED_2="You have successfully configured profile '$ProfileName'."
    EXPECTED_3="Set S3 max_bandwidth to '$Bandwidth'."
    assert_output --partial "$EXPECTED_1"
    assert_output --partial "$EXPECTED_2"
    assert_output --partial "$EXPECTED_3"
}

#
# function exists_aws_profile test
#

# bats test_tags=abnormal, profile
@test "[008][abnormal][------] exists_aws_profile with no profile name" {
    # do the test
    run exists_aws_profile
    assert_failure 250
    EXPECTED="$COMMAND_NAME: exists_aws_profile(): A profile name must be specified as argument 1"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, mock
@test "[009][ normal ][ mock ] exists_aws_profile there is matching profile name in the single-line profile list" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "use S3 max_bandwidth: '$Bandwidth'"
        return 0
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "configure list-profiles" ]]; then
            echo "$ProfileName"
            return 0
        else
            echo "# exists_aws_profile の引数が期待値と異なる。" >&3
            echo "# 期待値：'configure list-profiles'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_profile $ProfileName
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, mock, profile
@test "[010][ normal ][ mock ] exists_aws_profile there is matching profile name at the end of the 3-line profile list" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "use S3 max_bandwidth: '$Bandwidth'"
        return 0
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "configure list-profiles" ]]; then
            echo "profile-A"
            echo "profile-B"
            echo "$ProfileName"
            return 0
        else
            echo "# exists_aws_profile の引数が期待値と異なる。" >&3
            echo "# 期待値：'configure list-profiles'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_profile $ProfileName
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=abnormal, mock, profile
@test "[011][abnormal][ mock ] exists_aws_profile there is no profile list." {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "# 想定外に exists_aws_bandwidth_restrictions が呼ばれた" >&3
        return 255
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "configure list-profiles" ]]; then
            return 0
        else
            echo "# exists_aws_profile の引数が期待値と異なる。" >&3
            echo "# 期待値：'configure list-profiles'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_profile $ProfileName
    assert_success
    # assert_equal $HAS_ERRORS 1
    EXPECTED="$COMMAND_NAME: There is no profile for aws-cli named '$ProfileName' owned by user $CRYPT_KEY_OWNER."
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, mock, profile
@test "[012][abnormal][ mock ] exists_aws_profile there is no matching profile name in the 3-line profile list" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "# 想定外に exists_aws_bandwidth_restrictions が呼ばれた" >&3
        return 255
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "configure list-profiles" ]]; then
            echo "profile-A"
            echo "profile-B"
            echo "profile-C"
            return 0
        else
            echo "# exists_aws_profile の引数が期待値と異なる。" >&3
            echo "# 期待値：'configure list-profiles'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_profile $ProfileName
    assert_success
    # assert_equal $HAS_ERRORS 1
    EXPECTED="$COMMAND_NAME: There is no profile for aws-cli named '$ProfileName' owned by user $CRYPT_KEY_OWNER."
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, actual, profile
@test "[013][ normal ][actual] exists_aws_profile there is matching profile name in the profile list" {
    if ! aws --version ; then
        skip "because the test depends on the actual command."
    fi

    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "use S3 max_bandwidth: '$Bandwidth'"
        return 0
    }

    # do the test
    run exists_aws_profile $ProfileName
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

#
# function exists_aws_cli test
#

# bats test_tags=normal, mock, aws
@test "[014][ normal ][ mock ] exists_aws_cli there is aws_cli" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "use S3 max_bandwidth: '$Bandwidth'"
        return 0
    }
    # mock the exists_aws_profile
    exists_aws_profile() {
        exists_aws_bandwidth_restrictions "$@"
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "--version" ]]; then
            echo "(Bats)aws-cli/2.11.0 Python/3.11.2 Linux/3.10.0-1160.45.1.el7.x86_64 exe/x86_64.centos.7 prompt/off"
            return 0
        else
            echo "# exists_aws_cli の引数が期待値と異なる。" >&3
            echo "# 期待値：'--version'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_cli
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=abnormal, mock, aws
@test "[015][abnormal][ mock ] exists_aws_cli there is no aws" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "# 想定外に exists_aws_bandwidth_restrictions が呼ばれた" >&3
        return 255
    }
    # mock the exists_aws_profile
    exists_aws_profile() {
        echo "# 想定外に exists_aws_profile が呼ばれた" >&3
        return 255
    }
    # mock the aws command
    aws() {
        return 255
    }

    # do the test
    run exists_aws_cli
    assert_success
    # assert_equal $HAS_ERRORS 1
    EXPECTED="$COMMAND_NAME: aws command is required."
    assert_output --partial "$EXPECTED"
}

# bats test_tags=normal, actual, aws
@test "[016][ normal ][actual] exists_aws_cli there is aws" {
    if ! aws --version ; then
        skip "because the test depends on the actual command."
    fi

    # setting max_bandwidth before testing.
    (aws configure set profile.$ProfileName.s3.max_bandwidth $Bandwidth)

    # do the test
    run exists_aws_cli
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}


# bats test_tags=normal, mock, aws, version
@test "[017][ normal ][ mock ] your aws command has valid version" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "use S3 max_bandwidth: '$Bandwidth'"
        return 0
    }
    # mock the exists_aws_profile
    exists_aws_profile() {
        exists_aws_bandwidth_restrictions "$@"
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "--version" ]]; then
            echo "aws-cli/2.13.1 Python/3.11.4 Linux/5.15.90.1-microsoft-standard-WSL2 exe/x86_64.ubuntu.22 prompt/off"
            return 0
        else
            echo "# exists_aws_cli の引数が期待値と異なる。" >&3
            echo "# 期待値：'--version'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_cli
    assert_success
    EXPECTED="use S3 max_bandwidth: '$Bandwidth'"
    assert_output --partial "$EXPECTED"
}

# bats test_tags=abnormal, mock, aws, version
@test "[018][abnormal][ mock ] your aws command has not valid version" {
    # mock the exists_aws_bandwidth_restrictions function
    exists_aws_bandwidth_restrictions() {
        echo "use S3 max_bandwidth: '$Bandwidth'"
        return 0
    }
    # mock the exists_aws_profile
    exists_aws_profile() {
        exists_aws_bandwidth_restrictions "$@"
    }
    # mock the aws command
    aws() {
        if [[ ${*} == "--version" ]]; then
            echo "aws-cli/1.22.34 Python/3.10.6 Linux/5.15.90.1-microsoft-standard-WSL2 botocore/1.23.34"
            return 0
        else
            echo "# exists_aws_cli の引数が期待値と異なる。" >&3
            echo "# 期待値：'--version'" >&3
            echo "# 実際値：'$*'" >&3
            return 255
        fi
    }

    # do the test
    run exists_aws_cli
    assert_success
    assert_line "$COMMAND_NAME: aws command is required version 2.0 or later. version 1.22.34 found."
}


#EOS
