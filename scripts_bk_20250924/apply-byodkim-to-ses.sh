#!/bin/bash
# BYODKIM設定適用スクリプト
# EasyDKIMを無効化し、S3から取得したBYODKIM証明書をSESに適用

set -e

EMAIL_IDENTITY=${1:-goo.ne.jp}
REGION=${2:-ap-northeast-1}
S3_BUCKET=${3:-aws-ses-migration-prod-dkim-certificates}
SELECTOR=${4}

echo "=== BYODKIM設定適用スクリプト ==="
echo "Email Identity: $EMAIL_IDENTITY"
echo "Region: $REGION"
echo "S3 Bucket: $S3_BUCKET"
echo ""

# セレクターの自動検出またはパラメータから取得
if [ -z "$SELECTOR" ]; then
    echo "1. セレクターの自動検出（最新のセレクターを使用）..."
    SELECTOR=$(uv run aws s3 ls s3://$S3_BUCKET/dkim-keys/$EMAIL_IDENTITY/ | grep "PRE" | sort -k1,1 -k2,2 | tail -1 | awk '{print $2}' | sed 's/\///')
    if [ -z "$SELECTOR" ]; then
        echo "❌ エラー: S3バケットでセレクターが見つかりません。"
        echo "手動でセレクターを指定してください: $0 $EMAIL_IDENTITY $REGION $S3_BUCKET <selector>"
        exit 1
    fi
    echo "🔍 検出されたセレクター: $SELECTOR（最新）"

    # 利用可能なセレクターをすべて表示
    echo ""
    echo "📋 利用可能なセレクター一覧:"
    uv run aws s3 ls s3://$S3_BUCKET/dkim-keys/$EMAIL_IDENTITY/ | grep "PRE" | awk '{print "  - " $2}' | sed 's/\///'
    echo ""
fi

echo "使用するセレクター: $SELECTOR"
echo ""

# Step 1: 現在の設定確認
echo "2. 現在のDKIM設定確認..."
CURRENT_ORIGIN=$(uv run aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningAttributesOrigin" --output text 2>/dev/null || echo "ERROR")

if [ "$CURRENT_ORIGIN" = "ERROR" ]; then
    echo "❌ エラー: Email Identity '$EMAIL_IDENTITY' が見つかりません。Phase 3スタックが完了しているか確認してください。"
    exit 1
fi

echo "現在のSigningAttributesOrigin: $CURRENT_ORIGIN"

# Step 2: EasyDKIM無効化（AWS_SESの場合のみ）
if [ "$CURRENT_ORIGIN" = "AWS_SES" ]; then
    echo "3. EasyDKIM無効化中..."
    uv run aws sesv2 put-email-identity-dkim-attributes \
        --email-identity $EMAIL_IDENTITY \
        --no-signing-enabled \
        --region $REGION

    echo "EasyDKIM無効化完了。5秒待機..."
    sleep 5
else
    echo "3. EasyDKIMは既に無効化されています (Origin: $CURRENT_ORIGIN)"
fi

# Step 3: S3から秘密鍵を取得
echo "4. S3から秘密鍵を取得中..."
PRIVATE_KEY_PATH="s3://$S3_BUCKET/dkim-keys/$EMAIL_IDENTITY/$SELECTOR/private_key.pem"
TEMP_KEY_FILE="/tmp/private_key_${SELECTOR}.pem"

uv run aws s3 cp "$PRIVATE_KEY_PATH" "$TEMP_KEY_FILE"
if [ ! -f "$TEMP_KEY_FILE" ]; then
    echo "❌ エラー: 秘密鍵のダウンロードに失敗しました: $PRIVATE_KEY_PATH"
    exit 1
fi

echo "秘密鍵を取得しました: $PRIVATE_KEY_PATH"

# Step 4: PEMヘッダー除去とbase64エンコーディング
echo "5. 秘密鍵をbase64エンコード中..."
PRIVATE_KEY_BASE64=$(grep -v "BEGIN\|END" "$TEMP_KEY_FILE" | tr -d '\n')

if [ -z "$PRIVATE_KEY_BASE64" ]; then
    echo "❌ エラー: 秘密鍵のbase64エンコーディングに失敗しました"
    exit 1
fi

echo "base64エンコーディング完了"

# Step 5: BYODKIM署名属性設定
echo "6. BYODKIM署名属性をSESに設定中..."
uv run aws sesv2 put-email-identity-dkim-signing-attributes \
    --email-identity "$EMAIL_IDENTITY" \
    --signing-attributes-origin EXTERNAL \
    --signing-attributes "DomainSigningSelector=$SELECTOR,DomainSigningPrivateKey=$PRIVATE_KEY_BASE64" \
    --region "$REGION"

echo "BYODKIM署名属性設定完了"

# Step 6: DKIM署名有効化
echo "7. DKIM署名有効化中..."
uv run aws sesv2 put-email-identity-dkim-attributes \
    --email-identity "$EMAIL_IDENTITY" \
    --signing-enabled \
    --region "$REGION"

echo "DKIM署名有効化完了"

# Step 7: 設定確認
echo "8. 最終設定確認..."
FINAL_CONFIG=$(uv run aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes" --output json)
echo "最終DKIM設定:"
echo "$FINAL_CONFIG"

# Step 8: 結果検証（jq不要の方法）
FINAL_ORIGIN=$(uv run aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningAttributesOrigin" --output text)
FINAL_ENABLED=$(uv run aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningEnabled" --output text)
FINAL_TOKENS=$(uv run aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.Tokens[0]" --output text)

echo ""
echo "=== BYODKIM設定結果 ==="
if [ "$FINAL_ORIGIN" = "EXTERNAL" ] && ([ "$FINAL_ENABLED" = "true" ] || [ "$FINAL_ENABLED" = "True" ]); then
    echo "✅ BYODKIM設定成功！"
    echo "   SigningAttributesOrigin: $FINAL_ORIGIN"
    echo "   SigningEnabled: $FINAL_ENABLED"
    echo "   Selector Token: $FINAL_TOKENS"
    echo ""
    echo "📋 DNS設定情報:"
    echo "   レコード名: ${FINAL_TOKENS}._domainkey.$EMAIL_IDENTITY"
    echo "   レコードタイプ: TXT"
    echo "   レコード値: DNS情報ファイルを確認してください"
    echo ""
    echo "💡 次のステップ:"
    echo "   1. DNS担当者にTXTレコード登録を依頼"
    echo "   2. DNS伝播後、SESでDKIM検証が自動完了"
else
    echo "❌ BYODKIM設定に問題があります"
    echo "   SigningAttributesOrigin: $FINAL_ORIGIN (期待値: EXTERNAL)"
    echo "   SigningEnabled: $FINAL_ENABLED (期待値: true)"
    exit 1
fi

# 一時ファイル削除
rm -f "$TEMP_KEY_FILE"

echo ""
echo "=== BYODKIM設定適用完了 ==="
