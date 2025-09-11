#!/bin/bash
# EasyDKIM無効化スクリプト

set -e

EMAIL_IDENTITY=${1:-goo.ne.jp}
REGION=${2:-ap-northeast-1}

echo "=== EasyDKIM無効化スクリプト ==="
echo "Email Identity: $EMAIL_IDENTITY"
echo "Region: $REGION"
echo ""

# 1. 現在の設定確認
echo "1. 現在のDKIM設定確認..."
CURRENT_STATUS=$(aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningEnabled" --output text)
echo "現在のSigningEnabled: $CURRENT_STATUS"

if [ "$CURRENT_STATUS" = "false" ]; then
    echo "EasyDKIMは既に無効化されています。"
    exit 0
fi

# 2. EasyDKIM無効化
echo "2. EasyDKIM無効化..."
aws sesv2 put-email-identity-dkim-attributes \
    --email-identity $EMAIL_IDENTITY \
    --no-signing-enabled \
    --region $REGION

# 3. 無効化確認
echo "3. 無効化確認..."
NEW_STATUS=$(aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningEnabled" --output text)
echo "新しいSigningEnabled: $NEW_STATUS"

if [ "$NEW_STATUS" = "false" ]; then
    echo "=== EasyDKIM無効化完了 ==="
else
    echo "エラー: EasyDKIMの無効化に失敗しました"
    exit 1
fi
