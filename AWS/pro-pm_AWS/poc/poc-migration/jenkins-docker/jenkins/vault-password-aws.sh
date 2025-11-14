#!/bin/bash
#
# Ansible Vault Password取得スクリプト（AWS Secrets Manager版）
# 使用方法: 
#   ansible-playbook --vault-password-file vault-password-aws.sh playbook.yml
#   または ansible.cfg で vault_password_file = ./vault-password-aws.sh
#
# 環境変数:
#   AWS_VAULT_SECRET_NAME: Secrets ManagerのSecret名（必須）
#   AWS_REGION: AWSリージョン（デフォルト: ap-northeast-1）
#   AWS_VAULT_KEY: SecretのJSONキー名（デフォルト: password）
#

set -e

# 設定値
SECRET_NAME="${AWS_VAULT_SECRET_NAME:-ansible-vault-password}"
REGION="${AWS_REGION:-ap-northeast-1}"
SECRET_KEY="${AWS_VAULT_KEY:-password}"

# エラーハンドリング
if [[ -z "$AWS_VAULT_SECRET_NAME" ]]; then
    echo "Error: AWS_VAULT_SECRET_NAME environment variable is required" >&2
    exit 1
fi

# AWS CLI認証確認
if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
    echo "Error: AWS CLI authentication failed" >&2
    exit 1
fi

# Secrets Managerからパスワード取得
if SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --query SecretString \
    --output text 2>/dev/null); then
    
    # JSONパースしてパスワード抽出
    if PASSWORD=$(echo "$SECRET_VALUE" | jq -r ".$SECRET_KEY" 2>/dev/null); then
        if [[ "$PASSWORD" != "null" && -n "$PASSWORD" ]]; then
            echo "$PASSWORD"
            exit 0
        fi
    fi
fi

echo "Error: Failed to retrieve vault password from AWS Secrets Manager" >&2
exit 1
