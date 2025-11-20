import json
import boto3

ses_client = boto3.client('ses', region_name='ap-northeast-1')

def lambda_handler(event, context):
    """
    SES経由でメール送信を行うLambda関数
    
    event形式:
    {
        "source": "sender@example.com",
        "destination": "recipient@example.com",
        "subject": "テストメール",
        "body": "メール本文"
    }
    """
    try:
        response = ses_client.send_email(
            Source=event['source'],
            Destination={
                'ToAddresses': [event['destination']]
            },
            Message={
                'Subject': {
                    'Data': event['subject'],
                    'Charset': 'UTF-8'
                },
                'Body': {
                    'Text': {
                        'Data': event['body'],
                        'Charset': 'UTF-8'
                    }
                }
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Email sent successfully',
                'messageId': response['MessageId']
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to send email',
                'error': str(e)
            })
        }
