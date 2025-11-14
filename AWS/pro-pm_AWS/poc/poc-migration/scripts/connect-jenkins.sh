#!/bin/bash
set -e

REGION="ap-northeast-1"
LOCAL_PORT="8081"
REMOTE_PORT="8081"

echo "🔍 EC2インスタンスを検索中..."
EC2_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Environment,Values=poc" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region $REGION)

if [ "$EC2_ID" == "None" ] || [ -z "$EC2_ID" ]; then
  echo "❌ エラー: 稼働中のEC2インスタンスが見つかりません"
  exit 1
fi

echo "✅ EC2インスタンス: $EC2_ID"

echo "🔍 Jenkins ALBを検索中..."
JENKINS_ALB=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `jenkins`)].DNSName | [0]' \
  --output text \
  --region $REGION)

if [ "$JENKINS_ALB" == "None" ] || [ -z "$JENKINS_ALB" ]; then
  echo "❌ エラー: Jenkins ALBが見つかりません"
  exit 1
fi

echo "✅ Jenkins ALB: $JENKINS_ALB"
echo ""
echo "🚀 ポートフォワーディングを開始します..."
echo "   ローカル: http://localhost:$LOCAL_PORT"
echo "   リモート: http://$JENKINS_ALB:$REMOTE_PORT"
echo ""
echo "📝 Jenkins UI: http://localhost:$LOCAL_PORT"
echo ""
echo "⚠️  終了するには Ctrl+C を押してください"
echo ""

aws ssm start-session \
  --target $EC2_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$JENKINS_ALB\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
  --region $REGION
