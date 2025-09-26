#!/bin/bash

# AWS MFA 超簡単ワンライナー
# MFAコードを第1引数で受け取り、一瞬でログイン完了

if [ -z "$1" ]; then
    echo "使用方法: ./mfa_quick.sh [6桁のMFAコード]"
    echo "例: ./mfa_quick.sh 123456"
    exit 1
fi

# ワンライナー実行
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN && export AWS_PROFILE=prod && echo "🔐 MFA認証実行中..." && CREDS=$(aws sts get-session-token --duration-seconds 43200 --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" --token-code "$1" --no-verify-ssl 2>/dev/null) && eval $(echo "$CREDS" | python3 -c "import json,sys; d=json.load(sys.stdin)['Credentials']; print(f\"export AWS_ACCESS_KEY_ID='{d['AccessKeyId']}'; export AWS_SECRET_ACCESS_KEY='{d['SecretAccessKey']}'; export AWS_SESSION_TOKEN='{d['SessionToken']}';\")") && unset AWS_PROFILE && echo "✅ 認証成功！AWS CLIが使用可能です" && aws sts get-caller-identity --no-verify-ssl >/dev/null 2>&1 && echo "🎉 12時間有効" || echo "❌ 認証失敗 - MFAコードを確認してください"
