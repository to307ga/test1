#!/bin/bash

echo "MFA認証用スクリプト"
echo "現在のMFAデバイス: arn:aws:iam::910230630316:mfa/dev_toshimitsu.tomonaga.zd"
echo ""
echo "使用方法:"
echo "  ./get_mfa_token.sh [MFAトークンコード]"
echo ""
echo "例："
echo "  ./get_mfa_token.sh 123456"
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
    --profile dev \
    --serial-number arn:aws:iam::910230630316:mfa/dev_toshimitsu.tomonaga.zd \
    --token-code $TOKEN_CODE \
    --duration-seconds 43200 \
    --no-verify-ssl 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ MFA認証成功!"
    echo ""
    echo "以下のコマンドを実行して一時的な認証情報を設定してください:"
    echo ""
    
    ACCESS_KEY=$(echo $OUTPUT | grep -o '"AccessKeyId": "[^"]*"' | sed 's/.*": "\(.*\)"/\1/')
    SECRET_KEY=$(echo $OUTPUT | grep -o '"SecretAccessKey": "[^"]*"' | sed 's/.*": "\(.*\)"/\1/')
    SESSION_TOKEN=$(echo $OUTPUT | grep -o '"SessionToken": "[^"]*"' | sed 's/.*": "\(.*\)"/\1/')
    
    echo "export AWS_ACCESS_KEY_ID=$ACCESS_KEY"
    echo "export AWS_SECRET_ACCESS_KEY=$SECRET_KEY"
    echo "export AWS_SESSION_TOKEN=$SESSION_TOKEN"
    echo ""
    echo "または、以下のファイルに保存されました:"
    
    # Save to temporary profile (project root)
    CREDENTIALS_FILE="$(dirname "$0")/../aws_mfa_credentials_dev"
    cat > "$CREDENTIALS_FILE" << EOL
export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_SESSION_TOKEN=$SESSION_TOKEN
EOL
    
    echo "$CREDENTIALS_FILE"
    echo ""
    echo "適用するには: source $CREDENTIALS_FILE"
    
else
    echo "❌ MFA認証に失敗しました:"
    echo "$OUTPUT"
fi
