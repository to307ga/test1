#!/usr/bin/env python3
"""
SES テストメール送信スクリプト
使い方: python send_test_email.py
"""

import boto3
import json
from datetime import datetime

def main():
    # 設定値
    SENDER_EMAIL = "goo-idpay-sys@ml.nttdocomo.com"  # 検証済みアドレスを送信者としても使用
    RECIPIENT_EMAIL = "goo-idpay-sys@ml.nttdocomo.com"
    CONFIGURATION_SET = "aws-ses-migration-prod-config-set"
    REGION = "ap-northeast-1"

    # SESクライアント作成
    ses_client = boto3.client('ses', region_name=REGION)

    # メール内容作成
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    subject = f"SES Test Email - {datetime.now().strftime('%Y%m%d-%H%M%S')}"

    body_text = f"""SES テストメール送信

送信時刻: {timestamp}
送信者: {SENDER_EMAIL}
受信者: {RECIPIENT_EMAIL}
Configuration Set: {CONFIGURATION_SET}

このメールはSES-Kinesis統合のテストメールです。
ログがKinesis Firehose → S3に正常に格納されることを確認します。

テスト項目:
1. SES送信機能
2. BYODKIM署名
3. Configuration Set連携
4. Kinesis Firehose連携
5. S3ログ格納
"""

    print("=== SES テストメール送信 ===")
    print(f"送信者: {SENDER_EMAIL}")
    print(f"受信者: {RECIPIENT_EMAIL}")
    print(f"Configuration Set: {CONFIGURATION_SET}")
    print(f"時刻: {timestamp}")
    print()

    try:
        print("メール送信中...")

        # メール送信
        response = ses_client.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [RECIPIENT_EMAIL]},
            Message={
                'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                'Body': {'Text': {'Data': body_text, 'Charset': 'UTF-8'}}
            },
            ConfigurationSetName=CONFIGURATION_SET
        )

        message_id = response['MessageId']

        print("✅ メール送信成功！")
        print(f"📧 Message ID: {message_id}")
        print()

        print("=== ログ確認方法 ===")
        print("1. CloudWatch Logs:")
        print("   - /aws/ses/aws-ses-migration-prod")
        print("   - /aws/ses-kinesis-integration/aws-ses-migration-prod")
        print()
        print("2. Kinesis Data Firehose ログ:")
        print("   - CloudWatch: AWS/KinesisFirehose メトリクス")
        print()
        print("3. S3 ログファイル確認（約5分後）:")

        # S3バケット一覧表示
        s3_client = boto3.client('s3', region_name=REGION)

        buckets_to_check = [
            'aws-ses-migration-prod-raw-logs',
            'aws-ses-migration-prod-masked-logs'
        ]

        for bucket in buckets_to_check:
            try:
                print(f"   📁 s3://{bucket}/ の最新ファイル:")
                response = s3_client.list_objects_v2(
                    Bucket=bucket,
                    MaxKeys=10
                )

                if 'Contents' in response:
                    objects = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)
                    for obj in objects[:5]:
                        print(f"     - {obj['Key']} ({obj['LastModified']})")
                else:
                    print(f"     (ファイルなし)")

            except Exception as e:
                print(f"     エラー: {str(e)}")

            print()

        print("=== 次の手順 ===")
        print("1. 受信メールボックスでメール受信を確認")
        print("2. 約5分後にS3バケットに新しいログファイルが作成されるか確認")
        print("3. CloudWatch Logsでリアルタイムログを確認")

        return True

    except Exception as e:
        print(f"❌ メール送信エラー: {str(e)}")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
