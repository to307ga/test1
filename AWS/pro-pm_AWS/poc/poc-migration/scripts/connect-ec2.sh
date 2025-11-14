#!/bin/bash
# SSM Session Manager経由でEC2インスタンスに接続
# 使用方法:
#   ./connect-ec2.sh <instance-name> [environment] [region]
#   例: ./connect-ec2.sh pochub-001
#   例: ./connect-ec2.sh pochub-001 poc ap-northeast-1

set -e

# 引数の取得
INSTANCE_NAME=${1}
ENVIRONMENT=${2:-poc}
REGION=${3:-ap-northeast-1}

# 引数チェック
if [ -z "$INSTANCE_NAME" ]; then
  echo "Usage: $0 <instance-name> [environment] [region]"
  echo ""
  echo "Arguments:"
  echo "  instance-name : EC2インスタンスのNameタグ値 (必須)"
  echo "  environment   : Environmentタグ値 (デフォルト: poc)"
  echo "  region        : AWSリージョン (デフォルト: ap-northeast-1)"
  echo ""
  echo "Examples:"
  echo "  $0 pochub-001"
  echo "  $0 pochub-002 poc"
  echo "  $0 web-server prod ap-northeast-1"
  exit 1
fi

echo "=== EC2 SSM Session Manager Connection ==="
echo "Instance Name: ${INSTANCE_NAME}"
echo "Environment:   ${ENVIRONMENT}"
echo "Region:        ${REGION}"
echo ""

# インスタンスIDを取得
echo "Searching for instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=${INSTANCE_NAME}" \
    "Name=tag:Environment,Values=${ENVIRONMENT}" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region ${REGION})

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "Error: Instance not found with the following criteria:"
  echo "  Name: ${INSTANCE_NAME}"
  echo "  Environment: ${ENVIRONMENT}"
  echo "  State: running"
  echo "  Region: ${REGION}"
  exit 1
fi

echo "Instance ID: ${INSTANCE_ID}"
echo "Starting SSM session..."
echo ""

# SSMセッション開始
aws ssm start-session \
  --target ${INSTANCE_ID} \
  --region ${REGION}
