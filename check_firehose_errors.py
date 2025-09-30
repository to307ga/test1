#!/usr/bin/env python3
"""
Firehose配信エラーログを調査するスクリプト
"""
import boto3
import json
from datetime import datetime, timedelta

def check_firehose_errors():
    # SSL警告を無視
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # boto3クライアント作成（SSL検証無効）
    logs_client = boto3.client(
        'logs',
        region_name='ap-northeast-1',
        verify=False
    )

    cloudwatch = boto3.client(
        'cloudwatch',
        region_name='ap-northeast-1',
        verify=False
    )

    print("🔍 Firehose配信エラー調査")
    print("=" * 50)

    # Firehoseロググループ
    firehose_log_groups = [
        '/aws/kinesisfirehose/aws-ses-migration-prod-raw-logs',
        '/aws/kinesisfirehose/aws-ses-migration-prod-masked-logs'
    ]

    for log_group in firehose_log_groups:
        log_type = "Raw" if "raw-logs" in log_group else "マスク化"
        print(f"\n📋 {log_type}ログストリーム:")

        try:
            # ログストリームを取得
            response = logs_client.describe_log_streams(
                logGroupName=log_group,
                orderBy='LastEventTime',
                descending=True,
                limit=3
            )

            if not response['logStreams']:
                print(f"   ログストリームなし")
                continue

            # 最新のログストリームからエラーログを取得
            for stream in response['logStreams'][:2]:  # 最新2個
                stream_name = stream['logStreamName']
                print(f"\n   ストリーム: {stream_name}")

                # 過去2時間のログイベントを取得
                start_time = int((datetime.now() - timedelta(hours=2)).timestamp() * 1000)

                try:
                    events_response = logs_client.get_log_events(
                        logGroupName=log_group,
                        logStreamName=stream_name,
                        startTime=start_time,
                        limit=20
                    )

                    if events_response['events']:
                        print(f"   ログイベント数: {len(events_response['events'])}")
                        for event in events_response['events']:
                            timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                            message = event['message']
                            print(f"   [{timestamp}] {message}")

                            # S3アクセスエラーを特に確認
                            if any(keyword in message.lower() for keyword in ['access denied', 'forbidden', '403', 'bucket', 'permission']):
                                print(f"   🚨 S3アクセス関連エラー発見: {message}")
                    else:
                        print(f"   過去2時間のログイベントなし")

                except Exception as e:
                    print(f"   ログ取得エラー: {e}")

        except Exception as e:
            print(f"   ログストリーム確認エラー: {e}")

    # Firehoseメトリクスでエラー状況も確認
    print(f"\n📊 Firehoseエラーメトリクス:")

    streams = ['aws-ses-migration-prod-raw-logs-stream', 'aws-ses-migration-prod-masked-logs-stream']

    for stream_name in streams:
        stream_type = "Raw" if "raw-logs" in stream_name else "マスク化"
        print(f"\n   {stream_type}ストリーム ({stream_name}):")

        try:
            # エラーメトリクスを確認
            end_time = datetime.now()
            start_time = end_time - timedelta(hours=2)

            # S3配信エラー
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/KinesisFirehose',
                MetricName='DeliveryToS3.Success',
                Dimensions=[
                    {
                        'Name': 'DeliveryStreamName',
                        'Value': stream_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum', 'Average']
            )

            if response['Datapoints']:
                print(f"   S3配信成功メトリクス: {len(response['Datapoints'])} データポイント")
                for dp in sorted(response['Datapoints'], key=lambda x: x['Timestamp']):
                    print(f"     [{dp['Timestamp']}] 成功: {dp['Sum']}, 平均: {dp['Average']}")
            else:
                print(f"   S3配信成功メトリクス: データなし")

            # データ変換エラー
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/KinesisFirehose',
                MetricName='DeliveryToS3.DataFreshness',
                Dimensions=[
                    {
                        'Name': 'DeliveryStreamName',
                        'Value': stream_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average', 'Maximum']
            )

            if response['Datapoints']:
                print(f"   データ新鮮度メトリクス: {len(response['Datapoints'])} データポイント")
                for dp in sorted(response['Datapoints'], key=lambda x: x['Timestamp']):
                    print(f"     [{dp['Timestamp']}] 平均: {dp['Average']}, 最大: {dp['Maximum']}")

        except Exception as e:
            print(f"   メトリクス確認エラー: {e}")

if __name__ == "__main__":
    check_firehose_errors()
