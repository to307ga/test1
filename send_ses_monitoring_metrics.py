#!/usr/bin/env python3
"""
SES Monitoring Metrics Sender
Sends CloudWatch metrics for SES monitoring alarms
"""
import boto3
import json
from datetime import datetime, timezone, timedelta

def send_ses_monitoring_metrics():
    """Send SES monitoring metrics to CloudWatch"""

    cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-1', verify=False)
    ses = boto3.client('sesv2', region_name='ap-northeast-1', verify=False)

    try:
        # Get SES sending statistics (last 24 hours)
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(days=1)

        # SESv2 doesn't have get-send-statistics, so we'll use CloudWatch metrics from SES
        cw_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/SES',
            MetricName='Send',
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour periods
            Statistics=['Sum']
        )

        sends = sum([point['Sum'] for point in cw_response['Datapoints']])

        # Get bounces
        bounce_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/SES',
            MetricName='Bounce',
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )

        bounces = sum([point['Sum'] for point in bounce_response['Datapoints']])

        # Get complaints
        complaint_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/SES',
            MetricName='Complaint',
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )

        complaints = sum([point['Sum'] for point in complaint_response['Datapoints']])

        print(f"SES Statistics (last 24h):")
        print(f"  Sends: {sends}")
        print(f"  Bounces: {bounces}")
        print(f"  Complaints: {complaints}")

        # Calculate metrics
        if sends > 0:
            success_rate = ((sends - bounces - complaints) / sends) * 100
            bounce_rate = (bounces / sends) * 100
            complaint_rate = (complaints / sends) * 100
        else:
            # No sends in last 24h - assume healthy system (no failures)
            success_rate = 100.0
            bounce_rate = 0.0
            complaint_rate = 0.0
            sends = 0

        print(f"Calculated Rates:")
        print(f"  Success Rate: {success_rate:.2f}%")
        print(f"  Bounce Rate: {bounce_rate:.2f}%")
        print(f"  Complaint Rate: {complaint_rate:.2f}%")

        # Send metrics to custom namespace
        namespace = 'ses-migration/prod/007773581311/Monitoring'

        metrics = [
            {
                'MetricName': 'SendSuccessRate',
                'Value': success_rate,
                'Unit': 'Percent',
                'Timestamp': datetime.now(timezone.utc)
            },
            {
                'MetricName': 'BounceRate',
                'Value': bounce_rate,
                'Unit': 'Percent',
                'Timestamp': datetime.now(timezone.utc)
            },
            {
                'MetricName': 'ComplaintRate',
                'Value': complaint_rate,
                'Unit': 'Percent',
                'Timestamp': datetime.now(timezone.utc)
            },
            {
                'MetricName': 'SendVolume',
                'Value': sends,
                'Unit': 'Count',
                'Timestamp': datetime.now(timezone.utc)
            }
        ]

        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=metrics
        )

        print(f"📊 Sent metrics to namespace: {namespace}")
        for metric in metrics:
            print(f"   {metric['MetricName']}: {metric['Value']} {metric['Unit']}")

        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    print("=== SES Monitoring Metrics Sender ===")
    success = send_ses_monitoring_metrics()
    if success:
        print("✅ Metrics sent successfully")
    else:
        print("❌ Failed to send metrics")
