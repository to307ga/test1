#!/bin/bash

echo "MFA認証用スクリプト (改良版)"
echo "現在のMFAデバイス: arn:aws:iam::910230630316:mfa/dev_toshimitsu.tomonaga.zd"
echo ""

# 既存のMFA認証情報の有効期限チェック
check_existing_credentials() {
    if [ -n "$AWS_SESSION_TOKEN" ]; then
        echo "🔍 既存のMFA認証情報を確認中..."
        CALLER_IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "✅ 既存のMFA認証情報は有効です"
            echo "現在のユーザー: $(echo $CALLER_IDENTITY | jq -r '.Arn')"
            echo ""
            echo "新しい認証情報を取得しますか？ (y/N):"
            read -r RENEW
            if [[ ! "$RENEW" =~ ^[Yy]$ ]]; then
                echo "既存の認証情報を継続使用します"
                exit 0
            fi
        else
            echo "⚠️  既存のMFA認証情報が期限切れです。新しい認証情報を取得します。"
        fi
    fi
}

# 古い環境変数をクリア
clear_old_credentials() {
    echo "🧹 古い認証情報環境変数をクリア中..."
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    echo "✅ 環境変数クリア完了"
    echo ""
}

# 既存認証情報のチェック
check_existing_credentials

# 古い認証情報のクリア
clear_old_credentials

echo "使用方法:"
echo "  ./get_mfa_token_dev.sh [MFAトークンコード]"
echo ""
echo "例："
echo "  ./get_mfa_token_dev.sh 123456"
echo ""

if [ $# -eq 0 ]; then
    echo "MFAトークンコード（6桁）を入力してください:"
    read TOKEN_CODE
else
    TOKEN_CODE=$1
fi

echo "MFAトークン $TOKEN_CODE で認証中..."

# Get temporary credentials
OUTPUT=$(aws sts get-session-token \
    --serial-number arn:aws:iam::910230630316:mfa/dev_toshimitsu.tomonaga.zd \
    --token-code $TOKEN_CODE \
    --duration-seconds 43200 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ MFA認証成功!"
    echo ""
    
    ACCESS_KEY=$(echo $OUTPUT | jq -r '.Credentials.AccessKeyId')
    SECRET_KEY=$(echo $OUTPUT | jq -r '.Credentials.SecretAccessKey')
    SESSION_TOKEN=$(echo $OUTPUT | jq -r '.Credentials.SessionToken')
    EXPIRATION=$(echo $OUTPUT | jq -r '.Credentials.Expiration')
    
    # 有効期限を日本時間で表示
    EXPIRATION_JST=$(date -d "$EXPIRATION" "+%Y-%m-%d %H:%M:%S JST" 2>/dev/null || echo "$EXPIRATION")
    
    echo "認証情報の有効期限: $EXPIRATION_JST"
    echo ""
    
    # Save to temporary profile with timestamp
    cat > /home/t-tomonaga/AWS/aws_mfa_credentials << EOL
# MFA認証情報 - 有効期限: $EXPIRATION_JST
# 生成日時: $(date "+%Y-%m-%d %H:%M:%S JST")
export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_SESSION_TOKEN=$SESSION_TOKEN
EOL
    
    echo "✅ 認証情報が保存されました: /home/t-tomonaga/AWS/aws_mfa_credentials"
    echo ""
    echo "🚀 自動適用しますか？ (Y/n):"
    read -r AUTO_APPLY
    if [[ ! "$AUTO_APPLY" =~ ^[Nn]$ ]]; then
        source /home/t-tomonaga/AWS/aws_mfa_credentials
        echo "✅ 認証情報が自動適用されました"
        echo ""
        echo "確認:"
        aws sts get-caller-identity --query 'Arn' --output text
    else
        echo "手動適用するには: source /home/t-tomonaga/AWS/aws_mfa_credentials"
    fi
    
else
    echo "❌ MFA認証に失敗しました:"
    echo "$OUTPUT"
    echo ""
    echo "💡 トラブルシューティング:"
    echo "1. MFAトークンコードが正しいか確認"
    echo "2. 基本認証情報 (~/.aws/credentials) が設定されているか確認"
    echo "3. 時刻同期が正しいか確認"
fi
