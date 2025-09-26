#!/bin/bash

# AWS MFA自動ログインスクリプト
# 使用方法: ./mfa_login.sh [MFAコード]

set -e

# 設定
MFA_DEVICE_ARN="arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd"
DURATION=43200  # 12時間

# MFAコードの取得
if [ -z "$1" ]; then
    echo -n "MFAコードを入力してください (6桁): "
    read MFA_CODE
else
    MFA_CODE="$1"
fi

# 入力検証
if [[ ! "$MFA_CODE" =~ ^[0-9]{6}$ ]]; then
    echo "エラー: MFAコードは6桁の数字である必要があります"
    exit 1
fi

echo "MFA認証を実行中..."

# 既存のセッション情報をクリア
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# 現在のプロファイル設定
export AWS_PROFILE=prod

# GetSessionToken実行
echo "AWS STS GetSessionToken を実行中..."
TEMP_CREDENTIALS=$(aws sts get-session-token \
    --duration-seconds $DURATION \
    --serial-number "$MFA_DEVICE_ARN" \
    --token-code "$MFA_CODE" \
    --no-verify-ssl 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "エラー: GetSessionToken が失敗しました"
    echo "MFAコードが正しいか確認してください"
    exit 1
fi

# JSON解析にjqが利用可能かチェック
if ! command -v jq &> /dev/null; then
    echo "警告: jqがインストールされていません。手動設定が必要です。"
    echo ""
    echo "以下のコマンドを実行してください:"
    echo "$TEMP_CREDENTIALS"
    exit 1
fi

# 環境変数設定
echo "環境変数を設定中..."
export AWS_ACCESS_KEY_ID=$(echo "$TEMP_CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$TEMP_CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$TEMP_CREDENTIALS" | jq -r '.Credentials.SessionToken')
EXPIRATION=$(echo "$TEMP_CREDENTIALS" | jq -r '.Credentials.Expiration')
unset AWS_PROFILE

# 結果出力
echo "✅ MFA認証成功！"
echo "有効期限: $EXPIRATION"
echo ""
echo "現在のターミナルで以下の環境変数が設定されました:"
echo "  AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "  AWS_SECRET_ACCESS_KEY=(設定済み)"
echo "  AWS_SESSION_TOKEN=(設定済み)"
echo ""
echo "認証確認を実行中..."

# 認証確認
aws sts get-caller-identity --no-verify-ssl

echo ""
echo "🎉 AWS CLIが使用可能です（12時間有効）"
echo ""
echo "使用例:"
echo "  aws cloudwatch list-dashboards --no-verify-ssl"
echo "  cd sceptre && PYTHONHTTPSVERIFY=0 uv run sceptre status prod"
