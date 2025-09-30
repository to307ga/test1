#!/usr/bin/env python3
"""
Lambda関数の詳細ログを調査するスクリプト
"""
import boto3
import json
from datetime import datetime, timedelta
import os

def get_lambda_log_details():
    # SSL警告を無視
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # boto3クライアント作成（SSL検証無効）
    logs_client = boto3.client(
        'logs',
        region_name='ap-northeast-1',
        verify=False
    )

    # Raw ログ変換Lambda関数のログを詳細確認
    raw_log_group = '/aws/lambda/aws-ses-migration-prod-data-transform-raw'

    print("🔍 Raw変換Lambda関数詳細ログ")
    print("=" * 50)

    try:
        # 最近のログストリームを取得
        response = logs_client.describe_log_streams(
            logGroupName=raw_log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )

        if not response['logStreams']:
            print("ログストリームなし")
            return

        latest_stream = response['logStreams'][0]
        stream_name = latest_stream['logStreamName']

        print(f"最新ログストリーム: {stream_name}")

        # 過去1時間のログイベントを詳細取得
        start_time = int((datetime.now() - timedelta(hours=1)).timestamp() * 1000)

        events_response = logs_client.get_log_events(
            logGroupName=raw_log_group,
            logStreamName=stream_name,
            startTime=start_time,
            limit=50
        )

        print(f"\n📋 ログイベント詳細:")
        for event in events_response['events']:
            timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
            message = event['message']
            print(f"[{timestamp}] {message}")

    except Exception as e:
        print(f"エラー: {e}")

if __name__ == "__main__":
    get_lambda_log_details()
