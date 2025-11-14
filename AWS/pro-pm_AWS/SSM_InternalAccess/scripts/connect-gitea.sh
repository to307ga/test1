#!/bin/bash
set -e

REGION="ap-northeast-1"
LOCAL_PORT="8080"
REMOTE_PORT="80"

echo "🔍 EC2インスタンスを検索中..."
EC2_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Environment,Values=poc" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region $REGION \
  --no-verify-ssl)

if [ "$EC2_ID" == "None" ] || [ -z "$EC2_ID" ]; then
  echo "❌ エラー: 稼働中のEC2インスタンスが見つかりません"
  echo "   web-blue ASGのインスタンスを起動してください"
  exit 1
fi

echo "✅ EC2インスタンス: $EC2_ID"

echo "🔍 Gitea ALBを検索中..."
GITEA_ALB=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `gitea`)].DNSName | [0]' \
  --output text \
  --region $REGION \
  --no-verify-ssl)

if [ "$GITEA_ALB" == "None" ] || [ -z "$GITEA_ALB" ]; then
  echo "❌ エラー: Gitea ALBが見つかりません"
  exit 1
fi

echo "✅ Gitea ALB: $GITEA_ALB"
echo ""
echo "🚀 ポートフォワーディングを開始します..."
echo "   ローカル: http://localhost:$LOCAL_PORT"
echo "   リモート: http://$GITEA_ALB:$REMOTE_PORT"
echo ""
echo "📝 使用方法:"
echo "   - Web UI: http://localhost:$LOCAL_PORT"
echo "   - Git操作: git clone http://localhost:$LOCAL_PORT/user/repo.git"
echo ""
echo "⚠️  終了するには Ctrl+C を押してください"
echo ""

aws ssm start-session \
  --target $EC2_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$GITEA_ALB\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
  --region $REGION \
  --no-verify-ssl
