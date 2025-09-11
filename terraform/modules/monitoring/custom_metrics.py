import json
import boto3
import logging
from datetime import datetime, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

cloudwatch = boto3.client('cloudwatch')
ses = boto3.client('ses')

def lambda_handler(event, context):
    try:
        # Get SES sending statistics
        stats = ses.get_send_statistics()
        
        if stats['SendDataPoints']:
            latest_stats = stats['SendDataPoints'][-1]
            
            # Calculate success rate
            total_sent = latest_stats.get('DeliveryAttempts', 0)
            bounces = latest_stats.get('Bounces', 0)
            complaints = latest_stats.get('Complaints', 0)
            rejects = latest_stats.get('Rejects', 0)
            
            if total_sent > 0:
                success_rate = ((total_sent - bounces - complaints - rejects) / total_sent) * 100
                bounce_rate = (bounces / total_sent) * 100
                complaint_rate = (complaints / total_sent) * 100
                
                # Put custom metrics
                cloudwatch.put_metric_data(
                    Namespace='ses-migration/production/SES',
                    MetricData=[
                        {
                            'MetricName': 'SendSuccessRate',
                            'Value': success_rate,
                            'Unit': 'Percent'
                        },
                        {
                            'MetricName': 'BounceRate',
                            'Value': bounce_rate,
                            'Unit': 'Percent'
                        },
                        {
                            'MetricName': 'ComplaintRate',
                            'Value': complaint_rate,
                            'Unit': 'Percent'
                        }
                    ]
                )
                
                logger.info(f"Metrics published: Success={success_rate:.2f}%, Bounce={bounce_rate:.2f}%, Complaint={complaint_rate:.2f}%")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Metrics published successfully')
        }
        
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
