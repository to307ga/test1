#!/bin/bash
# SES テストメール送信スクリプト
# 使い方: ./send_test_email.sh

# 設定値
SENDER_EMAIL="test@goo.ne.jp"
RECIPIENT_EMAIL="goo-idpay-sys@ml.nttdocomo.com"
CONFIGURATION_SET="aws-ses-migration-prod-config-set"
REGION="ap-northeast-1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

#件名とメッセージ内容
SUBJECT="SES Test Email - $(date '+%Y%m%d-%H%M%S')"
MESSAGE_BODY="SES テストメール送信

送信時刻: ${TIMESTAMP}
送信者: ${SENDER_EMAIL}
受信者: ${RECIPIENT_EMAIL}
Configuration Set: ${CONFIGURATION_SET}

このメールはSES-Kinesis統合のテストメールです。
ログがKinesis Firehose → S3に正常に格納されることを確認します。

テスト項目:
1. SES送信機能
2. BYODKIM署名
3. Configuration Set連携
4. Kinesis Firehose連携
5. S3ログ格納
"

echo "=== SES テストメール送信 ==="
echo "送信者: ${SENDER_EMAIL}"
echo "受信者: ${RECIPIENT_EMAIL}"
echo "Configuration Set: ${CONFIGURATION_SET}"
echo "時刻: ${TIMESTAMP}"
echo ""

# AWS CLIでメール送信
echo "メール送信中..."
RESULT=$(aws ses send-email \
  --region ${REGION} \
  --source "${SENDER_EMAIL}" \
  --destination "ToAddresses=${RECIPIENT_EMAIL}" \
  --message "Subject={Data='${SUBJECT}',Charset=utf-8},Body={Text={Data='${MESSAGE_BODY}',Charset=utf-8}}" \
  --configuration-set-name "${CONFIGURATION_SET}" \
  --output json 2>&1)

if [ $? -eq 0 ]; then
    MESSAGE_ID=$(echo ${RESULT} | jq -r '.MessageId')
    echo "✅ メール送信成功！"
    echo "📧 Message ID: ${MESSAGE_ID}"
    echo ""

    echo "=== ログ確認方法 ==="
    echo "1. CloudWatch Logs:"
    echo "   - /aws/ses/aws-ses-migration-prod"
    echo "   - /aws/ses-kinesis-integration/aws-ses-migration-prod"
    echo ""
    echo "2. Kinesis Data Firehose ログ:"
    echo "   - CloudWatch: AWS/KinesisFirehose メトリクス"
    echo ""
    echo "3. S3 ログファイル（約5分後）:"
    aws s3 ls s3://aws-ses-migration-prod-raw-logs/ --recursive | tail -10
    echo ""
    aws s3 ls s3://aws-ses-migration-prod-masked-logs/ --recursive | tail -10

else
    echo "❌ メール送信エラー："
    echo "${RESULT}"
    exit 1
fi
