import json
import boto3
import re
import logging
import base64
import gzip

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def mask_email(email):
    """
    Mask email address: example@domain.com -> e***@***.***
    要件: 最初の1文字のみ表示、残りは***でマスク
    """
    if not email or '@' not in email:
        return "***@***.***"
    
    local, domain = email.split('@', 1)
    # 最初の1文字のみ表示、残りは***でマスク
    return f"{local[0]}***@***.***"

def mask_ip(ip_address):
    """
    Mask IP address: 192.168.1.100 -> 192.*.*.*
    要件: 最初のオクテットのみ表示、残りは.*.*.*でマスク
    """
    if not ip_address:
        return "***.*.*.*"
    
    # IPアドレスの形式チェック
    ip_pattern = re.match(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$', ip_address)
    if ip_pattern:
        first_octet = ip_pattern.group(1)
        return f"{first_octet}.*.*.*"
    else:
        return "***.*.*.*"

def mask_log_data(log_data, user_groups):
    """
    Mask sensitive data based on user groups
    """
    # Check if user has admin privileges
    is_admin = 'ses-migration-production-admin' in user_groups
    
    if is_admin:
        # Admin users see everything
        return log_data
    
    # Mask email addresses
    log_data = re.sub(
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        lambda m: mask_email(m.group(0)),
        log_data
    )
    
    # Mask IP addresses
    log_data = re.sub(
        r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
        lambda m: mask_ip(m.group(0)),
        log_data
    )
    
    return log_data

def lambda_handler(event, context):
    try:
        # Get user context from event
        user_groups = event.get('userGroups', [])
        log_data = event.get('logData', '')
        
        # Decompress if needed (CloudWatch Logs are often compressed)
        if event.get('awslogs', {}).get('data'):
            compressed_data = base64.b64decode(event['awslogs']['data'])
            log_data = gzip.decompress(compressed_data).decode('utf-8')
        
        # Apply masking
        masked_data = mask_log_data(log_data, user_groups)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'maskedData': masked_data,
                'isAdmin': 'ses-migration-production-admin' in user_groups
            })
        }
        
    except Exception as e:
        logger.error(f"Error masking data: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
