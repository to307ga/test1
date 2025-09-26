#!/usr/bin/env python3
"""
CloudWatchメトリクス遅延確認スクリプト
10分間隔での詳細メトリクス確認
"""

import boto3
import json
import time
from datetime import datetime, timedelta

class MetricsDelayChecker:
    def __init__(self):
        self.cloudwatch_client = boto3.client('cloudwatch', region_name='ap-northeast-1')
        self.configuration_set = "aws-ses-migration-prod-config-set"
        self.test_message_id = "010601997ea4dd70-251d8951-acef-45c2-a501-e3aafcc25225-000000"

    def check_ses_metrics_detailed(self):
        """SESメトリクスの詳細確認"""
        print("=== SESメトリクス詳細確認 ===")
        print(f"🕐 確認時刻: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"📧 対象メッセージID: {self.test_message_id}")

        # 異なる時間範囲で確認
        time_ranges = [
            {"name": "過去1時間", "hours": 1},
            {"name": "過去3時間", "hours": 3},
            {"name": "過去6時間", "hours": 6},
            {"name": "今日（日本時間）", "start": datetime.now().replace(hour=0, minute=0, second=0, microsecond=0), "hours": None}
        ]

        metrics_to_check = [
            {"name": "Send", "description": "送信数"},
            {"name": "Delivery", "description": "配信数"},
            {"name": "Bounce", "description": "バウンス数"},
            {"name": "Complaint", "description": "苦情数"}
        ]

        for time_range in time_ranges:
            print(f"\n📊 {time_range['name']}のメトリクス:")

            if time_range['hours']:
                end_time = datetime.utcnow()
                start_time = end_time - timedelta(hours=time_range['hours'])
            else:
                # 今日の開始時刻（JST）を UTC に変換
                jst_start = time_range['start']
                start_time = jst_start - timedelta(hours=9)  # JSTからUTCに変換
                end_time = datetime.utcnow()

            for metric in metrics_to_check:
                try:
                    # Configuration Set指定でのメトリクス取得
                    response = self.cloudwatch_client.get_metric_statistics(
                        Namespace='AWS/SES',
                        MetricName=metric['name'],
                        Dimensions=[
                            {'Name': 'ConfigurationSet', 'Value': self.configuration_set}
                        ],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=300,  # 5分間隔
                        Statistics=['Sum']
                    )

                    datapoints = response.get('Datapoints', [])
                    total = sum(point['Sum'] for point in datapoints)

                    if datapoints:
                        latest_point = max(datapoints, key=lambda x: x['Timestamp'])
                        print(f"  ✅ {metric['description']}: {total} (最新: {latest_point['Sum']} at {latest_point['Timestamp'].strftime('%H:%M:%S')})")
                    else:
                        print(f"  ⚠️  {metric['description']}: データなし")

                    # グローバル（Configuration Set指定なし）でも確認
                    response_global = self.cloudwatch_client.get_metric_statistics(
                        Namespace='AWS/SES',
                        MetricName=metric['name'],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=300,
                        Statistics=['Sum']
                    )

                    global_datapoints = response_global.get('Datapoints', [])
                    global_total = sum(point['Sum'] for point in global_datapoints)

                    if global_total != total:
                        print(f"    📈 グローバル{metric['description']}: {global_total} (差分: {global_total - total})")

                except Exception as e:
                    print(f"  ❌ {metric['description']} エラー: {str(e)}")

    def check_firehose_metrics_detailed(self):
        """Kinesis Firehoseメトリクスの詳細確認"""
        print("\n=== Kinesis Firehoseメトリクス詳細確認 ===")

        streams = [
            {'name': 'aws-ses-migration-prod-raw-logs-stream', 'type': 'Raw Logs'},
            {'name': 'aws-ses-migration-prod-masked-logs-stream', 'type': 'Masked Logs'}
        ]

        metrics_to_check = [
            {'name': 'DeliveryToS3.Records', 'description': 'S3配信レコード数'},
            {'name': 'DeliveryToS3.Success', 'description': 'S3配信成功数'},
            {'name': 'DeliveryToS3.DataFreshness', 'description': 'データ配信遅延(秒)'},
            {'name': 'IncomingRecords', 'description': '受信レコード数'}
        ]

        for stream in streams:
            print(f"\n📊 {stream['type']} ({stream['name']}):")

            # 過去6時間のメトリクスをチェック
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=6)

            for metric in metrics_to_check:
                try:
                    response = self.cloudwatch_client.get_metric_statistics(
                        Namespace='AWS/KinesisFirehose',
                        MetricName=metric['name'],
                        Dimensions=[
                            {'Name': 'DeliveryStreamName', 'Value': stream['name']}
                        ],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=300,  # 5分間隔
                        Statistics=['Sum', 'Average', 'Maximum'] if 'DataFreshness' in metric['name'] else ['Sum']
                    )

                    datapoints = response.get('Datapoints', [])

                    if datapoints:
                        if 'DataFreshness' in metric['name']:
                            avg_freshness = sum(point.get('Average', 0) for point in datapoints) / len(datapoints)
                            max_freshness = max(point.get('Maximum', 0) for point in datapoints)
                            print(f"  ✅ {metric['description']}: 平均{avg_freshness:.1f}秒, 最大{max_freshness:.1f}秒")
                        else:
                            total = sum(point['Sum'] for point in datapoints)
                            latest_point = max(datapoints, key=lambda x: x['Timestamp'])
                            print(f"  ✅ {metric['description']}: {total} (最新: {latest_point['Sum']} at {latest_point['Timestamp'].strftime('%H:%M:%S')})")
                    else:
                        print(f"  ⚠️  {metric['description']}: データなし")

                except Exception as e:
                    print(f"  ❌ {metric['description']} エラー: {str(e)}")

    def check_s3_activity(self):
        """S3バケット活動の確認"""
        print("\n=== S3バケット活動確認 ===")

        s3_client = boto3.client('s3', region_name='ap-northeast-1')
        buckets = [
            {'name': 'aws-ses-migration-prod-raw-logs-007773581311', 'type': 'Raw Logs'},
            {'name': 'aws-ses-migration-prod-masked-logs-007773581311', 'type': 'Masked Logs'}
        ]

        for bucket in buckets:
            try:
                print(f"\n📁 {bucket['type']} ({bucket['name']}):")

                # 今日の日付でファイル確認
                today = datetime.now().strftime("%Y/%m/%d")
                prefix = f"{'raw-logs' if 'raw' in bucket['name'] else 'masked-logs'}/environment=prod/year=2025/month=09/day=25/"

                response = s3_client.list_objects_v2(
                    Bucket=bucket['name'],
                    Prefix=prefix,
                    MaxKeys=10
                )

                if 'Contents' in response:
                    files = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)
                    print(f"  📊 今日のファイル数: {len(files)}")

                    for i, obj in enumerate(files[:3]):
                        file_age = datetime.now(obj['LastModified'].tzinfo) - obj['LastModified']
                        age_minutes = file_age.total_seconds() / 60
                        print(f"  📄 {i+1}. {obj['Key'].split('/')[-1][:50]}...")
                        print(f"      サイズ: {obj['Size']} bytes, 作成: {obj['LastModified'].strftime('%H:%M:%S')} ({age_minutes:.1f}分前)")
                else:
                    print("  ⚠️  今日のファイルなし")

            except Exception as e:
                print(f"  ❌ {bucket['type']} エラー: {str(e)}")

    def run_detailed_check(self):
        """詳細メトリクス確認の実行"""
        print("🔍 CloudWatchメトリクス遅延詳細確認を開始")
        print("=" * 60)

        self.check_ses_metrics_detailed()
        self.check_firehose_metrics_detailed()
        self.check_s3_activity()

        print("\n=" * 60)
        print("✅ 詳細確認完了")

        # 推奨事項の表示
        print("\n💡 推奨アクション:")
        print("1. SESメトリクスが空の場合: AWS SES Console で送信統計を直接確認")
        print("2. Firehoseメトリクスが0の場合: S3活動と比較して実際の配信状況を確認")
        print("3. データ配信遅延が長い場合: Firehose設定のバッファサイズ・時間を確認")
        print("4. 継続的な監視: 15-30分間隔での再チェックを推奨")

def main():
    """メイン実行関数"""
    checker = MetricsDelayChecker()

    print("CloudWatchメトリクス遅延確認ツール")
    print("現在時刻での詳細メトリクス確認を行います。")

    checker.run_detailed_check()

if __name__ == "__main__":
    main()
