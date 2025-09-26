#!/bin/bash

# AWS MFA超簡単ログインスクリプト (jq不要版)
# 使用方法: ./mfa_simple.sh [MFAコード]

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

echo "🔐 MFA認証を実行中..."

# 既存のセッション情報をクリア
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PROFILE=prod

# GetSessionToken実行
echo "   AWS STS GetSessionToken を実行中..."
TEMP_CREDENTIALS=$(aws sts get-session-token \
    --duration-seconds $DURATION \
    --serial-number "$MFA_DEVICE_ARN" \
    --token-code "$MFA_CODE" \
    --no-verify-ssl 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ エラー: GetSessionToken が失敗しました"
    echo "   MFAコードが正しいか確認してください"
    exit 1
fi

# Python使用でJSONをパース（jqの代替）
echo "   認証情報を解析中..."
python3 -c "
import json, os, sys
data = json.loads('''$TEMP_CREDENTIALS''')
creds = data['Credentials']
print('export AWS_ACCESS_KEY_ID=\"' + creds['AccessKeyId'] + '\"')
print('export AWS_SECRET_ACCESS_KEY=\"' + creds['SecretAccessKey'] + '\"')
print('export AWS_SESSION_TOKEN=\"' + creds['SessionToken'] + '\"')
print('export EXPIRATION=\"' + creds['Expiration'] + '\"')
" > /tmp/aws_mfa_vars.sh

# 環境変数を読み込み
source /tmp/aws_mfa_vars.sh
unset AWS_PROFILE
rm -f /tmp/aws_mfa_vars.sh

# 結果出力
echo "✅ MFA認証成功！"
echo "   有効期限: $EXPIRATION"
echo ""

# 認証確認
echo "🔍 認証確認を実行中..."
IDENTITY=$(aws sts get-caller-identity --no-verify-ssl 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ 認証確認成功"
    echo "   $(echo $IDENTITY | python3 -c "import json,sys; data=json.load(sys.stdin); print(f\"User: {data.get('Arn', 'Unknown')}\")")"
else
    echo "❌ 認証確認失敗"
    exit 1
fi

echo ""
echo "🎉 AWS CLIが使用可能です（12時間有効）"
echo ""
echo "📋 使用例:"
echo "   aws cloudwatch list-dashboards --no-verify-ssl"
echo "   cd sceptre && PYTHONHTTPSVERIFY=0 uv run sceptre status prod"
echo ""
echo "💡 この認証は現在のターミナルセッションでのみ有効です"
