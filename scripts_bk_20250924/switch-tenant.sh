#!/bin/bash
# テナント切り替えスクリプト

set -e

TENANT="$1"
ENVIRONMENT="$2"

if [ -z "$TENANT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "❌ Usage: $0 <tenant> <environment>"
    echo "📝 Available tenants: goo, partner-a, partner-b"
    echo "🏷️  Available environments: dev, prod"
    echo ""
    echo "例: $0 goo prod"
    exit 1
fi

# プロファイル設定
export AWS_PROFILE="${TENANT}-${ENVIRONMENT}"

# Sceptre設定
export SCEPTRE_CONFIG_DIR="config/${TENANT}/${ENVIRONMENT}"

echo "🔄 テナント切り替え完了:"
echo "   🏢 テナント: $TENANT"
echo "   🌍 環境: $ENVIRONMENT"
echo "   👤 AWSプロファイル: $AWS_PROFILE"
echo "   📁 Sceptre設定: $SCEPTRE_CONFIG_DIR"
echo ""

# アカウント確認
echo "🔍 現在のAWSアカウント:"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table || echo "❌ プロファイル設定を確認してください"
echo ""

echo "🚀 デプロイコマンド例:"
echo "   sceptre list stacks $SCEPTRE_CONFIG_DIR"
echo "   sceptre create $SCEPTRE_CONFIG_DIR/base.yaml"
echo "   sceptre create $SCEPTRE_CONFIG_DIR/ses.yaml"
