#!/bin/bash
# EasyDKIM無効化スクリプト（SSL対応版）

set -e

EMAIL_IDENTITY=${1:-goo.ne.jp}
REGION=${2:-ap-northeast-1}

echo "=== EasyDKIM無効化スクリプト (SSL Safe Version) ==="
echo "Email Identity: $EMAIL_IDENTITY"
echo "Region: $REGION"
echo "企業ネットワーク環境のため、--no-verify-sslオプションを使用します"
echo ""

# 1. 現在の設定確認
echo "1. 現在のDKIM設定確認..."
CURRENT_STATUS=$(aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --no-verify-ssl --query "DkimAttributes.SigningEnabled" --output text 2>/dev/null || echo "ERROR")

if [ "$CURRENT_STATUS" = "ERROR" ]; then
    echo "エラー: Email Identity '$EMAIL_IDENTITY' が見つかりません。Phase 3スタックが完了しているか確認してください。"
    exit 1
fi

echo "現在のSigningEnabled: $CURRENT_STATUS"

# 2. 既に無効化されている場合はスキップ
if [ "$CURRENT_STATUS" = "false" ]; then
    echo "EasyDKIMは既に無効化されています。"
    exit 0
fi

# 3. EasyDKIM無効化
echo "2. EasyDKIM無効化..."
aws sesv2 put-email-identity-dkim-attributes \
    --email-identity $EMAIL_IDENTITY \
    --no-signing-enabled \
    --region $REGION \
    --no-verify-ssl

echo "無効化コマンドを実行しました。"

# 4. 無効化確認（少し待ってから確認）
echo "3. 無効化確認（5秒待機後）..."
sleep 5

NEW_STATUS=$(aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --no-verify-ssl --query "DkimAttributes.SigningEnabled" --output text)
echo "新しいSigningEnabled: $NEW_STATUS"

# 'false' または 'False' のどちらでも成功と判定
if [ "$NEW_STATUS" = "false" ] || [ "$NEW_STATUS" = "False" ]; then
    echo "✅ EasyDKIM無効化成功！"
    echo ""
    echo "次のステップ:"
    echo "1. Phase 4: DNS準備の実行"
    echo "2. Phase 5: DNSチーム連携"
    echo "3. 手動DKIM証明書生成とBYODKIM登録"
else
    echo "❌ EasyDKIM無効化に失敗しました。現在の状態: $NEW_STATUS"
    exit 1
fi
