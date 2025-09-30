#!/usr/bin/env python3
"""
Firehoseの配信成功状況を詳細確認するスクリプト
"""
import boto3
from datetime import datetime, timedelta

def check_firehose_success_metrics():
    # SSL警告を無視
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    cloudwatch = boto3.client(
        'cloudwatch',
        region_name='ap-northeast-1',
        verify=False
    )

    print("🔍 Firehose配信成功メトリクス詳細確認")
    print("=" * 60)

    # 2:14:40 JST は UTC 5:14:40
    # その前後30分をチェック
    end_time = datetime.now()
    start_time = end_time - timedelta(hours=2)  # 過去2時間

    streams = [
        ('aws-ses-migration-prod-raw-logs-stream', 'Raw'),
        ('aws-ses-migration-prod-masked-logs-stream', 'マスク化')
    ]

    for stream_name, stream_type in streams:
        print(f"\n📊 {stream_type}ストリーム ({stream_name}):")

        try:
            # 配信成功メトリクス
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
                Period=300,  # 5分間隔
                Statistics=['Sum']
            )

            if response['Datapoints']:
                print(f"   🎯 S3配信成功データポイント: {len(response['Datapoints'])}個")
                for dp in sorted(response['Datapoints'], key=lambda x: x['Timestamp']):
                    local_time = dp['Timestamp'] + timedelta(hours=9)  # JST変換
                    print(f"     [{local_time.strftime('%m/%d %H:%M:%S JST')}] 成功数: {int(dp['Sum'])}")
            else:
                print(f"   ❌ S3配信成功データポイント: なし")

            # 配信レコード数
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/KinesisFirehose',
                MetricName='DeliveryToS3.Records',
                Dimensions=[
                    {
                        'Name': 'DeliveryStreamName',
                        'Value': stream_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )

            if response['Datapoints']:
                print(f"   📝 配信レコード数: {len(response['Datapoints'])}個のデータポイント")
                for dp in sorted(response['Datapoints'], key=lambda x: x['Timestamp']):
                    local_time = dp['Timestamp'] + timedelta(hours=9)  # JST変換
                    print(f"     [{local_time.strftime('%m/%d %H:%M:%S JST')}] レコード数: {int(dp['Sum'])}")
            else:
                print(f"   ❌ 配信レコード数: データポイントなし")

            # データサイズ
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/KinesisFirehose',
                MetricName='DeliveryToS3.Bytes',
                Dimensions=[
                    {
                        'Name': 'DeliveryStreamName',
                        'Value': stream_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )

            if response['Datapoints']:
                print(f"   💾 配信データサイズ: {len(response['Datapoints'])}個のデータポイント")
                for dp in sorted(response['Datapoints'], key=lambda x: x['Timestamp']):
                    local_time = dp['Timestamp'] + timedelta(hours=9)  # JST変換
                    size_bytes = int(dp['Sum'])
                    print(f"     [{local_time.strftime('%m/%d %H:%M:%S JST')}] サイズ: {size_bytes} bytes")

        except Exception as e:
            print(f"   エラー: {e}")

if __name__ == "__main__":
    check_firehose_success_metrics()
