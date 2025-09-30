#!/bin/bash

# AWS認証状態 - クイック確認
echo "🔍 現在のAWS認証状態:"
echo ""

# 現在の認証情報
IDENTITY=$(aws sts get-caller-identity --no-verify-ssl 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ 認証: 成功"
    echo "👤 ユーザー: $(echo "$IDENTITY" | grep -o '"Arn":"[^"]*' | cut -d'"' -f4)"
    echo "🏢 アカウント: $(echo "$IDENTITY" | grep -o '"Account":"[^"]*' | cut -d'"' -f4)"
else
    echo "❌ 認証: 失敗"
    exit 1
fi

# 設定情報
echo ""
echo "⚙️ 認証設定:"
aws configure list | head -5

echo ""
echo "📝 利用可能プロファイル:"
aws configure list-profiles | sed 's/^/   /'

# 環境変数チェック
echo ""
echo "🔧 環境変数:"
echo "   AWS_PROFILE: ${AWS_PROFILE:-'(未設定 = default使用)'}"
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "   一時認証: 使用中"
else
    echo "   永続認証: credentials file使用"
fi
