#!/usr/bin/env bash
# -- actualtest.sh
#
# 実環境上のテスト
# aws コマンドと有効な S3 プロファイルを使用し、 
# テスト用バケットに対してバックアップを実行する
#
# usage:
#   actualtest.sh
#

TEST_BASE=~/projects/transfer-s3

TRANSFER_S3="${TEST_BASE}/script/transfer-s3.sh"
TESTDATA_BASE="${TEST_BASE}/testdata"
BACKUP_SOURCE="${TESTDATA_BASE}/data1"

BUCKET=backup-gooid-idhub-dev

HOSTNAME=$(hostname -s)

shift
OPTIONS=( "$@" )

# prepare the backup soruce dirctory.
rm -rf "${BACKUP_SOURCE}"
cp -a "$TESTDATA_BASE/orgdata" "${BACKUP_SOURCE}"

# set the date so that all files are targets for backup.
TODAY=$(date +%Y-%m-%d)
date_op_str="$TODAY 2 days ago"
touch_date=$(date --date="$date_op_str" "+%Y-%m-%d")
find "$BACKUP_SOURCE" -name ".*" -prune -o \( -print -exec touch --date="$touch_date" {} + \)

# delete s3 directory before backup.
aws s3 rm --recursive "s3://${BUCKET}/${HOSTNAME}${BACKUP_SOURCE}"

# run transfer-s3
cmd=("${TRANSFER_S3}" --gzip-older-than=1 --move-older-than=1 --verbose "${OPTIONS[@]}" "${BUCKET}" "${BACKUP_SOURCE}")

echo "${cmd[*]}"
sudo "${cmd[@]}"

# EOS
