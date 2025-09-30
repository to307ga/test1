#!/usr/bin/env python3
"""
Firehose最新エラーログのみを確認するスクリプト
"""
import boto3
from datetime import datetime, timedelta

def check_latest_firehose_errors():
    # SSL警告を無視
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    logs_client = boto3.client(
        'logs',
        region_name='ap-northeast-1',
        verify=False
    )

    print("🔍 Firehose最新エラーログ確認")
    print("=" * 50)

    raw_log_group = '/aws/kinesisfirehose/aws-ses-migration-prod-raw-logs'

    try:
        # 最新のログストリーム
        response = logs_client.describe_log_streams(
            logGroupName=raw_log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )

        if not response['logStreams']:
            print("Raw ログストリームなし")
            return

        stream_name = response['logStreams'][0]['logStreamName']
        print(f"最新Rawログストリーム: {stream_name}")

        # 過去2時間のログイベントをすべて取得
        start_time = int((datetime.now() - timedelta(hours=2)).timestamp() * 1000)

        events_response = logs_client.get_log_events(
            logGroupName=raw_log_group,
            logStreamName=stream_name,
            startTime=start_time,
            limit=20  # より多くのイベントを取得
        )

        if events_response['events']:
            print(f"\n📋 過去2時間のログイベント (最新順):")
            # すべてのイベントを時刻順で表示
            for event in sorted(events_response['events'], key=lambda x: x['timestamp'], reverse=True):
                timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                jst_time = timestamp + timedelta(hours=9)  # JST変換
                message = event['message']
                print(f"[{jst_time.strftime('%m/%d %H:%M:%S JST')}] {message}")

                # アクセス成功を示すメッセージがあるかチェック
                if 'success' in message.lower() or 'delivered' in message.lower():
                    print("   ✅ 成功メッセージ発見！")
        else:
            print("過去2時間のログイベントなし（修正が効いている可能性）")

    except Exception as e:
        print(f"エラー: {e}")

if __name__ == "__main__":
    check_latest_firehose_errors()
