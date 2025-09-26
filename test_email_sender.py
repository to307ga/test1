import json
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    ses_client = boto3.client('ses')

    try:
        source_domain = os.environ['SOURCE_DOMAIN']
        recipient = os.environ['RECIPIENT_EMAIL']
        config_set = os.environ['CONFIGURATION_SET']
        project = os.environ['PROJECT_NAME']
        env = os.environ['ENVIRONMENT']

        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        sender = f"test@{source_domain}"

        subject = f"SES Test Email - {project} {env} - {timestamp}"
        body_text = f"SES Test Email\nProject: {project}\nEnvironment: {env}\nTimestamp: {timestamp}\nConfiguration Set: {config_set}\n\nThis is a test email for SES-Kinesis integration verification."

        response = ses_client.send_email(
            Source=sender,
            Destination={
                'ToAddresses': [recipient]
            },
            Message={
                'Subject': {
                    'Data': subject,
                    'Charset': 'UTF-8'
                },
                'Body': {
                    'Text': {
                        'Data': body_text,
                        'Charset': 'UTF-8'
                    }
                }
            },
            ConfigurationSetName=config_set
        )

        message_id = response['MessageId']

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Test email sent successfully',
                'messageId': message_id,
                'sender': sender,
                'recipient': recipient,
                'configurationSet': config_set,
                'timestamp': timestamp
            })
        }

    except Exception as e:
        print(f"Error sending test email: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to send test email'
            })
        }
