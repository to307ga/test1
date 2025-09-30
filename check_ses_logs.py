#!/usr/bin/env python3
"""
SESログ確認スクリプト
テストメール送信後のログ格納状況を確認
"""

import boto3
import json
import time
from datetime import datetime, timedelta
import os

def check_cloudwatch_logs():
    """CloudWatchログを確認"""
    print("=== CloudWatch Logs 確認 ===")

    client = boto3.client('logs', region_name='ap-northeast-1')

    # SES関連ロググループ
    log_groups = [
        '/aws/ses/aws-ses-migration-prod',
        '/aws/kinesisfirehose/aws-ses-migration-prod-raw-logs',
        '/aws/kinesisfirehose/aws-ses-migration-prod-masked-logs',
        '/aws/ses-kinesis-integration/aws-ses-migration-prod'
    ]

    for group in log_groups:
        try:
            print(f"\n📋 {group}:")

            # 最新のログストリームを取得
            streams = client.describe_log_streams(
                logGroupName=group,
                orderBy='LastEventTime',
                descending=True,
                limit=3
            )

            if streams['logStreams']:
                for stream in streams['logStreams']:
                    last_event = datetime.fromtimestamp(stream['lastEventTime']/1000)
                    print(f"   📄 {stream['logStreamName']}")
                    print(f"      最終イベント: {last_event}")

                    # 最新のイベントを数個取得
                    try:
                        events = client.get_log_events(
                            logGroupName=group,
                            logStreamName=stream['logStreamName'],
                            limit=3,
                            startFromHead=False
                        )

                        for event in events['events'][-3:]:
                            timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                            message = event['message'][:100] + "..." if len(event['message']) > 100 else event['message']
                            print(f"      [{timestamp}] {message}")

                    except Exception as e:
                        print(f"      ログ取得エラー: {e}")
            else:
                print("   ログストリームなし")

        except Exception as e:
            print(f"   エラー: {e}")

def check_firehose_metrics():
    """Kinesis Firehoseメトリクス確認"""
    print("\n=== Kinesis Firehose メトリクス ===")

    client = boto3.client('cloudwatch', region_name='ap-northeast-1')

    delivery_streams = [
        'aws-ses-migration-prod-raw-logs',
        'aws-ses-migration-prod-masked-logs'
    ]

    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)

    for stream in delivery_streams:
        print(f"\n📊 {stream}:")

        metrics_to_check = [
            'DeliveryToS3.Records',
            'DeliveryToS3.Success',
            'DeliveryToS3.DataFreshness'
        ]

        for metric in metrics_to_check:
            try:
                response = client.get_metric_statistics(
                    Namespace='AWS/KinesisFirehose',
                    MetricName=metric,
                    Dimensions=[
                        {'Name': 'DeliveryStreamName', 'Value': stream}
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum', 'Average', 'Maximum']
                )

                if response['Datapoints']:
                    latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                    print(f"   {metric}:")
                    print(f"     時刻: {latest['Timestamp']}")
                    if 'Sum' in latest:
                        print(f"     合計: {latest['Sum']}")
                    if 'Average' in latest:
                        print(f"     平均: {latest['Average']:.2f}")
                    if 'Maximum' in latest:
                        print(f"     最大: {latest['Maximum']}")
                else:
                    print(f"   {metric}: データポイントなし")

            except Exception as e:
                print(f"   {metric}: エラー - {e}")

def check_s3_access_with_role():
    """IAMロールを使用してS3バケットアクセスを試行"""
    print("\n=== S3バケット アクセス試行 ===")

    s3_client = boto3.client('s3', region_name='ap-northeast-1')

    buckets = [
        'aws-ses-migration-prod-raw-logs-007773581311',
        'aws-ses-migration-prod-masked-logs-007773581311'
    ]

    for bucket in buckets:
        print(f"\n📁 {bucket}:")
        try:
            # バケット存在確認
            s3_client.head_bucket(Bucket=bucket)
            print("   ✅ バケット存在確認: OK")

            # リスト権限確認
            response = s3_client.list_objects_v2(
                Bucket=bucket,
                MaxKeys=10
            )

            if 'Contents' in response:
                print(f"   📄 ファイル数: {len(response['Contents'])}")
                for obj in response['Contents'][:5]:
                    print(f"     - {obj['Key']} ({obj['Size']} bytes, {obj['LastModified']})")
            else:
                print("   📄 ファイルなし")

        except Exception as e:
            print(f"   ❌ アクセスエラー: {e}")

            # エラーの詳細分析
            if "AccessDenied" in str(e):
                print("     → IP制限またはIAM権限の問題")
            elif "NoSuchBucket" in str(e):
                print("     → バケットが存在しない")
            else:
                print(f"     → その他のエラー: {type(e).__name__}")

def main():
    print("🔍 SES ログ格納状況確認")
    print("=" * 50)

    # 環境変数でSSL検証無効化
    os.environ['PYTHONHTTPSVERIFY'] = '0'

    try:
        # CloudWatchログ確認
        check_cloudwatch_logs()

        # Firehoseメトリクス確認
        check_firehose_metrics()

        # S3バケットアクセス確認
        check_s3_access_with_role()

        print("\n" + "=" * 50)
        print("✅ ログ確認完了")
        print("\n💡 注意点:")
        print("- Firehoseは通常5分間隔でS3に配信します")
        print("- IP制限によりS3アクセスが制限される場合があります")
        print("- CloudWatchログは即座に記録されます")

    except Exception as e:
        print(f"❌ エラー: {e}")
        return False

    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
