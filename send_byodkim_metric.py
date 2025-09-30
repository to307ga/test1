#!/usr/bin/env python3
"""
BYODKIM verification status metric sender
Sends CloudWatch metric to resolve alarm state
"""
import boto3
import json
from datetime import datetime, timezone

def send_byodkim_metric():
    """Send BYODKIM verification status metric to CloudWatch"""

    cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-1', verify=False)
    ses = boto3.client('sesv2', region_name='ap-northeast-1', verify=False)

    try:
        # Get current BYODKIM status
        response = ses.get_email_identity(EmailIdentity='goo.ne.jp')
        dkim_attrs = response.get('DkimAttributes', {})

        signing_enabled = dkim_attrs.get('SigningEnabled', False)
        status = dkim_attrs.get('Status', 'FAILED')
        origin = dkim_attrs.get('SigningAttributesOrigin', 'UNKNOWN')

        print(f"Current BYODKIM Status:")
        print(f"  SigningEnabled: {signing_enabled}")
        print(f"  Status: {status}")
        print(f"  Origin: {origin}")

        # Determine metric value
        # 1 = Success (BYODKIM active and configured)
        # 0 = Failed/Pending
        if signing_enabled and origin == 'EXTERNAL':
            metric_value = 1.0
            print(f"✅ BYODKIM is properly configured")
        else:
            metric_value = 0.0
            print(f"⚠️ BYODKIM needs attention")

        # Send metric to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='ses-migration/prod/007773581311/BYODKIM',
            MetricData=[
                {
                    'MetricName': 'BYODKIMVerificationStatus',
                    'Value': metric_value,
                    'Unit': 'None',
                    'Timestamp': datetime.now(timezone.utc)
                }
            ]
        )

        print(f"📊 Sent metric: BYODKIMVerificationStatus = {metric_value}")
        print(f"📍 Namespace: ses-migration/prod/007773581311/BYODKIM")

        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    print("=== BYODKIM Metric Sender ===")
    success = send_byodkim_metric()
    if success:
        print("✅ Metric sent successfully")
    else:
        print("❌ Failed to send metric")
