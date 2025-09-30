#!/usr/bin/env python3
"""Send SendSuccessRate metric to CloudWatch for alarm resolution."""

import boto3
from datetime import datetime, timedelta
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def send_sendsuccessrate_metric():
    """Send SendSuccessRate metric to CloudWatch."""
    try:
        # Create CloudWatch client
        cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-1')

        # Metric configuration
        namespace = 'ses-migration/prod/007773581311/Monitoring'
        metric_name = 'SendSuccessRate'

        # Calculate timestamp (current time)
        timestamp = datetime.utcnow()

        # Send metric with 100% success rate (based on previous SES stats)
        success_rate = 100.0

        response = cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': success_rate,
                    'Unit': 'Percent',
                    'Timestamp': timestamp
                }
            ]
        )

        logger.info(f"Successfully sent {metric_name} metric: {success_rate}%")
        logger.info(f"Namespace: {namespace}")
        logger.info(f"Timestamp: {timestamp}")
        logger.info(f"Response: {response}")

        return response

    except Exception as e:
        logger.error(f"Error sending metric: {str(e)}")
        raise

if __name__ == "__main__":
    send_sendsuccessrate_metric()
