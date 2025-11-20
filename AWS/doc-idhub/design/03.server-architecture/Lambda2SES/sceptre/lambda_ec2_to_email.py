import json
import boto3
import time
import os
from datetime import datetime

ssm_client = boto3.client('ssm', region_name='ap-northeast-1')
ses_client = boto3.client('ses', region_name='ap-northeast-1')

def lambda_handler(event, context):
    """
    Retrieve file content from any EC2 instance via SSM and send via SES

    Event format:
    {
        "instance_id": "i-xxxxxxxxxxxxx",  # Optional: defaults to env var
        "file_path": "/path/to/file",      # Optional: defaults to env var
        "email_source": "sender@example.com",
        "email_destination": "recipient@example.com",
        "email_subject": "EC2 File Content"  # Optional
    }

    Environment Variables:
    - DEFAULT_INSTANCE_ID: Default EC2 instance ID
    - DEFAULT_FILE_PATH: Default file path to read
    """
    try:
        # Get default values from environment variables
        default_instance_id = os.environ.get('DEFAULT_INSTANCE_ID', 'i-0297dec34ad7ea77b')
        default_file_path = os.environ.get('DEFAULT_FILE_PATH', '/tmp/aaa')

        # Extract parameters from event (with fallback to env vars)
        instance_id = event.get('instance_id', default_instance_id)
        file_path = event.get('file_path', default_file_path)
        email_source = event['email_source']
        email_destination = event['email_destination']
        email_subject = event.get('email_subject', f'EC2 File Content: {file_path} from {instance_id}')

        # Execute command on EC2 via SSM
        print(f"Reading file {file_path} from instance {instance_id}")

        command = f'cat {file_path}'

        response = ssm_client.send_command(
            InstanceIds=[instance_id],
            DocumentName='AWS-RunShellScript',
            Parameters={
                'commands': [command]
            },
            TimeoutSeconds=30
        )

        command_id = response['Command']['CommandId']
        print(f"Command ID: {command_id}")

        # Wait for command completion
        max_attempts = 10
        attempt = 0

        while attempt < max_attempts:
            time.sleep(2)

            try:
                output = ssm_client.get_command_invocation(
                    CommandId=command_id,
                    InstanceId=instance_id
                )

                status = output['Status']
                print(f"Command status: {status}")

                if status == 'Success':
                    file_content = output['StandardOutputContent']
                    error_content = output['StandardErrorContent']

                    # Build email body
                    email_body = f"""EC2 Instance File Content Report
========================

Instance ID: {instance_id}
File Path: {file_path}
Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Command ID: {command_id}

File Content:
-------------
{file_content}

"""
                    if error_content:
                        email_body += f"""
Errors/Warnings:
----------------
{error_content}
"""

                    # Send email via SES
                    ses_response = ses_client.send_email(
                        Source=email_source,
                        Destination={
                            'ToAddresses': [email_destination]
                        },
                        Message={
                            'Subject': {
                                'Data': email_subject,
                                'Charset': 'UTF-8'
                            },
                            'Body': {
                                'Text': {
                                    'Data': email_body,
                                    'Charset': 'UTF-8'
                                }
                            }
                        }
                    )

                    return {
                        'statusCode': 200,
                        'body': json.dumps({
                            'message': 'File content retrieved and email sent successfully',
                            'command_id': command_id,
                            'message_id': ses_response['MessageId'],
                            'file_size': len(file_content)
                        })
                    }

                elif status in ['Failed', 'Cancelled', 'TimedOut']:
                    error_msg = output.get('StandardErrorContent', 'Unknown error')
                    raise Exception(f"Command {status}: {error_msg}")

            except ssm_client.exceptions.InvocationDoesNotExist:
                print(f"Waiting for command invocation... (attempt {attempt + 1}/{max_attempts})")

            attempt += 1

        raise Exception(f"Command timed out after {max_attempts} attempts")

    except Exception as e:
        error_message = str(e)
        print(f"Error: {error_message}")

        # Send error notification email
        try:
            error_email_body = f"""EC2 File Retrieval Failed
========================

Instance ID: {event.get('instance_id', 'N/A')}
File Path: {event.get('file_path', 'N/A')}
Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Error:
------
{error_message}
"""
            ses_client.send_email(
                Source=event.get('email_source', 'noreply@example.com'),
                Destination={
                    'ToAddresses': [event.get('email_destination', 'admin@example.com')]
                },
                Message={
                    'Subject': {
                        'Data': f"ERROR: {event.get('email_subject', 'EC2 File Retrieval Failed')}",
                        'Charset': 'UTF-8'
                    },
                    'Body': {
                        'Text': {
                            'Data': error_email_body,
                            'Charset': 'UTF-8'
                        }
                    }
                }
            )
        except Exception as email_error:
            print(f"Failed to send error notification: {str(email_error)}")

        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to retrieve file content',
                'error': error_message
            })
        }
