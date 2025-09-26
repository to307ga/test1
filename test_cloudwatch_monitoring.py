#!/usr/bin/env python3
"""
CloudWatch監視テストスクリプト
サンドボックス環境でのモニタリング機能テスト
"""

import boto3
import json
import time
from datetime import datetime, timedelta

class CloudWatchMonitoringTester:
    def __init__(self):
        self.ses_client = boto3.client('ses', region_name='ap-northeast-1')
        self.cloudwatch_client = boto3.client('cloudwatch', region_name='ap-northeast-1')
        self.configuration_set = "aws-ses-migration-prod-config-set"
        self.test_email = "goo-idpay-sys@ml.nttdocomo.com"

    def test_ses_sending_metrics(self):
        """SES送信メトリクスのテスト"""
        print("=== SES送信メトリクステスト ===")

        try:
            # テストメール送信前のメトリクス取得
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=1)

            # Send メトリクス取得
            response = self.cloudwatch_client.get_metric_statistics(
                Namespace='AWS/SES',
                MetricName='Send',
                Dimensions=[
                    {'Name': 'ConfigurationSet', 'Value': self.configuration_set}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )

            print(f"📊 送信前のSendメトリクス: {response['Datapoints']}")

            # テストメール送信
            print("📧 テストメール送信中...")
            mail_response = self.ses_client.send_email(
                Source=self.test_email,
                Destination={'ToAddresses': [self.test_email]},
                Message={
                    'Subject': {'Data': f'CloudWatch Monitor Test - {datetime.now().strftime("%Y%m%d-%H%M%S")}', 'Charset': 'UTF-8'},
                    'Body': {'Text': {'Data': 'CloudWatch監視機能テストメールです。', 'Charset': 'UTF-8'}}
                },
                ConfigurationSetName=self.configuration_set
            )

            message_id = mail_response['MessageId']
            print(f"✅ メール送信成功: {message_id}")

            # メトリクス更新待ち
            print("⏱️  メトリクス更新待ち（5分間）...")
            time.sleep(300)

            # 送信後のメトリクス取得
            end_time = datetime.utcnow()
            response = self.cloudwatch_client.get_metric_statistics(
                Namespace='AWS/SES',
                MetricName='Send',
                Dimensions=[
                    {'Name': 'ConfigurationSet', 'Value': self.configuration_set}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )

            print(f"📊 送信後のSendメトリクス: {response['Datapoints']}")
            return True

        except Exception as e:
            print(f"❌ SES送信メトリクステストエラー: {str(e)}")
            return False

    def test_firehose_metrics(self):
        """Kinesis Firehoseメトリクスのテスト"""
        print("\n=== Kinesis Firehoseメトリクステスト ===")

        streams = [
            'aws-ses-migration-prod-raw-logs-stream',
            'aws-ses-migration-prod-masked-logs-stream'
        ]

        for stream_name in streams:
            try:
                print(f"📊 {stream_name} のメトリクスを確認中...")

                end_time = datetime.utcnow()
                start_time = end_time - timedelta(hours=2)

                # レコード配信数
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace='AWS/KinesisFirehose',
                    MetricName='DeliveryToS3.Records',
                    Dimensions=[
                        {'Name': 'DeliveryStreamName', 'Value': stream_name}
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=3600,
                    Statistics=['Sum']
                )

                datapoints = response.get('Datapoints', [])
                total_records = sum(point['Sum'] for point in datapoints)
                print(f"  📈 配信レコード数: {total_records}")

                # 配信成功数
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace='AWS/KinesisFirehose',
                    MetricName='DeliveryToS3.Success',
                    Dimensions=[
                        {'Name': 'DeliveryStreamName', 'Value': stream_name}
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=3600,
                    Statistics=['Sum']
                )

                datapoints = response.get('Datapoints', [])
                total_success = sum(point['Sum'] for point in datapoints)
                print(f"  ✅ 配信成功数: {total_success}")

            except Exception as e:
                print(f"  ❌ {stream_name} メトリクスエラー: {str(e)}")

    def test_alarm_states(self):
        """アラーム状態のテスト"""
        print("\n=== アラーム状態テスト ===")

        alarm_names = [
            'aws-ses-migration-prod-ses-bounce-rate-high',
            'aws-ses-migration-prod-ses-complaint-rate-high',
            'aws-ses-migration-prod-ses-sending-quota-usage-high'
        ]

        try:
            response = self.cloudwatch_client.describe_alarms(
                AlarmNames=alarm_names
            )

            for alarm in response['MetricAlarms']:
                state_emoji = {
                    'OK': '✅',
                    'ALARM': '🚨',
                    'INSUFFICIENT_DATA': '⚠️'
                }.get(alarm['StateValue'], '❓')

                print(f"  {state_emoji} {alarm['AlarmName']}: {alarm['StateValue']}")
                print(f"    閾値: {alarm['Threshold']} ({alarm['ComparisonOperator']})")
                print(f"    理由: {alarm.get('StateReason', 'N/A')}")

        except Exception as e:
            print(f"❌ アラーム状態テストエラー: {str(e)}")

    def test_dashboard_access(self):
        """ダッシュボードアクセステスト"""
        print("\n=== ダッシュボードアクセステスト ===")

        try:
            response = self.cloudwatch_client.list_dashboards()
            ses_dashboards = [d for d in response['DashboardEntries']
                             if 'aws-ses-migration' in d['DashboardName']]

            print(f"📊 利用可能なSESダッシュボード数: {len(ses_dashboards)}")

            for dashboard in ses_dashboards:
                print(f"  📋 {dashboard['DashboardName']}")
                dashboard_url = f"https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name={dashboard['DashboardName']}"
                print(f"     URL: {dashboard_url}")

        except Exception as e:
            print(f"❌ ダッシュボードアクセステストエラー: {str(e)}")

    def quick_monitoring_test(self):
        """クイック監視テスト（メール送信なし）"""
        print("=== クイック監視テスト（メール送信なし）===")

        self.test_firehose_metrics()
        self.test_alarm_states()
        self.test_dashboard_access()

        # 最近のS3バケット活動確認
        print("\n=== S3バケット活動確認 ===")
        s3_client = boto3.client('s3', region_name='ap-northeast-1')

        buckets = [
            'aws-ses-migration-prod-raw-logs-007773581311',
            'aws-ses-migration-prod-masked-logs-007773581311'
        ]

        for bucket in buckets:
            try:
                response = s3_client.list_objects_v2(
                    Bucket=bucket,
                    MaxKeys=5
                )

                if 'Contents' in response:
                    latest_objects = sorted(response['Contents'],
                                          key=lambda x: x['LastModified'],
                                          reverse=True)
                    print(f"📁 {bucket}:")
                    for obj in latest_objects[:3]:
                        print(f"  📄 {obj['Key']} ({obj['LastModified']})")
                else:
                    print(f"📁 {bucket}: ファイルなし")

            except Exception as e:
                print(f"❌ {bucket} アクセスエラー: {str(e)}")

def main():
    """メイン実行関数"""
    tester = CloudWatchMonitoringTester()

    print("CloudWatch監視テストを開始します。")
    print("テストオプション:")
    print("1. クイックテスト（メール送信なし）")
    print("2. フルテスト（メール送信あり）")

    choice = input("選択してください (1/2): ").strip()

    if choice == "1":
        print("\n🚀 クイックテスト実行中...")
        tester.quick_monitoring_test()
    elif choice == "2":
        print("\n🚀 フルテスト実行中...")
        print("⚠️  注意: このテストは約6分かかります（メール送信＋メトリクス待ち）")
        confirm = input("続行しますか？ (y/N): ").strip().lower()
        if confirm == 'y':
            tester.test_ses_sending_metrics()
            tester.test_firehose_metrics()
            tester.test_alarm_states()
            tester.test_dashboard_access()
        else:
            print("テストをキャンセルしました。")
    else:
        print("無効な選択です。クイックテストを実行します。")
        tester.quick_monitoring_test()

    print("\n✅ CloudWatch監視テスト完了！")

if __name__ == "__main__":
    main()
