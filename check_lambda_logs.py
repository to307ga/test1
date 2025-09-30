#!/usr/bin/env python3
"""
Lambda関数のログを調査するスクリプト
"""
import boto3
import json
from datetime import datetime, timedelta
import os

def check_lambda_logs():
    # SSL警告を無視
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # boto3クライアント作成（SSL検証無効）
    logs_client = boto3.client(
        'logs',
        region_name='ap-northeast-1',
        verify=False
    )

    # Raw ログ変換Lambda関数のログを確認
    raw_log_group = '/aws/lambda/aws-ses-migration-prod-data-transform-raw'
    masked_log_group = '/aws/lambda/aws-ses-migration-prod-data-transform-masked'

    print("🔍 Lambda関数ログ調査")
    print("=" * 50)

    for log_group, name in [(raw_log_group, 'Raw変換'), (masked_log_group, 'マスク化変換')]:
        print(f"\n📋 {name}Lambda関数ログ:")

        try:
            # 最近のログストリームを取得
            response = logs_client.describe_log_streams(
                logGroupName=log_group,
                orderBy='LastEventTime',
                descending=True,
                limit=3
            )

            if not response['logStreams']:
                print(f"   ログストリームなし")
                continue

            # 最新のログストリームから最近のログイベントを取得
            latest_stream = response['logStreams'][0]
            stream_name = latest_stream['logStreamName']

            print(f"   最新ログストリーム: {stream_name}")
            print(f"   最終イベント時刻: {datetime.fromtimestamp(latest_stream.get('lastEventTime', 0) / 1000)}")

            # 過去1時間のログイベントを取得
            start_time = int((datetime.now() - timedelta(hours=1)).timestamp() * 1000)

            events_response = logs_client.get_log_events(
                logGroupName=log_group,
                logStreamName=stream_name,
                startTime=start_time,
                limit=10
            )

            if events_response['events']:
                print(f"   最近のログイベント数: {len(events_response['events'])}")
                for event in events_response['events'][-3:]:  # 最新3件
                    timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                    print(f"     [{timestamp}] {event['message'][:100]}...")
            else:
                print(f"   過去1時間のログイベントなし")

        except Exception as e:
            print(f"   エラー: {e}")

if __name__ == "__main__":
    check_lambda_logs()
